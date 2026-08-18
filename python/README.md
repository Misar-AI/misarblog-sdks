# Misar.Blog Python SDK

[Misar.Blog](https://misar.blog) is a hosted blogging platform. Authors write in
Markdown, publish or schedule articles, group them into series, and get
comments, reactions, follows, subscriber- and paid-gated posts, AI writing
helpers and per-account analytics. This package is the official Python client
for its developer API at `https://api.misar.io/blog/v1` — for anyone automating
publishing, syncing a blog out of CI or another CMS, or building a reader,
dashboard or integration on top of a Misar.Blog account.

## Features

The API surface this SDK covers, in full:

- **Articles** — list and filter by status, visibility or webhook-only, fetch by
  slug or UUID, publish or schedule from Markdown, update in place, and save
  drafts.
- **Series** — list, create, and add an article at a position.
- **Reactions** — `like` / `clap` / `bookmark` counts plus the caller's own
  reactions; add and remove.
- **Comments** — read an article's thread, newest first, replies nested one
  level deep.
- **Follows** — a profile's follower/following counts and whether the key's
  owner follows it.
- **AI** — SEO/AEO/GEO title suggestions (`suggest` from existing copy, `seo`
  from a keyword) and free-form system + user completions.
- **Images** — AI cover-image generation (`1024x1024`, `1792x1024`,
  `1024x1792`) and multipart CDN upload.
- **Discovery** — full-text search across articles, profiles and tags, and
  related-article recommendations.
- **Account** — the authenticated profile, an analytics summary (views,
  gross/net revenue, active subscribers), live plan and quota, the self-serve
  trial, and the upsell funnel (platform-admin keys only).
- **Embeds** — build a public iframe URL for a profile or a single article.
  Unauthenticated and unmetered.

That is all 25 key-authenticated operations.

## What's in the package

- `MisarBlogClient` — the client, both sync and async in one object.
  `MisarBlogClient(api_key, base_url=..., max_retries=3, timeout=30.0)`.
- Resource attributes: `articles`, `series`, `reactions`, `comments`,
  `follows`, `ai`, `images`, `me`, `analytics`, `plan`, `trial`,
  `upsell_funnel`.
- **Every method has an `a`-prefixed async twin** — `list` / `alist`,
  `publish` / `apublish`, `get` / `aget`, and so on. Both share one client;
  close with `close()` / `await aclose()`, or use `with` / `async with`.
- Errors: `MisarBlogError`, `MisarBlogPlanLimitError`, `MisarBlogNetworkError`.
- `embed_url(username, slug=None, theme="auto")` — pure string building for
  public embeds.
- `misarblog.models` — `TypedDict` shapes and `Literal` enums (`ArticleStatus`,
  `ArticleVisibility`, `ReactionType`, `ImageSize`, `SearchSort`, …). Responses
  are plain `dict` at runtime; the models are for static typing.
- `DEFAULT_BASE_URL` for overriding or asserting the endpoint.

**Transport.** Built on `httpx`. Base URL `https://api.misar.io/blog/v1`; the
key goes on `Authorization: Bearer`. Statuses 429/500/502/503/504 and transport
failures are retried up to `max_retries` attempts (default 3) with exponential
back-off from 200 ms; the final attempt is always sent. Per-request timeout
defaults to 30 s. Optional `transport=` / `atransport=` let tests inject an
`httpx` transport.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

## Install

```bash
pip install misarblog
```

Python 3.9+. Pulls in `httpx>=0.27`.

## Quick start

```python
import os
from misarblog import MisarBlogClient

blog = MisarBlogClient(os.environ["MISARBLOG_API_KEY"])

me = blog.me.get()
print(f"authenticated as @{me['username']}")

article = blog.articles.publish(
    title="Shipping a blog from CI",
    body_markdown="# Shipping a blog from CI\n\nMarkdown in, article out.",
    tags=["ci", "automation"],
)
print(article["url"])

blog.close()
```

Async, same surface:

```python
import asyncio
from misarblog import MisarBlogClient

async def main():
    async with MisarBlogClient("mbk_...") as blog:
        me = await blog.me.aget()
        await blog.articles.apublish(title="Hello", body_markdown="# Hi")
        print(me["username"])

asyncio.run(main())
```

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
itself is a cookie-session flow and is deliberately not exposed here.

## Primary functions

### Publish (or schedule) an article

```python
article = blog.articles.publish(
    title="Hello, Misar",
    body_markdown="# Hello\n\nFirst post.",
    tags=["intro"],
    cover_image_url="https://cdn.example.com/cover.png",
    visibility="public",                 # public | subscribers | paid | private | webhook_only
    schedule_at="2026-09-01T09:00:00Z",  # omit to publish immediately
)
print(article["slug"], article["status"], article["url"])
```

### Save a draft

```python
draft = blog.articles.create_draft(
    title="Work in progress",
    body_markdown="Notes so far…",
    tags=["draft"],
)
print(draft["editor_url"])  # open in the Misar.Blog editor
```

### List your articles

```python
result = blog.articles.list(status="published", limit=20)
for a in result["articles"]:
    print(a["slug"], a["view_count"])
print(len(result["articles"]), "of", result["total"])
```

`status` accepts `draft`, `published`, `scheduled`, `archived`, `flagged` or
`all`; `visibility`, `webhook_only` and `sort` narrow it further.

### Update an article — and publish a draft

```python
updated = blog.articles.update(
    "work-in-progress",
    title="Finished at last",
    body_markdown="The complete post.",
    publish=True,  # flips a draft to published in the same call
)
print(updated["status"], updated["published_at"])
```

### Read an article's comment thread

```python
thread = blog.comments.list(article["id"], limit=50, offset=0)
for c in thread["comments"]:
    print(f"@{c['user']['username']}: {c['content']} ({c['reply_count']} replies)")
print(thread["totalCount"], thread["hasMore"])
```

### Read and add reactions

```python
counts = blog.reactions.get(article["id"])
print(counts["counts"], counts["total"], counts["user_reactions"])

blog.reactions.add(article["id"], "clap")     # like | clap | bookmark
blog.reactions.remove(article["id"], "clap")
```

### Generate SEO titles

```python
result = blog.ai.titles("seo", prompt="shipping a static blog from GitHub Actions")
for t in result["titles"]:
    print(t["title"], "—", t["hint"])
```

Pass `"suggest"` with `context=<article text>` to get titles from copy you
already have.

### Read the analytics summary

```python
summary = blog.analytics.summary(days=30)
print(summary["views"], summary["revenue_cents"], summary["active_subscribers"])
```

### Generate or upload a cover image

```python
image = blog.images.generate("a dark editorial illustration of a printing press",
                             size="1792x1024")
print(image["url"])

with open("cover.png", "rb") as fh:
    uploaded = blog.images.upload(fh, filename="cover.png", content_type="image/png")
print(uploaded["url"])
```

### Embed a public article

```python
from misarblog import embed_url

print(embed_url("gulshan", slug="hello-misar", theme="dark"))
```

## Errors

Every failure raises. All three types derive from `MisarBlogError`, so a single
`except MisarBlogError` catches everything.

| Type | Raised when | Extra attributes |
| --- | --- | --- |
| `MisarBlogError` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `status`, `error_type`, `payload`, and on 403 `required_scope` / `granted_scopes` |
| `MisarBlogPlanLimitError` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `plan`, `upgrade_url`, `retry_after`, `upgrade` |
| `MisarBlogNetworkError` | The request never reached the API — DNS, TLS, connection, timeout — or the retry budget was exhausted | `cause`; `status` is `0` |

```python
from misarblog import MisarBlogError, MisarBlogNetworkError, MisarBlogPlanLimitError

try:
    blog.ai.complete(prompt="Draft an intro paragraph")
except MisarBlogPlanLimitError as err:
    # Route the reader to checkout instead of reporting a bare failure.
    print(f"{err.plan} plan is out of credits — upgrade at {err.upgrade_url}")
except MisarBlogNetworkError as err:
    print("could not reach the API:", err.cause)
except MisarBlogError as err:
    print(err.status, err.required_scope)
```

`MisarBlogPlanLimitError` and `MisarBlogNetworkError` both subclass
`MisarBlogError`, so order your `except` clauses narrowest-first.

## Links

- Misar.Blog — <https://misar.blog>
- API docs — <https://docs.misar.io/blog>
- OpenAPI spec — <https://api.misar.io/blog/v1/openapi.json>
- Mint an API key — <https://www.misar.blog/dashboard/settings/api>

## License

MIT — see [LICENSE](LICENSE).
