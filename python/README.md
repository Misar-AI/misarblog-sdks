# Misar.Blog Python SDK

> Sync and async client for the Misar.Blog developer API — publish, schedule and manage Markdown articles from Python.

[![PyPI](https://img.shields.io/pypi/v/misarblog)](https://pypi.org/project/misarblog/) [![Python](https://img.shields.io/badge/python-3.9%2B-blue)](https://www.python.org) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**12 resource attributes · 25 operations · sync and async from one client**

Works against the Misar.Blog developer API at `https://api.misar.io/blog/v1` — for
anyone automating publishing, syncing a blog out of CI or another CMS, or building
a reader, dashboard or integration on top of a Misar.Blog account.

---

## Install

### pip

```bash
pip install misarblog
```

### uv

```bash
uv add misarblog
```

### poetry

```bash
poetry add misarblog
```

Python 3.9+. Pulls in `httpx>=0.27`.

---

## Authentication

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_` and go on the `Authorization: Bearer` header; an OAuth 2.1 access token
works on the same header. Key management itself is a cookie-session flow and is
deliberately not exposed here.

Feature access and throughput follow the subscription attached to the key. The
machine-readable contract for every route below is the OpenAPI spec at
<https://api.misar.io/blog/v1/openapi.json>.

---

## API surface

Every sync method listed here has an `a`-prefixed async twin — the rule is a
literal `a` in front of the sync name, so `list` / `alist`, `publish` /
`apublish`, `create_draft` / `acreate_draft`, `add_article` / `aadd_article`,
and so on for all 25. Both halves share one client.

| Resource | Method | Endpoint | What it does |
| --- | --- | --- | --- |
| `articles` | `list` | `GET /articles` | list your articles, filtered by status/visibility/sort |
| `articles` | `get` | `GET /articles/{slug}` | fetch one article by slug or UUID, full Markdown body |
| `articles` | `publish` | `POST /articles` | publish or schedule an article from Markdown |
| `articles` | `update` | `PATCH /articles/{slug}` | update title/body/tags in place; `publish: true` flips a draft live |
| `articles` | `create_draft` | `POST /drafts` | save a draft without publishing |
| `articles` | `search` | `GET /search` | full-text search across articles, profiles and tags |
| `articles` | `recommendations` | `GET /recommendations` | related articles for an article id |
| `series` | `list` | `GET /series` | list your series |
| `series` | `create` | `POST /series` | create a series |
| `series` | `add_article` | `POST /series/{slug}/articles` | add an article to a series at a position |
| `reactions` | `get` | `GET /reactions` | reaction counts and the caller's own reactions |
| `reactions` | `add` | `POST /reactions` | add a `like` / `clap` / `bookmark` |
| `reactions` | `remove` | `DELETE /reactions` | remove a reaction |
| `comments` | `list` | `GET /comments` | an article's comment thread, newest first, replies one level deep |
| `follows` | `status` | `GET /follows` | follower/following counts and whether the key's owner follows |
| `ai` | `complete` | `POST /ai/complete` | free-form system + user completion |
| `ai` | `titles` | `POST /ai/titles` | SEO/AEO/GEO title suggestions (`seo` from a keyword, `suggest` from copy) |
| `images` | `generate` | `POST /images/generate` | AI cover image (`1024x1024`, `1792x1024`, `1024x1792`) |
| `images` | `upload` | `POST /images/upload` | upload an image to the CDN |
| `me` | `get` | `GET /me` | the authenticated creator profile |
| `analytics` | `summary` | `GET /analytics` | views, gross/net revenue, active subscribers for trailing N days |
| `plan` | `get` | `GET /plan` | live plan and per-feature quota |
| `trial` | `status` | `GET /trial` | whether a self-serve trial is active |
| `trial` | `start` | `POST /trial` | start a self-serve trial |
| `upsell_funnel` | `get` | `GET /upsell-funnel` | per-feature upsell funnel (platform-admin keys only; a creator key gets 403) |

That is all 25 key-authenticated operations — 50 callables counting the async
twins.

---

## What's in the package

| Item | What it is |
| --- | --- |
| `MisarBlogClient` | The client, both sync and async in one object. `MisarBlogClient(api_key, base_url=..., max_retries=3, timeout=30.0)`. |
| Resource attributes | `articles`, `series`, `reactions`, `comments`, `follows`, `ai`, `images`, `me`, `analytics`, `plan`, `trial`, `upsell_funnel` — the 12 groups in the table above. |
| Async twins | Every method has an `a`-prefixed async form. Close with `close()` / `await aclose()`, or use `with` / `async with`. |
| `MisarBlogError`, `MisarBlogPlanLimitError`, `MisarBlogNetworkError` | The three error types; the latter two subclass the first. |
| `embed_url(username, slug=None, theme="auto")` | Pure string building for public embeds. Unauthenticated and unmetered. |
| `misarblog.models` | `TypedDict` shapes and `Literal` enums (`ArticleStatus`, `ArticleVisibility`, `ReactionType`, `ImageSize`, `SearchSort`, …). Responses are plain `dict` at runtime; the models are for static typing. |
| `DEFAULT_BASE_URL` | The endpoint constant, for overriding or asserting against. |

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

---

## Examples

### Authenticate and publish

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

### The same, async

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

---

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

---

## Links

- Website — https://www.misar.blog
- App — https://www.misar.blog
- Parent — https://misar.io
- Documentation — https://docs.misar.io/blog
- Source — https://github.com/Misar-AI/misarblog-sdks
- PyPI — https://pypi.org/project/misarblog/

MIT © [Misar AI](https://misar.io)
