# Misar.Blog Swift SDK

> Publish, schedule and manage a Misar.Blog account from Swift async/await.

[![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)](https://swift.org) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**14 resource groups · 25 operations · async/await on URLSession**

Works with any Swift 5.9 codebase — an iOS or macOS reader, a Linux CI job that
syncs a blog out of another CMS, a server-side Vapor handler. No third-party
dependencies. Covers the developer API at `https://api.misar.io/blog/v1` in
full.

---

## Install

### Swift Package Manager

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Misar-AI/misarblog-swift.git", from: "5.0.0")
]
```

and in the target that uses it:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "MisarBlog", package: "misarblog-swift")
])
```

### Xcode

**File ▸ Add Package Dependencies…** and paste the same URL.

Swift 5.9+, macOS 12+ / iOS 15+ (or Linux with `FoundationNetworking`).

---

## Authentication

Mint a key in the dashboard at
<https://www.misar.blog/dashboard/settings/api>. Keys are prefixed `mbk_` and
travel on `Authorization: Bearer`; an OAuth 2.1 access token works on the same
header. Key management itself is a cookie-session flow and is deliberately not
exposed here. Construct the client with `MisarBlogClient(apiKey: key)`, as the
first example below does.

The machine-readable contract for every route below is the OpenAPI spec at
<https://api.misar.io/blog/v1/openapi.json>.

---

## API surface

Every operation is `async throws` and returns `[String: Any]` — the decoded
JSON, uniform across routes and forward-compatible with fields added after this
release. An empty body or unparsable payload returns `[:]`.

Note the grouping: search and recommendations are their own resources here, not
methods on `articles`, and the trial and upsell funnel are split out of `plan`.

| Resource | Method | Endpoint | What it does |
| --- | --- | --- | --- |
| `articles` | `list` | `GET /articles` | List your articles, filtered by status/visibility/sort |
| `articles` | `get` | `GET /articles/{slug}` | Fetch one article by slug or UUID, full Markdown body |
| `articles` | `update` | `PATCH /articles/{slug}` | Update title/body/tags in place; `publish: true` flips a draft live |
| `articles` | `publish` | `POST /articles` | Publish or schedule an article from Markdown |
| `articles` | `createDraft` | `POST /drafts` | Save a draft without publishing |
| `search` | `query` | `GET /search` | Full-text search across articles, profiles and tags |
| `recommendations` | `get` | `GET /recommendations` | Related articles for an article id |
| `series` | `list` | `GET /series` | List your series |
| `series` | `create` | `POST /series` | Create a series |
| `series` | `addArticle` | `POST /series/{slug}/articles` | Add an article to a series at a position |
| `reactions` | `get` | `GET /reactions` | Reaction counts and the caller's own reactions |
| `reactions` | `add` | `POST /reactions` | Add a `like` / `clap` / `bookmark` |
| `reactions` | `remove` | `DELETE /reactions` | Remove a reaction |
| `comments` | `list` | `GET /comments` | An article's comment thread, newest first, replies one level deep |
| `follows` | `status` | `GET /follows` | Follower/following counts and whether the key's owner follows |
| `ai` | `complete` | `POST /ai/complete` | Free-form system + user completion |
| `ai` | `titles` | `POST /ai/titles` | SEO/AEO/GEO title suggestions (`seo` from a keyword, `suggest` from copy) |
| `images` | `generate` | `POST /images/generate` | AI cover image (`1024x1024`, `1792x1024`, `1024x1792`) |
| `images` | `upload` | `POST /images/upload` | Upload an image to the CDN |
| `profile` | `get` | `GET /me` | The authenticated creator profile |
| `analytics` | `get` | `GET /analytics` | Views, gross/net revenue, active subscribers for trailing N days |
| `plan` | `get` | `GET /plan` | Live plan and per-feature quota |
| `trial` | `status` | `GET /trial` | Whether a self-serve trial is active |
| `trial` | `start` | `POST /trial` | Start a self-serve trial |
| `upsell` | `funnel` | `GET /upsell-funnel` | Per-feature upsell funnel (platform-admin keys only; a creator key gets 403) |

---

## What's in the package

