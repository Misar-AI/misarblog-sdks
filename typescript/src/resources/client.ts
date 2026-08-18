/**
 * Core HTTP transport for the Misar.Blog developer API.
 *
 * Base URL is `https://api.misar.io/blog/v1` — the blog gateway strips `/api`,
 * so paths here never carry an `/api` prefix. Authenticate with a developer key
 * (`mbk_...`) or an OAuth 2.1 access token, both sent as a Bearer token.
 */

export class BlogApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
    /** The decoded error body, when the response carried JSON. */
    public readonly body: Record<string, unknown> = {}
  ) {
    super(message);
    this.name = "BlogApiError";
  }

  /** Scope the key would need, present on 403 scope failures. */
  get requiredScope(): string | undefined {
    return typeof this.body.required_scope === "string" ? this.body.required_scope : undefined;
  }

  /** Scopes the presented key carries, present on 403 scope failures. */
  get grantedScopes(): string[] | undefined {
    return Array.isArray(this.body.granted_scopes)
      ? (this.body.granted_scopes as string[])
      : undefined;
  }
}

/**
 * Thrown when the subscription attached to the API key blocks the call.
 *
 * The API signals this with `code: "plan_limit_exceeded"` and answers 429 when
 * a metered allowance is exhausted (retryable once the period rolls over) or
 * 402 when the feature is locked outright. It is a distinct type rather than a
 * generic 429 because retrying cannot help until the allowance resets or the
 * plan changes — the client stops retrying as soon as it sees this code.
 *
 * Surface {@link upgradeUrl} to the user rather than reporting a bare failure.
 */
export class PlanLimitError extends BlogApiError {
  constructor(
    status: number,
    message: string,
    body: Record<string, unknown>,
    /** The account's current plan slug, when the API reports it. */
    public readonly plan?: string,
    /** Pricing page to send the user to. */
    public readonly upgradeUrl?: string,
    /** Seconds until the allowance resets, when the API supplies it. */
    public readonly retryAfter?: number
  ) {
    super(status, message, body);
    this.name = "PlanLimitError";
  }

  /** The full upgrade offer from the response body. */
  get upgrade(): Record<string, unknown> {
    return typeof this.body.upgrade === "object" && this.body.upgrade !== null
      ? (this.body.upgrade as Record<string, unknown>)
      : {};
  }
}

/** Thrown when the request never reached the API (transport failure). */
export class NetworkError extends BlogApiError {
  constructor(message: string, public readonly cause?: unknown) {
    super(0, message);
    this.name = "NetworkError";
  }
}

export interface BlogApiClientOptions {
  /** Override the API base (e.g. the app origin `https://www.misar.blog/api/v1`). */
  baseUrl?: string;
  /** Total attempts for retryable statuses and transport errors. Minimum 1. */
  maxRetries?: number;
  /** Per-request timeout in milliseconds. */
  timeoutMs?: number;
  /** Injectable fetch, used by tests. */
  fetch?: typeof globalThis.fetch;
}

const DEFAULT_BASE_URL = "https://api.misar.io/blog/v1";
const RETRYABLE = new Set([429, 500, 502, 503, 504]);
const RETRY_BASE_MS = 300;

/**
 * Read a nested string out of a decoded JSON body.
 *
 * Only own properties are followed, so a response containing `__proto__` or
 * `constructor` resolves to undefined rather than reaching up the prototype
 * chain — the body is attacker-influenced data, not a trusted object.
 */
function pick(obj: unknown, ...path: string[]): string | undefined {
  let cur: unknown = obj;
  for (const key of path) {
    if (typeof cur !== "object" || cur === null) return undefined;
    if (!Object.prototype.hasOwnProperty.call(cur, key)) return undefined;
    cur = (cur as Record<string, unknown>)[key];
  }
  return typeof cur === "string" ? cur : undefined;
}

