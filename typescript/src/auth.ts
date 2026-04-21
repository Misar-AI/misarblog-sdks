const AUTH_BASE = "https://misar.blog";
const TOKEN_KEY = "misar_blog_token";

export interface TokenRefreshOptions {
  token: string;
  baseUrl?: string;
}

export interface TokenRefreshResult {
  token: string;
  expiresAt: number;
}

export async function refreshToken(options: TokenRefreshOptions): Promise<TokenRefreshResult> {
  const base = options.baseUrl ?? AUTH_BASE;
  const res = await fetch(`${base}/api/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: options.token }),
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error((body as { error?: string }).error ?? `Refresh failed: ${res.status}`);
  }

  const data = (await res.json()) as TokenRefreshResult;

  if (typeof localStorage !== "undefined") {
    localStorage.setItem(TOKEN_KEY, data.token);
  }

  return data;
}

export function getToken(): string | null {
  if (typeof localStorage === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function clearToken(): void {
  if (typeof localStorage !== "undefined") {
    localStorage.removeItem(TOKEN_KEY);
  }
}