| Item | What it is |
| --- | --- |
| `MisarBlogClient` | The client: `MisarBlogClient(apiKey:baseURL:maxRetries:session:)`. `apiKey`, `baseURL`, `maxRetries` and `session` are public `let`s you can read back |
| Resource properties | `articles`, `series`, `reactions`, `comments`, `follows`, `ai`, `images`, `profile`, `analytics`, `plan`, `trial`, `upsell`, `search`, `recommendations` — public computed properties |
| `MisarBlog` | A separate class with `embedURL(username:slug:theme:)` for public iframe URLs (unauthenticated, unmetered) and `refreshToken(token:baseURL:)`, which returns its nested `TokenResult` struct (`token`, `expiresAt`). Construct it with `MisarBlog()` |
| `MisarBlogError` | An `enum` with three cases: `.apiError`, `.planLimitExceeded` and `.networkError`, plus an `upgradeURL` convenience property. Match with `catch let MisarBlogError.…` pattern binding |
| `Article`, `Series` | `Codable`, `Equatable` value types with a throwing `from(_ json: [String: Any])` factory, for a typed view of a response |
| Platform bridging | Builds against Foundation on Apple platforms and `FoundationNetworking` on Linux, with a bridged `URLSession.data(for:)` so the async surface is identical on both |

**Untyped `[String: Any]`, not typed models.** Every resource method hands back
the raw decoded dictionary. `Article` and `Series` exist as an opt-in typed view
you decode yourself; nothing returns them for you.

**Transport.** `URLSession` — no third-party dependencies. Base URL
`https://api.misar.io/blog/v1`; the key goes on `Authorization: Bearer`.
Statuses 429/500/502/503/504 and transport failures are retried up to
`maxRetries` attempts (default 3) with exponential back-off from 500 ms; the
final attempt is always surfaced. Per-request timeout is 30 s. Pass your own
`URLSession` to inject a `URLProtocol` stub in tests, as this package's own
suite does.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

---

## Examples

### Authenticate and publish

```swift
import Foundation
import MisarBlog

let key = ProcessInfo.processInfo.environment["MISARBLOG_API_KEY"]!
let blog = MisarBlogClient(apiKey: key)

let me = try await blog.profile.get()
print("authenticated as @\(me["username"] as? String ?? "")")

let article = try await blog.articles.publish(data: [
    "title": "Shipping a blog from CI",
    "body_markdown": "# Shipping a blog from CI\n\nMarkdown in, article out.",
    "tags": ["ci", "automation"],
])
print(article["url"] as? String ?? "")
```

### Publish (or schedule) an article

```swift
let article = try await blog.articles.publish(data: [
    "title": "Hello, Misar",
    "body_markdown": "# Hello\n\nFirst post.",
    "tags": ["intro"],
    "cover_image_url": "https://cdn.example.com/cover.png",
    "visibility": "public",                // public | subscribers | paid | private | webhook_only
    "schedule_at": "2026-09-01T09:00:00Z", // omit to publish immediately
])

print(article["slug"] as? String ?? "", article["status"] as? String ?? "")
```

The body is an untyped `[String: Any]`; only `title` and `body_markdown` are
required. For a typed view of the result:

```swift
let typed = try Article.from(article)
print(typed.slug ?? "", typed.status ?? "", typed.editorURL ?? "")
```

### Save a draft

```swift
let draft = try await blog.articles.createDraft(data: [
    "title": "Work in progress",
    "body_markdown": "Notes so far…",
    "tags": ["draft"],
])
print(draft["editor_url"] as? String ?? "") // open in the Misar.Blog editor
```

### List your articles

```swift
let result = try await blog.articles.list(status: "published", limit: 20)

let articles = result["articles"] as? [[String: Any]] ?? []
for a in articles {
    print(a["slug"] as? String ?? "", a["view_count"] as? Int ?? 0)
}
print(articles.count, "of", result["total"] as? Int ?? 0)
```

`status` accepts `draft`, `published`, `scheduled`, `archived`, `flagged` or
`all`; `visibility`, `webhookOnly` and `sort` narrow it further. Note
`webhookOnly` is a `String?` here, not a `Bool?` — pass `"true"`.

### Update an article — and publish a draft

```swift
let updated = try await blog.articles.update(slug: "work-in-progress", data: [
    "title": "Finished at last",
    "body_markdown": "The complete post.",
    "publish": true, // flips a draft to published in the same call
])
print(updated["status"] as? String ?? "")
```

Omitted fields are left unchanged.

### Read an article's comment thread

