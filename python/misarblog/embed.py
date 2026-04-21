from urllib.parse import urlencode

EMBED_BASE = "https://misar.blog"


def embed_url(username: str, slug: str | None = None, theme: str = "auto") -> str:
    path = f"{username}/{slug}/embed" if slug else f"{username}/embed"
    url = f"{EMBED_BASE}/{path}"
    if theme != "auto":
        url = f"{url}?{urlencode({'theme': theme})}"
    return url
