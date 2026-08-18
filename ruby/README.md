# Misar.Blog Ruby SDK

[Misar.Blog](https://misar.blog) is a hosted blogging platform. Authors write in
Markdown, publish or schedule articles, group them into series, and get
comments, reactions, follows, subscriber- and paid-gated posts, AI writing
helpers and per-account analytics. This gem is the official Ruby client for its
developer API at `https://api.misar.io/blog/v1` — for anyone automating
publishing, syncing a blog out of CI or another CMS, or building a reader,
dashboard or integration on top of a Misar.Blog account.

## Features

The API surface this SDK covers, in full:

- **Articles** — list and filter by status, visibility, webhook-only or sort
  order, fetch by slug or UUID, publish or schedule from Markdown, update in
  place, and save drafts.
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
  `1024x1792`) and CDN upload.
- **Discovery** — full-text search across articles, profiles and tags, and
  related-article recommendations.
- **Account** — the authenticated profile, an analytics summary (views,
  gross/net revenue, active subscribers), live plan and quota, the self-serve
  trial, and the upsell funnel (platform-admin keys only).
- **Embeds** — build a public iframe URL for a profile or a single article.
  Unauthenticated and unmetered.

That is all 25 key-authenticated operations.

## What's in the package

- `MisarBlog::Client` — the client. `MisarBlog.new(api_key:, base_url:,
  timeout: 30, max_retries: 3)` is the shorthand constructor.
- Resource readers on the client: `articles`, `series`, `reactions`, `comments`,
  `follows`, `ai`, `images`, `account`, `analytics`. Plan, trial and upsell live
  on `account`.
- Errors: `MisarBlog::ApiError`, `MisarBlog::PlanLimitError`,
  `MisarBlog::NetworkError`.
- `MisarBlog.embed_url(username:, slug:, theme:)` — pure string building for
  public embeds.
- `MisarBlog::Models` — `Article`, `ArticleList`, `Series`, `SeriesList`,
  `Profile`, `Plan`, `PlanUsage`, `Analytics`, `ArticleReactions`,
  `ReactionResult`, `TrialStatus`, `TitlesResult`, `TitleSuggestion`, `AiText`,
  `ImageResult`. Each wraps the decoded body: named readers for the documented
  fields, `#[]` for string-key access, and `#raw` / `#to_h` for the untouched
  Hash, so a field the API adds after this release is still reachable.
- **Not everything is modelled.** `comments.list`, `follows.status`,
  `articles.search`, `articles.recommendations`, `account.start_trial` and
  `account.upsell_funnel` return the plain decoded `Hash` with string keys.
- `client.request(method, path, data)` is public, so an endpoint this SDK does
  not wrap yet is still one call away.

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

## Install

```bash
gem install misarblog
```

Or in a `Gemfile`:

```ruby
gem "misarblog", "~> 1.1"
```

Ruby 2.7+.

## Quick start

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

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
itself is a cookie-session flow and is deliberately not exposed here.

## Primary functions

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
`required_scope` and `granted_scopes` off `e.body`.

## Links

- Misar.Blog — <https://misar.blog>
- API docs — <https://docs.misar.io/blog>
- OpenAPI spec — <https://api.misar.io/blog/v1/openapi.json>
- Mint an API key — <https://www.misar.blog/dashboard/settings/api>

## License

MIT — see [LICENSE](LICENSE).
