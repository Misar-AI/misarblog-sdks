// The suite this came from also covered refreshToken/getToken/clearToken
// against a ../auth.js module. No such module exists in this SDK and no
// such symbols are exported, so those six cases tested nothing that ships
// here and are dropped rather than propped up with a stub.
import { describe, it, expect, beforeEach } from "vitest";
import { embed, embedUrl } from "../embed.js";

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
