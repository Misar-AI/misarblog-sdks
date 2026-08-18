"""Synchronous + asynchronous client for the Misar.Blog developer API.

Base URL is ``https://api.misar.io/blog/v1`` — the blog gateway strips ``/api``,
so paths here never carry an ``/api`` prefix. Authenticate with a developer key
(``mbk_...``) or an OAuth 2.1 access token, both sent as a Bearer token.

Sync usage::

    from misarblog import MisarBlogClient

    blog = MisarBlogClient("mbk_...")
    me = blog.me.get()
    blog.articles.publish(title="Hello", body_markdown="# Hi")

Async usage::

    blog = MisarBlogClient("mbk_...")
    me = await blog.me.aget()
    await blog.aclose()
"""

from __future__ import annotations

import asyncio
import time
from typing import Any, Optional, Union

import httpx

from .errors import MisarBlogError, MisarBlogNetworkError, MisarBlogPlanLimitError
from .models import (
    AnalyticsSummary,
    Article,
    ArticleListResult,
    ArticleReactions,
    ArticleStatus,
    ArticleVisibility,
    CommentsResult,
    CompletionResponse,
    FollowStatus,
    GeneratedImage,
    ImageSize,
    Plan,
    Profile,
    ReactionType,
    RecommendationsResult,
    SearchResult,
    SearchSort,
    SearchType,
    Series,
    SeriesListResult,
    TitleAction,
    TitlesResponse,
    TrialStatus,
)

__all__ = ["MisarBlogClient", "DEFAULT_BASE_URL"]

DEFAULT_BASE_URL = "https://api.misar.io/blog/v1"
RETRY_BASE_S = 0.2
RETRYABLE = {429, 500, 502, 503, 504}


def _clean(d: Optional[dict[str, Any]]) -> Optional[dict[str, Any]]:
    """Drop ``None`` values so optional query/body fields are omitted."""
    if d is None:
        return None
    return {k: v for k, v in d.items() if v is not None}


