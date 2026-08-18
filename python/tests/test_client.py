"""Tests for MisarBlogClient using httpx MockTransport (no network, no respx)."""

from __future__ import annotations

import httpx
import pytest

from misarblog import MisarBlogClient, MisarBlogError

BASE = "https://api.misar.io/blog/v1"


def make_client(handler, **kwargs) -> MisarBlogClient:
    return MisarBlogClient(
        api_key="mbk_test",
        transport=httpx.MockTransport(handler),
        atransport=httpx.MockTransport(handler),
        **kwargs,
    )


def test_base_url_has_no_api_prefix():
    client = MisarBlogClient("mbk_test")
    assert client._base_url == BASE
    assert client._base_url.endswith("/blog/v1")
    assert "/api/" not in client._base_url  # gateway strips /api


def test_get_profile():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/blog/v1/me"
        assert request.headers["Authorization"] == "Bearer mbk_test"
        return httpx.Response(200, json={"id": "u1", "username": "gulshan"})

    with make_client(handler) as blog:
        me = blog.me.get()
        assert me["username"] == "gulshan"


def test_list_articles_query_params():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/blog/v1/articles"
        assert request.url.params.get("status") == "published"
        assert request.url.params.get("limit") == "5"
        # `status == "all"` should be omitted; here it's "published"
        return httpx.Response(200, json={"articles": [], "total": 0})

    with make_client(handler) as blog:
        res = blog.articles.list(status="published", limit=5)
        assert res["total"] == 0


def test_publish_article_body():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "POST"
        assert request.url.path == "/blog/v1/articles"
        import json
        body = json.loads(request.content)
        assert body["title"] == "Hello"
        assert body["body_markdown"] == "# Hi"
        assert "schedule_at" not in body  # None dropped
        return httpx.Response(200, json={"id": "a1", "slug": "hello", "status": "published"})

    with make_client(handler) as blog:
        res = blog.articles.publish(title="Hello", body_markdown="# Hi")
        assert res["slug"] == "hello"


def test_reactions_remove_uses_query():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "DELETE"
        assert request.url.path == "/blog/v1/reactions"
        assert request.url.params.get("article_id") == "a1"
        assert request.url.params.get("type") == "clap"
        return httpx.Response(200, json={"success": True, "reacted": False})

    with make_client(handler) as blog:
        res = blog.reactions.remove("a1", "clap")
        assert res["success"] is True


def test_ai_titles():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/blog/v1/ai/titles"
        return httpx.Response(200, json={"titles": [{"title": "T", "hint": "h"}], "raw": "T"})

    with make_client(handler) as blog:
        res = blog.ai.titles("seo", prompt="ai writing tools")
        assert res["titles"][0]["title"] == "T"


def test_series_add_article_path():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/blog/v1/series/my-series/articles"
        return httpx.Response(200, json={"ok": True})

    with make_client(handler) as blog:
        assert blog.series.add_article("my-series", "some-slug", position=2)["ok"] is True


def test_error_401_raises():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(401, json={"error": "unauthorized"})

    with make_client(handler) as blog:
        with pytest.raises(MisarBlogError) as exc:
            blog.me.get()
        assert exc.value.status == 401


def test_error_403_scope_fields():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403, json={
            "error": "insufficient scope",
            "required_scope": "articles:write",
            "granted_scopes": ["articles:read"],
        })

    with make_client(handler) as blog:
        with pytest.raises(MisarBlogError) as exc:
            blog.articles.publish(title="x", body_markdown="y")
        assert exc.value.required_scope == "articles:write"
        assert exc.value.granted_scopes == ["articles:read"]


def test_retry_then_success(monkeypatch):
    import misarblog.client as mod
    monkeypatch.setattr(mod.time, "sleep", lambda *_: None)

    calls = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        if calls["n"] < 3:
            return httpx.Response(503, json={"error": "unavailable"})
        return httpx.Response(200, json={"id": "u1"})

    with make_client(handler, max_retries=3) as blog:
        res = blog.me.get()
        assert res["id"] == "u1"
        assert calls["n"] == 3  # sent on the final attempt, no off-by-one


def test_retry_exhausted_raises_last_status(monkeypatch):
    import misarblog.client as mod
    monkeypatch.setattr(mod.time, "sleep", lambda *_: None)

    calls = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        return httpx.Response(503, json={"error": "unavailable"})

    with make_client(handler, max_retries=3) as blog:
        with pytest.raises(MisarBlogError) as exc:
            blog.me.get()
        assert exc.value.status == 503
        assert calls["n"] == 3  # exactly max_retries sends


@pytest.mark.asyncio
async def test_async_get_profile():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"id": "u1", "username": "async"})

    blog = make_client(handler)
    me = await blog.me.aget()
    assert me["username"] == "async"
    await blog.aclose()
