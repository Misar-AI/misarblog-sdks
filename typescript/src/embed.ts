export interface EmbedOptions {
  username: string;
  slug?: string;
  theme?: "light" | "dark" | "auto";
  width?: string;
  height?: string;
  className?: string;
}

export interface EmbedResult {
  iframe: HTMLIFrameElement;
  destroy: () => void;
}

const EMBED_BASE = "https://misar.blog";

export function embed(container: HTMLElement, options: EmbedOptions): EmbedResult {
  const { username, slug, theme = "auto", width = "100%", height = "600px", className } = options;
  const path = slug ? `/${username}/${slug}/embed` : `/${username}/embed`;
  const url = new URL(path, EMBED_BASE);
  if (theme !== "auto") url.searchParams.set("theme", theme);

  const iframe = document.createElement("iframe");
  iframe.src = url.toString();
  iframe.width = width;
  iframe.height = height;
  iframe.style.border = "none";
  iframe.loading = "lazy";
  iframe.allow = "clipboard-write";
  if (className) iframe.className = className;

  container.appendChild(iframe);

  return {
    iframe,
    destroy: () => iframe.remove(),
  };
}

export function embedUrl(options: EmbedOptions): string {
  const { username, slug, theme = "auto" } = options;
  const path = slug ? `/${username}/${slug}/embed` : `/${username}/embed`;
  const url = new URL(path, EMBED_BASE);
  if (theme !== "auto") url.searchParams.set("theme", theme);
  return url.toString();
}