class _MisarBlogCore:
    _api_key: str
    _base_url: str
    _max_retries: int
    _timeout: float
    _transport: Optional[httpx.BaseTransport]
    _atransport: Optional[httpx.AsyncBaseTransport]
    _client: Optional[httpx.Client]
    _aclient: Optional[httpx.AsyncClient]

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self._api_key}",
            "Accept": "application/json",
        }

    def _sync(self) -> httpx.Client:
        if self._client is None:
            self._client = httpx.Client(
                base_url=self._base_url,
                timeout=self._timeout,
                transport=self._transport,
            )
        return self._client

    def _async(self) -> httpx.AsyncClient:
        if self._aclient is None:
            self._aclient = httpx.AsyncClient(
                base_url=self._base_url,
                timeout=self._timeout,
                transport=self._atransport,
            )
        return self._aclient

    @staticmethod
    def _decode(resp: httpx.Response) -> dict[str, Any]:
        try:
            if resp.content:
                parsed = resp.json()
                if isinstance(parsed, dict):
                    return parsed
        except ValueError:
            pass
        return {}

    @staticmethod
    def _is_plan_limit(data: dict[str, Any]) -> bool:
        return data.get("code") == "plan_limit_exceeded"

    def _handle(self, resp: httpx.Response) -> dict[str, Any]:
        if not resp.is_success:
            data = self._decode(resp)
            err = data.get("error")
            message = err if isinstance(err, str) else (resp.reason_phrase or "unknown error")
            if self._is_plan_limit(data):
                raise MisarBlogPlanLimitError(
                    resp.status_code, message, data, dict(resp.headers)
                )
            raise MisarBlogError(resp.status_code, message, payload=data)
        return resp.json() if resp.content else {}

    def _request(
        self,
        method: str,
        path: str,
        body: Optional[dict[str, Any]] = None,
        *,
        params: Optional[dict[str, Any]] = None,
        files: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        client = self._sync()
        last_exc: Optional[Exception] = None
        for attempt in range(self._max_retries):
            try:
                resp = client.request(
                    method,
                    path,
                    headers=self._headers(),
                    params=_clean(params),
                    json=body if files is None else None,
                    files=files,
                )
                # A plan-limit 429 is not a "slow down" — retrying cannot help
                # until the allowance resets or the plan changes, so surface it
                # immediately instead of burning the retry budget.
                if (
                    resp.status_code in RETRYABLE
                    and attempt < self._max_retries - 1
                    and not self._is_plan_limit(self._decode(resp))
                ):
                    time.sleep(RETRY_BASE_S * (2**attempt))
                    continue
                return self._handle(resp)
            except MisarBlogError:
                raise
            except Exception as exc:  # transport-level failure
                last_exc = exc
                if attempt < self._max_retries - 1:
                    time.sleep(RETRY_BASE_S * (2**attempt))
                    continue
                raise MisarBlogNetworkError(str(exc), exc) from exc
        raise MisarBlogNetworkError("max retries exceeded", last_exc)

    async def _arequest(
        self,
        method: str,
        path: str,
        body: Optional[dict[str, Any]] = None,
        *,
        params: Optional[dict[str, Any]] = None,
        files: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        client = self._async()
        last_exc: Optional[Exception] = None
        for attempt in range(self._max_retries):
            try:
                resp = await client.request(
                    method,
                    path,
                    headers=self._headers(),
                    params=_clean(params),
                    json=body if files is None else None,
                    files=files,
                )
                if (
                    resp.status_code in RETRYABLE
                    and attempt < self._max_retries - 1
                    and not self._is_plan_limit(self._decode(resp))
                ):
                    await asyncio.sleep(RETRY_BASE_S * (2**attempt))
                    continue
                return self._handle(resp)
            except MisarBlogError:
                raise
            except Exception as exc:
                last_exc = exc
                if attempt < self._max_retries - 1:
                    await asyncio.sleep(RETRY_BASE_S * (2**attempt))
                    continue
                raise MisarBlogNetworkError(str(exc), exc) from exc
        raise MisarBlogNetworkError("max retries exceeded", last_exc)


class _Resource:
    def __init__(self, client: _MisarBlogCore) -> None:
        self._c = client


# ── Articles (+ drafts, search, recommendations) ─────────────────────────────

class _ArticlesResource(_Resource):
    def list(
        self,
        *,
        status: Optional[ArticleStatus] = None,
        visibility: Optional[ArticleVisibility] = None,
        webhook_only: Optional[bool] = None,
        sort: Optional[str] = None,
        limit: Optional[int] = None,
    ) -> ArticleListResult:
        return self._c._request("GET", "/articles", params=self._list_params(
            status, visibility, webhook_only, sort, limit))

    async def alist(
        self,
        *,
        status: Optional[ArticleStatus] = None,
        visibility: Optional[ArticleVisibility] = None,
        webhook_only: Optional[bool] = None,
        sort: Optional[str] = None,
        limit: Optional[int] = None,
    ) -> ArticleListResult:
        return await self._c._arequest("GET", "/articles", params=self._list_params(
            status, visibility, webhook_only, sort, limit))

    @staticmethod
    def _list_params(status, visibility, webhook_only, sort, limit) -> dict[str, Any]:
        return {
            "status": status if status and status != "all" else None,
            "visibility": visibility,
            "webhook_only": None if webhook_only is None else ("true" if webhook_only else "false"),
            "sort": sort,
            "limit": limit,
        }

    def get(self, slug: str) -> Article:
        return self._c._request("GET", f"/articles/{slug}")

    async def aget(self, slug: str) -> Article:
        return await self._c._arequest("GET", f"/articles/{slug}")

    def publish(
        self,
        *,
        title: str,
        body_markdown: str,
        tags: Optional[list[str]] = None,
        cover_image_url: Optional[str] = None,
        schedule_at: Optional[str] = None,
        visibility: Optional[ArticleVisibility] = None,
    ) -> dict[str, Any]:
        return self._c._request("POST", "/articles", _clean({
            "title": title,
            "body_markdown": body_markdown,
            "tags": tags,
            "cover_image_url": cover_image_url,
            "schedule_at": schedule_at,
            "visibility": visibility,
        }))

    async def apublish(
        self,
        *,
        title: str,
        body_markdown: str,
        tags: Optional[list[str]] = None,
        cover_image_url: Optional[str] = None,
        schedule_at: Optional[str] = None,
        visibility: Optional[ArticleVisibility] = None,
    ) -> dict[str, Any]:
        return await self._c._arequest("POST", "/articles", _clean({
            "title": title,
            "body_markdown": body_markdown,
            "tags": tags,
            "cover_image_url": cover_image_url,
            "schedule_at": schedule_at,
            "visibility": visibility,
        }))

    def update(
        self,
        slug: str,
        *,
        title: Optional[str] = None,
        body_markdown: Optional[str] = None,
        tags: Optional[list[str]] = None,
        publish: Optional[bool] = None,
    ) -> dict[str, Any]:
        return self._c._request("PATCH", f"/articles/{slug}", _clean({
            "title": title,
            "body_markdown": body_markdown,
            "tags": tags,
            "publish": publish,
        }))

    async def aupdate(
        self,
        slug: str,
        *,
        title: Optional[str] = None,
        body_markdown: Optional[str] = None,
        tags: Optional[list[str]] = None,
        publish: Optional[bool] = None,
    ) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/articles/{slug}", _clean({
            "title": title,
            "body_markdown": body_markdown,
            "tags": tags,
            "publish": publish,
        }))

    def create_draft(
        self,
        *,
        title: str,
        body_markdown: str,
        tags: Optional[list[str]] = None,
    ) -> dict[str, Any]:
        return self._c._request("POST", "/drafts", _clean({
            "title": title, "body_markdown": body_markdown, "tags": tags}))

    async def acreate_draft(
        self,
        *,
        title: str,
        body_markdown: str,
        tags: Optional[list[str]] = None,
    ) -> dict[str, Any]:
        return await self._c._arequest("POST", "/drafts", _clean({
            "title": title, "body_markdown": body_markdown, "tags": tags}))

    def search(
        self,
        *,
        q: Optional[str] = None,
        type: Optional[SearchType] = None,
        tag: Optional[str] = None,
        author: Optional[str] = None,
        sort: Optional[SearchSort] = None,
        from_: Optional[str] = None,
        to: Optional[str] = None,
        limit: Optional[int] = None,
    ) -> SearchResult:
        return self._c._request("GET", "/search", params={
            "q": q, "type": type, "tag": tag, "author": author,
            "sort": sort, "from": from_, "to": to, "limit": limit})

    async def asearch(
        self,
        *,
        q: Optional[str] = None,
        type: Optional[SearchType] = None,
        tag: Optional[str] = None,
        author: Optional[str] = None,
        sort: Optional[SearchSort] = None,
        from_: Optional[str] = None,
        to: Optional[str] = None,
        limit: Optional[int] = None,
    ) -> SearchResult:
        return await self._c._arequest("GET", "/search", params={
            "q": q, "type": type, "tag": tag, "author": author,
            "sort": sort, "from": from_, "to": to, "limit": limit})

    def recommendations(self, article_id: str, *, limit: Optional[int] = None) -> RecommendationsResult:
        return self._c._request("GET", "/recommendations",
                                 params={"article_id": article_id, "limit": limit})

    async def arecommendations(self, article_id: str, *, limit: Optional[int] = None) -> RecommendationsResult:
        return await self._c._arequest("GET", "/recommendations",
                                       params={"article_id": article_id, "limit": limit})


