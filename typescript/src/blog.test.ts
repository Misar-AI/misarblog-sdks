import { describe, expect, it, vi } from "vitest";
import { MisarBlog } from "./blog.js";
import { BlogApiError, PlanLimitError } from "./resources/client.js";

/** Build a fetch stub that replays the given responses in order. */
function stubFetch(
  ...responses: Array<{
    status: number;
    body?: unknown;
    headers?: Record<string, string>;
  }>
) {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const impl = vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    // Keep replaying the final response once the queue is drained, so a test
    // that makes many calls only has to describe the ones that differ.
    const next = responses.length > 1 ? responses.shift()! : responses[0];
    return new Response(next.body === undefined ? "" : JSON.stringify(next.body), {
      status: next.status,
      headers: { "Content-Type": "application/json", ...(next.headers ?? {}) },
    });
  });
  return { impl: impl as unknown as typeof globalThis.fetch, calls };
}

function client(fetchImpl: typeof globalThis.fetch, maxRetries = 3) {
  return new MisarBlog({ apiKey: "mbk_test", fetch: fetchImpl, maxRetries });
}

describe("MisarBlog transport", () => {
  it("sends the API key as a Bearer token against the gateway base URL", async () => {
    const { impl, calls } = stubFetch({ status: 200, body: { id: "u1", username: "gulshan" } });
    await client(impl).profiles.me();

    expect(calls[0].url).toBe("https://api.misar.io/blog/v1/me");
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe("Bearer mbk_test");
  });

  it("retries a transient 503 and then succeeds", async () => {
    const { impl, calls } = stubFetch(
      { status: 503, body: { error: "upstream" } },
      { status: 200, body: { articles: [], total: 0 } }
    );
    const result = await client(impl).articles.list();

    expect(calls).toHaveLength(2);
    expect(result.total).toBe(0);
  });

  it("throws BlogApiError on a 401 without retrying", async () => {
    const { impl, calls } = stubFetch({ status: 401, body: { error: "Invalid or missing API key" } });

    await expect(client(impl).profiles.me()).rejects.toThrowError(BlogApiError);
    expect(calls).toHaveLength(1);
  });
});

describe("plan limits", () => {
  it("raises PlanLimitError with the upgrade URL from the response headers", async () => {
    const { impl } = stubFetch({
      status: 429,
      body: {
        error: "You have used all 50 writes this month. Upgrade to keep publishing.",
        code: "plan_limit_exceeded",
        upgrade: { urls: { pricing: "https://body.example/pricing" } },
      },
      headers: {
        "X-Misar-Plan": "starter",
        "X-Misar-Upgrade-Url": "https://www.misar.blog/pricing?utm_source=mcp",
        "Retry-After": "3600",
      },
    });

    const err = await client(impl)
      .articles.create({ title: "x", body_markdown: "y" })
      .catch((e: unknown) => e);

    expect(err).toBeInstanceOf(PlanLimitError);
    const planErr = err as PlanLimitError;
    expect(planErr.status).toBe(429);
    expect(planErr.plan).toBe("starter");
    expect(planErr.upgradeUrl).toBe("https://www.misar.blog/pricing?utm_source=mcp");
    expect(planErr.retryAfter).toBe(3600);
  });

  it("falls back to the offer body when a proxy strips the headers", async () => {
    const { impl } = stubFetch({
      status: 402,
      body: {
        error: "AI titles are not included on Free.",
        code: "plan_limit_exceeded",
        upgrade: {
          urls: { pricing: "https://www.misar.blog/pricing" },
          current_plan: { slug: "free" },
        },
      },
    });

    const err = (await client(impl)
      .ai.titles({ action: "seo", prompt: "x" })
      .catch((e: unknown) => e)) as PlanLimitError;

    expect(err).toBeInstanceOf(PlanLimitError);
    expect(err.plan).toBe("free");
    expect(err.upgradeUrl).toBe("https://www.misar.blog/pricing");
  });

  it("does not burn the retry budget on a plan-limit 429", async () => {
    const { impl, calls } = stubFetch({
      status: 429,
      body: { error: "quota exhausted", code: "plan_limit_exceeded" },
    });

    await expect(client(impl).articles.create({ title: "x", body_markdown: "y" })).rejects.toThrowError(
      PlanLimitError
    );
    // A plain 429 would have been retried 3 times; this must stop at 1.
    expect(calls).toHaveLength(1);
  });

  it("still retries a plain 429 that is not a plan refusal", async () => {
    const { impl, calls } = stubFetch(
      { status: 429, body: { error: "Rate limit exceeded — 100 req/min" } },
      { status: 200, body: { id: "u1" } }
    );

    await client(impl).profiles.me();
    expect(calls).toHaveLength(2);
  });
});

describe("surface coverage", () => {
  it("targets the documented path and method for each operation", async () => {
    const cases: Array<[string, () => Promise<unknown>, string, string]> = [];
    const { impl, calls } = stubFetch({ status: 200, body: {} });
    const blog = client(impl);

    cases.push(
      ["articles.update", () => blog.articles.update("a b", { title: "t" }), "PATCH", "/articles/a%20b"],
      ["ai.complete", () => blog.ai.complete({ prompt: "p" }), "POST", "/ai/complete"],
      ["images.generate", () => blog.images.generate("p"), "POST", "/images/generate"],
      ["images.upload", () => blog.images.upload({ data: "x" }), "POST", "/images/upload"],
      ["plan.get", () => blog.plan.get(), "GET", "/plan"],
      ["plan.trialStatus", () => blog.plan.trialStatus(), "GET", "/trial"],
      ["plan.startTrial", () => blog.plan.startTrial({ feature: "ai" }), "POST", "/trial"],
      ["upsell.funnel", () => blog.upsell.funnel({ days: 7 }), "GET", "/upsell-funnel?days=7"],
      ["series.addArticle", () => blog.series.addArticle("s", "a"), "POST", "/series/s/articles"],
      ["comments.list", () => blog.comments.list("art1"), "GET", "/comments?article_id=art1"],
      ["follows.status", () => blog.follows.status("u1"), "GET", "/follows?user_id=u1"]
    );

    for (const [name, run, method, path] of cases) {
      calls.length = 0;
      await run();
      expect(calls[0].init.method, name).toBe(method);
      expect(calls[0].url, name).toBe(`https://api.misar.io/blog/v1${path}`);
    }
  });
});
