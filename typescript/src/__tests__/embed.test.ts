import { describe, it, expect, beforeEach, vi } from "vitest";
import { embed, embedUrl } from "../embed.js";
import { refreshToken, getToken, clearToken } from "../auth.js";

describe("embedUrl()", () => {
  it("builds profile embed URL", () => {
    const url = embedUrl({ username: "alice" });
    expect(url).toBe("https://misar.blog/alice/embed");
  });

  it("builds post embed URL with slug", () => {
    const url = embedUrl({ username: "alice", slug: "my-post" });
    expect(url).toBe("https://misar.blog/alice/my-post/embed");
  });

  it("appends theme param when not auto", () => {
    const url = embedUrl({ username: "alice", theme: "dark" });
    expect(url).toBe("https://misar.blog/alice/embed?theme=dark");
  });

  it("omits theme param when auto", () => {
    const url = embedUrl({ username: "alice", theme: "auto" });
    expect(url).not.toContain("theme=");
  });

  it("light theme param", () => {
    const url = embedUrl({ username: "bob", slug: "post", theme: "light" });
    expect(url).toContain("theme=light");
  });
});

describe("embed()", () => {
  let container: HTMLDivElement;

  beforeEach(() => {
    container = document.createElement("div");
    document.body.appendChild(container);
  });

  it("appends iframe to container", () => {
    embed(container, { username: "alice" });
    expect(container.querySelector("iframe")).not.toBeNull();
  });

  it("sets iframe src correctly", () => {
    const { iframe } = embed(container, { username: "alice", slug: "post" });
    expect(iframe.src).toBe("https://misar.blog/alice/post/embed");
  });

  it("uses default width and height", () => {
    const { iframe } = embed(container, { username: "alice" });
    expect(iframe.width).toBe("100%");
    expect(iframe.height).toBe("600px");
  });

  it("respects custom width and height", () => {
    const { iframe } = embed(container, { username: "alice", width: "800px", height: "400px" });
    expect(iframe.width).toBe("800px");
    expect(iframe.height).toBe("400px");
  });

  it("sets className when provided", () => {
    const { iframe } = embed(container, { username: "alice", className: "my-embed" });
    expect(iframe.className).toBe("my-embed");
  });

  it("has lazy loading and clipboard-write allow", () => {
    const { iframe } = embed(container, { username: "alice" });
    expect(iframe.loading).toBe("lazy");
    expect(iframe.allow).toBe("clipboard-write");
  });

  it("destroy() removes iframe from DOM", () => {
    const { destroy } = embed(container, { username: "alice" });
    expect(container.querySelector("iframe")).not.toBeNull();
    destroy();
    expect(container.querySelector("iframe")).toBeNull();
  });
});

describe("auth helpers", () => {
  beforeEach(() => {
    clearToken();
    vi.restoreAllMocks();
  });

  it("getToken() returns null when not set", () => {
    expect(getToken()).toBeNull();
  });

  it("clearToken() removes stored token", () => {
    localStorage.setItem("misar_blog_token", "tok");
    clearToken();
    expect(getToken()).toBeNull();
  });

  it("refreshToken() stores and returns token on success", async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ token: "new-tok", expiresAt: 9999999999 }),
    } as Response);

    const result = await refreshToken({ token: "old-tok" });
    expect(result.token).toBe("new-tok");
    expect(getToken()).toBe("new-tok");
  });

  it("refreshToken() throws on non-ok response", async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      json: async () => ({ error: "Unauthorized" }),
    } as Response);

    await expect(refreshToken({ token: "bad-tok" })).rejects.toThrow("Unauthorized");
  });

  it("refreshToken() uses custom baseUrl", async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ token: "tok2", expiresAt: 1 }),
    } as Response);

    await refreshToken({ token: "t", baseUrl: "https://staging.misar.blog" });
    expect(vi.mocked(global.fetch)).toHaveBeenCalledWith(
      "https://staging.misar.blog/api/auth/refresh",
      expect.any(Object)
    );
  });
});
