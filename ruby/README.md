# Misar.Blog Ruby SDK

> The official Ruby client for the Misar.Blog developer API.

[![gem](https://img.shields.io/gem/v/misarblog)](https://rubygems.org/gems/misarblog) [![Ruby](https://img.shields.io/badge/ruby-%3E%3D2.7-CC342D)](https://www.ruby-lang.org) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**9 resource groups · 25 operations · standard library only (net/http)**

Works with any Ruby 2.7+ program that needs to drive a
[Misar.Blog](https://www.misar.blog) account: automating publishing, syncing a
blog out of CI or another CMS, or building a reader, dashboard or integration on
top of the API at `https://api.misar.io/blog/v1`.

---

## Install

```bash
gem install misarblog
```

Or in a `Gemfile`:

```ruby
gem "misarblog", "~> 1.1"
```

Ruby 2.7+.

---

## Authentication

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
`MisarBlog.new(api_key:, base_url:, timeout:, max_retries:)` is a shorthand that
delegates to `MisarBlog::Client.new`; the key is sent as
`Authorization: Bearer`. See the first example below. The full request/response
contract is published as an OpenAPI document at
<https://api.misar.io/blog/v1/openapi.json>.

---

## API surface

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
| `account` | `profile` | `GET /me` | the authenticated creator profile |
| `account` | `plan` | `GET /plan` | live plan and per-feature quota |
| `account` | `trial_status` | `GET /trial` | whether a self-serve trial is active |
| `account` | `start_trial` | `POST /trial` | start a self-serve trial |
| `account` | `upsell_funnel` | `GET /upsell-funnel` | per-feature upsell funnel (platform-admin keys only; a creator key gets 403) |
| `analytics` | `get` | `GET /analytics` | views, gross/net revenue, active subscribers for trailing N days |

Note the two groupings that differ from the other Misar.Blog SDKs: profile,
plan, trial and upsell all hang off `account`, and the analytics summary is
`analytics.get` rather than `analytics.summary`.

---

## What's in the package

| Item | What it is |
| --- | --- |
| `MisarBlog::Client` | The client. `MisarBlog.new(api_key:, base_url:, timeout: 30, max_retries: 3)` is the shorthand constructor. Resource readers: `articles`, `series`, `reactions`, `comments`, `follows`, `ai`, `images`, `account`, `analytics`. |
| Errors | `MisarBlog::ApiError`, `MisarBlog::PlanLimitError`, `MisarBlog::NetworkError`. |
| `MisarBlog.embed_url(username:, slug:, theme:)` | Pure string building for public embeds. |
| `MisarBlog::Models` | `Article`, `ArticleList`, `Series`, `SeriesList`, `Profile`, `Plan`, `PlanUsage`, `Analytics`, `ArticleReactions`, `ReactionResult`, `TrialStatus`, `TitlesResult`, `TitleSuggestion`, `AiText`, `ImageResult`. Each wraps the decoded body: named readers for the documented fields, `#[]` for string-key access, and `#raw` / `#to_h` for the untouched Hash, so a field the API adds after this release is still reachable. |
| `client.request(method, path, data)` | Public, so an endpoint this SDK does not wrap yet is still one call away. |

**Not everything is modelled.** `comments.list`, `follows.status`,
`articles.search`, `articles.recommendations`, `account.start_trial` and
`account.upsell_funnel` return the plain decoded `Hash` with string keys.

**Transport.** Standard library only — `net/http`, `uri`, `json`; no runtime
gem dependencies. Base URL `https://api.misar.io/blog/v1`; the key goes on
`Authorization: Bearer`. Statuses 429/500/502/503/504 and connection failures
are retried up to `max_retries` attempts (default 3) with exponential back-off
from 300 ms; the final attempt is always surfaced. Open timeout 10 s, read
timeout `timeout:` (default 30 s). A `204` or empty body returns `{}`.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

---

## Examples

### Authenticate and publish

```ruby
require "misarblog"

blog = MisarBlog.new(api_key: ENV.fetch("MISARBLOG_API_KEY"))

me = blog.account.profile
puts "authenticated as @#{me.username}"

article = blog.articles.publish(
  title: "Shipping a blog from CI",
  body_markdown: "# Shipping a blog from CI\n\nMarkdown in, article out.",
  tags: %w[ci automation]
)
puts article.url
```

### Publish (or schedule) an article

```ruby
article = blog.articles.publish(
  title: "Hello, Misar",
  body_markdown: "# Hello\n\nFirst post.",
  tags: ["intro"],
  cover_image_url: "https://cdn.example.com/cover.png",
  visibility: "public",                # public | subscribers | paid | private | webhook_only
  schedule_at: "2026-09-01T09:00:00Z"  # omit to publish immediately
)
puts "#{article.slug} #{article.status} #{article.url}"
```

`title:` and `body_markdown:` are required keywords; every other keyword is
dropped from the request body when left nil.

### Save a draft

```ruby
draft = blog.articles.create_draft(
  title: "Work in progress",
  body_markdown: "Notes so far…",
  tags: ["draft"]
)
puts draft.editor_url # open in the Misar.Blog editor
```

### List your articles

```ruby
result = blog.articles.list(status: "published", limit: 20)
result.articles.each { |a| puts "#{a.slug} #{a["view_count"]}" }
puts "#{result.articles.size} of #{result.total}"
```

`status:` accepts `draft`, `published`, `scheduled`, `archived` or `flagged`;
`visibility:`, `webhook_only:` and `sort:` narrow it further. `Article` exposes
the common fields as readers and everything else through `#[]` or `#raw`.

### Update an article — and publish a draft

```ruby
updated = blog.articles.update(
  "work-in-progress",
  title: "Finished at last",
  body_markdown: "The complete post.",
  publish: true # flips a draft to published in the same call
)
puts "#{updated.status} #{updated.published_at}"
```

The slug is positional; everything else is a keyword, and omitted keywords are
left out of the body so those fields stay unchanged.

### Read an article's comment thread

```ruby
thread = blog.comments.list(article_id: article.id, limit: 50, offset: 0)
thread["comments"].each do |c|
  puts "@#{c["user"]["username"]}: #{c["content"]} (#{c["reply_count"]} replies)"
end
puts "#{thread["totalCount"]} #{thread["hasMore"]}"
```

This one returns a plain Hash, not a model. Leave `limit:`/`offset:` out to take
the server defaults of 20 (max 100) and 0.

### Read and add reactions

```ruby
counts = blog.reactions.get(article_id: article.id)
puts "#{counts.counts["clap"]} #{counts.total} #{counts.user_reactions}"

blog.reactions.add(article_id: article.id, type: "clap")    # like | clap | bookmark
blog.reactions.remove(article_id: article.id, type: "clap")
```

### Generate SEO titles

```ruby
result = blog.ai.titles(
  action: "seo", # "seo" from a keyword, "suggest" from existing copy
  prompt: "shipping a static blog from GitHub Actions"
)
result.titles.each { |t| puts "#{t.title} — #{t.hint}" }
```

For `"suggest"`, pass the article text as `context:` instead of `prompt:`.

### Read the analytics summary

```ruby
summary = blog.analytics.get(days: 30)
puts "#{summary.views} #{summary.revenue_cents} #{summary.active_subscribers}"
```

### Generate a cover image

```ruby
image = blog.images.generate(
  prompt: "a dark editorial illustration of a printing press",
  size: "1792x1024"
)
puts image.url
```

`blog.images.upload(data)` posts to the CDN upload route as JSON — pass the Hash
the API expects (a base64 `data` field). This SDK does not build a multipart
request for you; the Go and Python clients do.

### Embed a public article

```ruby
puts MisarBlog.embed_url(username: "gulshan", slug: "hello-misar", theme: "dark")
# https://misar.blog/gulshan/hello-misar/embed?theme=dark
```

Omit `slug:` to embed the whole profile; `theme:` defaults to `"auto"`, which
adds no query parameter.

---

## Errors

Every failure raises. `PlanLimitError` and `NetworkError` both subclass
`ApiError`, which subclasses `StandardError` — so a single `rescue
MisarBlog::ApiError` catches everything from this SDK. Order narrowest-first.

| Type | Raised when | Readers |
| --- | --- | --- |
| `ApiError` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `status`, `error_type`, `body` (the decoded error Hash) |
| `PlanLimitError` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `plan`, `upgrade_url`, `retry_after`, `upgrade` |
| `NetworkError` | The request never reached the API — DNS, TLS, connection refused/reset, open or read timeout — on the final attempt | `cause_error`; `status` is `0` |

```ruby
begin
  blog.ai.complete(prompt: "Draft an intro paragraph")
rescue MisarBlog::PlanLimitError => e
  # Route the reader to checkout instead of reporting a bare failure.
  puts "#{e.plan} plan is out of credits — upgrade at #{e.upgrade_url}"
rescue MisarBlog::NetworkError => e
  puts "could not reach the API: #{e.cause_error}"
rescue MisarBlog::ApiError => e
  puts "#{e.status} #{e.body && e.body["required_scope"]}"
end
```

The 403 scope details are not promoted to named readers here — read
`required_scope` and `granted_scopes` off `e.body`. If a failure lands in the
wrong class, file it at <https://github.com/Misar-AI/misarblog-sdks/issues>.

---

## Links

- Website — https://www.misar.blog
- App — https://www.misar.blog
- Parent — https://misar.io
- Documentation — https://docs.misar.io/blog
- Source — https://github.com/Misar-AI/misarblog-sdks
- RubyGems — https://rubygems.org/gems/misarblog

MIT © [Misar AI](https://misar.io)
