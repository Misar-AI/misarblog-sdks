import httpx

EMBED_BASE = "https://misar.blog"


def refresh_token(token: str, base_url: str = EMBED_BASE) -> dict:
    response = httpx.post(
        f"{base_url}/api/auth/refresh",
        json={"token": token},
    )
    response.raise_for_status()
    return response.json()