export class BlogApiClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly maxRetries: number;
  private readonly timeoutMs: number;
  private readonly fetchImpl: typeof globalThis.fetch;

  constructor(apiKey: string, options: BlogApiClientOptions | string = {}) {
    // A bare string keeps the pre-1.1 `new BlogApiClient(key, baseUrl)` call working.
    const opts: BlogApiClientOptions = typeof options === "string" ? { baseUrl: options } : options;

    if (!apiKey) throw new Error("apiKey is required");

    this.apiKey = apiKey;
    this.baseUrl = (opts.baseUrl ?? DEFAULT_BASE_URL).replace(/\/$/, "");
    this.maxRetries = Math.max(1, opts.maxRetries ?? 3);
    this.timeoutMs = opts.timeoutMs ?? 30_000;
    this.fetchImpl = opts.fetch ?? globalThis.fetch;
  }

  async request<T>(method: string, path: string, body?: unknown): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    let lastError: unknown;

    for (let attempt = 0; attempt < this.maxRetries; attempt++) {
      if (attempt > 0) {
        await new Promise((r) => setTimeout(r, RETRY_BASE_MS * 2 ** (attempt - 1)));
      }

      let res: Response;
      try {
        res = await this.fetchImpl(url, {
          method,
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            "Content-Type": "application/json",
            Accept: "application/json",
          },
          ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
          signal: AbortSignal.timeout(this.timeoutMs),
        });
      } catch (err) {
        lastError = err;
        if (attempt < this.maxRetries - 1) continue;
        throw new NetworkError(err instanceof Error ? err.message : String(err), err);
      }

      if (res.status === 204) return {} as T;

      const raw = await res.text();
      const decoded = this.decode(raw);

      // A plan-limit 429 is not "slow down": retrying cannot help until the
      // allowance resets or the plan changes, so surface it immediately
      // instead of burning the retry budget.
      if (decoded.code === "plan_limit_exceeded") {
        throw this.planLimitError(res, decoded);
      }

      if (RETRYABLE.has(res.status) && attempt < this.maxRetries - 1) {
        lastError = new BlogApiError(res.status, this.message(decoded, res), decoded);
        continue;
      }

      if (!res.ok) {
        throw new BlogApiError(res.status, this.message(decoded, res), decoded);
      }

      return (raw ? JSON.parse(raw) : {}) as T;
    }

    throw new NetworkError(
      `max retries exceeded: ${lastError instanceof Error ? lastError.message : "unknown"}`,
      lastError
    );
  }

  private decode(raw: string): Record<string, unknown> {
    if (!raw) return {};
    try {
      const parsed: unknown = JSON.parse(raw);
      return typeof parsed === "object" && parsed !== null ? (parsed as Record<string, unknown>) : {};
    } catch {
      return {};
    }
  }

  private message(decoded: Record<string, unknown>, res: Response): string {
    return typeof decoded.error === "string"
      ? decoded.error
      : res.statusText || `HTTP ${res.status}`;
  }

  private planLimitError(res: Response, decoded: Record<string, unknown>): PlanLimitError {
    // Headers are authoritative; fall back to the offer body when a proxy has
    // stripped them.
    const plan =
      res.headers.get("x-misar-plan") ?? pick(decoded.upgrade, "current_plan", "slug");
    const upgradeUrl =
      res.headers.get("x-misar-upgrade-url") ?? pick(decoded.upgrade, "urls", "pricing");
    const retryHeader = res.headers.get("retry-after");
    const retryAfter = retryHeader && /^\d+$/.test(retryHeader) ? Number(retryHeader) : undefined;

    return new PlanLimitError(
      res.status,
      this.message(decoded, res),
      decoded,
      plan ?? undefined,
      upgradeUrl ?? undefined,
      retryAfter
    );
  }

  get<T>(path: string): Promise<T> {
    return this.request<T>("GET", path);
  }

  post<T>(path: string, body?: unknown): Promise<T> {
    return this.request<T>("POST", path, body);
  }

  patch<T>(path: string, body?: unknown): Promise<T> {
    return this.request<T>("PATCH", path, body);
  }

  delete<T>(path: string, body?: unknown): Promise<T> {
    return this.request<T>("DELETE", path, body);
  }
}