# ── AI ───────────────────────────────────────────────────────────────────────

class _AiResource(_Resource):
    def complete(self, prompt: str, *, system: Optional[str] = None,
                 max_tokens: Optional[int] = None) -> CompletionResponse:
        return self._c._request("POST", "/ai/complete", _clean({
            "prompt": prompt, "system": system, "max_tokens": max_tokens}))

    async def acomplete(self, prompt: str, *, system: Optional[str] = None,
                        max_tokens: Optional[int] = None) -> CompletionResponse:
        return await self._c._arequest("POST", "/ai/complete", _clean({
            "prompt": prompt, "system": system, "max_tokens": max_tokens}))

    def titles(self, action: TitleAction, *, prompt: Optional[str] = None,
               context: Optional[str] = None) -> TitlesResponse:
        return self._c._request("POST", "/ai/titles", _clean({
            "action": action, "prompt": prompt, "context": context}))

    async def atitles(self, action: TitleAction, *, prompt: Optional[str] = None,
                     context: Optional[str] = None) -> TitlesResponse:
        return await self._c._arequest("POST", "/ai/titles", _clean({
            "action": action, "prompt": prompt, "context": context}))


# ── Images ─────────────────────────────────────────────────────────────────────

class _ImagesResource(_Resource):
    def generate(self, prompt: str, *, size: Optional[ImageSize] = None) -> GeneratedImage:
        return self._c._request("POST", "/images/generate", _clean({
            "prompt": prompt, "size": size}))

    async def agenerate(self, prompt: str, *, size: Optional[ImageSize] = None) -> GeneratedImage:
        return await self._c._arequest("POST", "/images/generate", _clean({
            "prompt": prompt, "size": size}))

    def upload(
        self,
        file: Union[bytes, Any],
        *,
        filename: str = "image",
        content_type: Optional[str] = None,
    ) -> dict[str, Any]:
        return self._c._request("POST", "/images/upload",
                                files={"file": (filename, file, content_type)})

    async def aupload(
        self,
        file: Union[bytes, Any],
        *,
        filename: str = "image",
        content_type: Optional[str] = None,
    ) -> dict[str, Any]:
        return await self._c._arequest("POST", "/images/upload",
                                       files={"file": (filename, file, content_type)})