```swift
let articleID = article["id"] as? String ?? ""
let thread = try await blog.comments.list(articleID: articleID, limit: 50, offset: 0)

for c in thread["comments"] as? [[String: Any]] ?? [] {
    let user = c["user"] as? [String: Any] ?? [:]
    print("@\(user["username"] as? String ?? ""): \(c["content"] as? String ?? "")")
}
print(thread["totalCount"] as? Int ?? 0, thread["hasMore"] as? Bool ?? false)
```

Leave `limit`/`offset` out to take the server defaults of 20 (max 100) and 0.
Mind the spelling: comments and follows take `articleID` / `userID`, while
reactions and recommendations take `articleId`.

### Read and add reactions

```swift
let counts = try await blog.reactions.get(articleId: articleID)
let byType = counts["counts"] as? [String: Int] ?? [:]
print(byType["clap"] ?? 0, counts["total"] as? Int ?? 0)

_ = try await blog.reactions.add(articleId: articleID, type: "clap")    // like | clap | bookmark
_ = try await blog.reactions.remove(articleId: articleID, type: "clap")
```

### Generate SEO titles

```swift
let result = try await blog.ai.titles(
    action: "seo", // "seo" from a keyword, "suggest" from existing copy
    prompt: "shipping a static blog from GitHub Actions"
)

for t in result["titles"] as? [[String: Any]] ?? [] {
    print(t["title"] as? String ?? "", "—", t["hint"] as? String ?? "")
}
```

For `"suggest"`, pass the article text as `context:` instead of `prompt:`.

### Read the analytics summary

```swift
let summary = try await blog.analytics.get(days: 30)
print(summary["views"] as? Int ?? 0,
      summary["revenue_cents"] as? Int ?? 0,
      summary["active_subscribers"] as? Int ?? 0)
```

### Generate a cover image

```swift
let image = try await blog.images.generate(
    prompt: "a dark editorial illustration of a printing press",
    size: "1792x1024"
)
print(image["url"] as? String ?? "")
```

`blog.images.upload(data:)` posts to the CDN upload route as JSON — pass the
dictionary the API expects (a base64 `data` field). This SDK does not build a
multipart request for you; the Go and Python clients do.

### Embed a public article

```swift
let embeds = MisarBlog()
let url = embeds.embedURL(username: "gulshan", slug: "hello-misar", theme: "dark")
print(url.absoluteString)
// https://misar.blog/gulshan/hello-misar/embed?theme=dark
```

`embedURL` returns a `URL`. Omit `slug` to embed the whole profile; `theme`
defaults to `"auto"`, which adds no query parameter. The same `MisarBlog`
instance carries `refreshToken(token:baseURL:)`.

---

## Errors

Every failure throws `MisarBlogError`. It is an `enum`, not a class hierarchy —
there is no base case that catches the others, so bind the case you care about
and let the rest fall through to a general `catch`.

| Case | Thrown when | Payload |
| --- | --- | --- |
| `.apiError` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `status`, `message`, `requiredScope`, `grantedScopes` |
| `.planLimitExceeded` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `status`, `message`, `plan`, `upgradeURL`, `retryAfter` |
| `.networkError` | The request never reached the API — DNS, TLS, connection, timeout — or the retry budget was exhausted | `message` |

```swift
do {
    _ = try await blog.ai.complete(prompt: "Draft an intro paragraph")
} catch let MisarBlogError.planLimitExceeded(_, _, plan, upgradeURL, retryAfter) {
    // Route the reader to checkout instead of reporting a bare failure.
    print("\(plan ?? "current") plan is out of credits — upgrade at \(upgradeURL ?? "")")
    print("resets in \(retryAfter ?? 0)s")
} catch let MisarBlogError.networkError(message) {
    print("could not reach the API: \(message)")
} catch let MisarBlogError.apiError(status, message, requiredScope, _) {
    print(status, message, requiredScope ?? "")
}
```

`MisarBlogError` also conforms to `CustomStringConvertible`, so
`print(error)` yields the status, message and any scope detail without
unwrapping the case.

---

## Links

- Website — https://www.misar.blog
- App — https://www.misar.blog
- Parent — https://misar.io
- Documentation — https://docs.misar.io/blog
- Source — https://github.com/Misar-AI/misarblog-sdks
- Swift Package Index — https://github.com/Misar-AI/misarblog-swift

MIT © [Misar AI](https://misar.io)