# ── Analytics ──────────────────────────────────────────────────────────────────

class _AnalyticsResource(_Resource):
    def summary(self, *, days: Optional[int] = None) -> AnalyticsSummary:
        return self._c._request("GET", "/analytics", params={"days": days})

    async def asummary(self, *, days: Optional[int] = None) -> AnalyticsSummary:
        return await self._c._arequest("GET", "/analytics", params={"days": days})


# ── Me / Profile ───────────────────────────────────────────────────────────────

class _MeResource(_Resource):
    def get(self) -> Profile:
        return self._c._request("GET", "/me")

    async def aget(self) -> Profile:
        return await self._c._arequest("GET", "/me")


# ── Plan ───────────────────────────────────────────────────────────────────────

class _PlanResource(_Resource):
    def get(self) -> Plan:
        return self._c._request("GET", "/plan")

    async def aget(self) -> Plan:
        return await self._c._arequest("GET", "/plan")


# ── Reactions ──────────────────────────────────────────────────────────────────

class _ReactionsResource(_Resource):
    def get(self, article_id: str) -> ArticleReactions:
        return self._c._request("GET", "/reactions", params={"article_id": article_id})

    async def aget(self, article_id: str) -> ArticleReactions:
        return await self._c._arequest("GET", "/reactions", params={"article_id": article_id})

    def add(self, article_id: str, type: ReactionType) -> dict[str, Any]:
        return self._c._request("POST", "/reactions",
                                {"article_id": article_id, "type": type})

    async def aadd(self, article_id: str, type: ReactionType) -> dict[str, Any]:
        return await self._c._arequest("POST", "/reactions",
                                       {"article_id": article_id, "type": type})

    def remove(self, article_id: str, type: ReactionType) -> dict[str, Any]:
        return self._c._request("DELETE", "/reactions",
                                params={"article_id": article_id, "type": type})

    async def aremove(self, article_id: str, type: ReactionType) -> dict[str, Any]:
        return await self._c._arequest("DELETE", "/reactions",
                                       params={"article_id": article_id, "type": type})


# ── Series ─────────────────────────────────────────────────────────────────────

class _SeriesResource(_Resource):
    def list(self) -> SeriesListResult:
        return self._c._request("GET", "/series")

    async def alist(self) -> SeriesListResult:
        return await self._c._arequest("GET", "/series")

    def create(self, *, title: str, description: Optional[str] = None) -> Series:
        return self._c._request("POST", "/series", _clean({
            "title": title, "description": description}))

    async def acreate(self, *, title: str, description: Optional[str] = None) -> Series:
        return await self._c._arequest("POST", "/series", _clean({
            "title": title, "description": description}))

    def add_article(self, slug: str, article_slug: str, *,
                    position: Optional[int] = None) -> dict[str, Any]:
        return self._c._request("POST", f"/series/{slug}/articles", _clean({
            "article_slug": article_slug, "position": position}))

    async def aadd_article(self, slug: str, article_slug: str, *,
                          position: Optional[int] = None) -> dict[str, Any]:
        return await self._c._arequest("POST", f"/series/{slug}/articles", _clean({
            "article_slug": article_slug, "position": position}))


# ── Comments ───────────────────────────────────────────────────────────────────

class _CommentsResource(_Resource):
    def list(self, article_id: str, *, limit: Optional[int] = None,
             offset: Optional[int] = None) -> CommentsResult:
        return self._c._request("GET", "/comments", params={
            "article_id": article_id, "limit": limit, "offset": offset})

    async def alist(self, article_id: str, *, limit: Optional[int] = None,
                   offset: Optional[int] = None) -> CommentsResult:
        return await self._c._arequest("GET", "/comments", params={
            "article_id": article_id, "limit": limit, "offset": offset})


# ── Follows ────────────────────────────────────────────────────────────────────

class _FollowsResource(_Resource):
    def status(self, user_id: str) -> FollowStatus:
        return self._c._request("GET", "/follows", params={"user_id": user_id})

    async def astatus(self, user_id: str) -> FollowStatus:
        return await self._c._arequest("GET", "/follows", params={"user_id": user_id})


# ── Trial ──────────────────────────────────────────────────────────────────────

class _TrialResource(_Resource):
    def status(self) -> TrialStatus:
        return self._c._request("GET", "/trial")

    async def astatus(self) -> TrialStatus:
        return await self._c._arequest("GET", "/trial")

    def start(self, *, feature: Optional[str] = None,
              ref: Optional[str] = None) -> dict[str, Any]:
        return self._c._request("POST", "/trial", _clean({
            "feature": feature, "ref": ref}))

    async def astart(self, *, feature: Optional[str] = None,
                    ref: Optional[str] = None) -> dict[str, Any]:
        return await self._c._arequest("POST", "/trial", _clean({
            "feature": feature, "ref": ref}))


# ── Upsell Funnel (platform-admin only) ─────────────────────────────────────────

class _UpsellFunnelResource(_Resource):
    def get(self, *, days: Optional[int] = None,
            feature: Optional[str] = None) -> dict[str, Any]:
        return self._c._request("GET", "/upsell-funnel",
                                params={"days": days, "feature": feature})

    async def aget(self, *, days: Optional[int] = None,
                  feature: Optional[str] = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/upsell-funnel",
                                       params={"days": days, "feature": feature})


# ── Main Client ────────────────────────────────────────────────────────────────

class MisarBlogClient(_MisarBlogCore):
    """Client for the Misar.Blog developer API (sync + async).

    Args:
        api_key: Developer key (``mbk_...``) or OAuth 2.1 access token.
        base_url: API base. Defaults to ``https://api.misar.io/blog/v1``.
        max_retries: Total attempts for 429/5xx and transport errors.
        timeout: Per-request timeout, seconds.
        transport / atransport: Optional httpx transports (used by tests).
    """

    def __init__(
        self,
        api_key: str,
        base_url: str = DEFAULT_BASE_URL,
        max_retries: int = 3,
        timeout: float = 30.0,
        *,
        transport: Optional[httpx.BaseTransport] = None,
        atransport: Optional[httpx.AsyncBaseTransport] = None,
    ) -> None:
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._max_retries = max(1, max_retries)
        self._timeout = timeout
        self._transport = transport
        self._atransport = atransport
        self._client = None
        self._aclient = None

        self.articles = _ArticlesResource(self)
        self.ai = _AiResource(self)
        self.images = _ImagesResource(self)
        self.analytics = _AnalyticsResource(self)
        self.me = _MeResource(self)
        self.plan = _PlanResource(self)
        self.reactions = _ReactionsResource(self)
        self.series = _SeriesResource(self)
        self.comments = _CommentsResource(self)
        self.follows = _FollowsResource(self)
        self.trial = _TrialResource(self)
        self.upsell_funnel = _UpsellFunnelResource(self)

    def close(self) -> None:
        if self._client is not None:
            self._client.close()
            self._client = None

    async def aclose(self) -> None:
        if self._aclient is not None:
            await self._aclient.aclose()
            self._aclient = None

    def __enter__(self) -> "MisarBlogClient":
        return self

    def __exit__(self, *_: Any) -> None:
        self.close()

    async def __aenter__(self) -> "MisarBlogClient":
        return self

    async def __aexit__(self, *_: Any) -> None:
        await self.aclose()
