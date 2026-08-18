# Misar.Blog Kotlin SDK

[Misar.Blog](https://misar.blog) is a hosted blogging platform. Authors write in
Markdown, publish or schedule articles, group them into series, and get
comments, reactions, follows, subscriber- and paid-gated posts, AI writing
helpers and per-account analytics. This artifact is the official Kotlin client
for its developer API at `https://api.misar.io/blog/v1` — for anyone automating
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

- `blog.misar.sdk.MisarBlog` — the client:
  `MisarBlog(apiKey, baseUrl = "https://api.misar.io/blog/v1", maxRetries = 3)`.
- Resource properties on the client: `articles`, `series`, `reactions`,
  `comments`, `follows`, `ai`, `images`, `account`, `analytics`, `plan`.
- **Every operation is a `suspend` function**, dispatched on `Dispatchers.IO`.
  Call them from a coroutine — `runBlocking` in a script, `viewModelScope` in an
  app, `kotlinx-coroutines-test` in tests.
- Exceptions: `BlogApiException` (open), `PlanLimitException` and
  `BlogNetworkException`, both of which extend it.
- `MisarBlog.embedUrl(username, slug, theme)` — a companion-object function,
  pure string building for public embeds.
- `Article` and `Series` data classes, Jackson-mapped with
  `@JsonIgnoreProperties(ignoreUnknown = true)` so a field the API adds later
  will not break deserialisation.

**Mostly `Map<String, Any>`.** Only `articles.get`, `articles.publish`,
`articles.update`, `articles.createDraft` and `series.create` return typed
objects; every other method hands back the decoded JSON as a `Map<String, Any>`,
and request bodies are `Map<String, Any?>` too. Build them with `mapOf(...)`.

**Transport.** `java.net.http.HttpClient` from the JDK plus
`jackson-module-kotlin` and `kotlinx-coroutines-core`. Base URL
`https://api.misar.io/blog/v1`; the key goes on `Authorization: Bearer`.
Statuses 429/500/502/503/504 and transport failures are retried up to
`maxRetries` attempts (default 3) with exponential back-off from 500 ms; the
final attempt is always surfaced. Connect timeout 10 s, request timeout 30 s —
the client is built internally, so unlike the Java SDK there is no hook for
supplying your own `HttpClient`.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

## Install

Gradle (Kotlin DSL):

```kotlin
implementation("blog.misar:misarblog-sdk:1.1.0")
```

Maven:

```xml
<dependency>
    <groupId>blog.misar</groupId>
    <artifactId>misarblog-sdk</artifactId>
    <version>1.1.0</version>
</dependency>
```

JVM toolchain 17. Note the artifact id is `misarblog-sdk`; `blog.misar:misarblog`
is the separate Java SDK.

## Quick start

```kotlin
import blog.misar.sdk.MisarBlog
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val blog = MisarBlog(System.getenv("MISARBLOG_API_KEY"))

    val me = blog.account.me()
    println("authenticated as @${me["username"]}")

    val article = blog.articles.publish(
        mapOf(
            "title" to "Shipping a blog from CI",
            "body_markdown" to "# Shipping a blog from CI\n\nMarkdown in, article out.",
            "tags" to listOf("ci", "automation"),
        )
    )
    println(article.url)
}
```

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
itself is a cookie-session flow and is deliberately not exposed here.

## Primary functions

### Publish (or schedule) an article

```kotlin
val article = blog.articles.publish(
    mapOf(
        "title" to "Hello, Misar",
        "body_markdown" to "# Hello\n\nFirst post.",
        "tags" to listOf("intro"),
        "cover_image_url" to "https://cdn.example.com/cover.png",
        "visibility" to "public",                // public | subscribers | paid | private | webhook_only
        "schedule_at" to "2026-09-01T09:00:00Z", // omit to publish immediately
    )
)
println("${article.slug} ${article.status} ${article.url}")
```

Only `title` and `body_markdown` are required. The body map's value type is
`Any?`, so a null entry is dropped rather than rejected.

### Save a draft

```kotlin
val draft = blog.articles.createDraft(
    mapOf(
        "title" to "Work in progress",
        "body_markdown" to "Notes so far…",
        "tags" to listOf("draft"),
    )
)
println(draft.editorUrl) // open in the Misar.Blog editor
```

### List your articles

```kotlin
val result = blog.articles.list(mapOf("status" to "published", "limit" to 20))

@Suppress("UNCHECKED_CAST")
val articles = result["articles"] as List<Map<String, Any>>
for (a in articles) println("${a["slug"]} ${a["view_count"]}")
println("${articles.size} of ${result["total"]}")
```

`status` accepts `draft`, `published`, `scheduled`, `archived`, `flagged` or
`all`; `visibility`, `webhook_only` and `sort` narrow it further.
`blog.articles.list()` with no argument sends no filters.

### Update an article — and publish a draft

```kotlin
val updated = blog.articles.update(
    "work-in-progress",
    mapOf(
        "title" to "Finished at last",
        "body_markdown" to "The complete post.",
        "publish" to true, // flips a draft to published in the same call
    )
)
println("${updated.status} ${updated.publishedAt}")
```

Omitted fields are left unchanged.

### Read an article's comment thread

```kotlin
val thread = blog.comments.list(article.id, limit = 50, offset = 0)

@Suppress("UNCHECKED_CAST")
val comments = thread["comments"] as List<Map<String, Any>>
for (c in comments) {
    @Suppress("UNCHECKED_CAST")
    val user = c["user"] as Map<String, Any>
    println("@${user["username"]}: ${c["content"]}")
}
println("${thread["totalCount"]} ${thread["hasMore"]}")
```

`limit` and `offset` default to `null`, which leaves the server defaults of 20
(max 100) and 0.

### Read and add reactions

```kotlin
val counts = blog.reactions.get(article.id)
println("${counts["counts"]} ${counts["total"]}")

blog.reactions.add(mapOf("article_id" to article.id, "type" to "clap")) // like | clap | bookmark
blog.reactions.remove(article.id, "clap")
```

Note the asymmetry: `add` takes the request body as a map, `remove` takes the
article id and type as positional arguments.

### Generate SEO titles

```kotlin
val result = blog.ai.titles(
    mapOf(
        "action" to "seo", // "seo" from a keyword, "suggest" from existing copy
        "prompt" to "shipping a static blog from GitHub Actions",
    )
)

@Suppress("UNCHECKED_CAST")
val titles = result["titles"] as List<Map<String, Any>>
for (t in titles) println("${t["title"]} — ${t["hint"]}")
```

For `"suggest"`, put the article text under `"context"` instead of `"prompt"`.

### Read the analytics summary

```kotlin
val summary = blog.analytics.summary(days = 30)
println("${summary["views"]} ${summary["revenue_cents"]} ${summary["active_subscribers"]}")
```

### Generate a cover image

```kotlin
val image = blog.images.generate(
    mapOf(
        "prompt" to "a dark editorial illustration of a printing press",
        "size" to "1792x1024",
    )
)
println(image["url"])
```

`blog.images.upload(body)` posts to the CDN upload route as JSON — pass the body
the API expects (a base64 `data` field). This SDK does not build a multipart
request for you; the Go and Python clients do.

### Embed a public article

```kotlin
val url = MisarBlog.embedUrl("gulshan", "hello-misar", theme = "dark")
// https://misar.blog/gulshan/hello-misar/embed?theme=dark
```

Omit `slug` to embed the whole profile; `theme` defaults to `"auto"`, which adds
no query parameter.

## Errors

Every failure throws. `PlanLimitException` and `BlogNetworkException` both extend
`BlogApiException`, so a single `catch (e: BlogApiException)` catches everything
— order narrowest-first when you want to tell them apart. Kotlin has no checked
exceptions, so nothing forces you to handle them at the call site.

| Type | Thrown when | Properties |
| --- | --- | --- |
| `BlogApiException` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `status` |
| `PlanLimitException` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `plan`, `upgradeUrl`, `retryAfter` |
| `BlogNetworkException` | The request never reached the API — DNS, TLS, connection, timeout — or the retry budget was exhausted | `status` is `0` |

```kotlin
try {
    blog.ai.complete(mapOf("prompt" to "Draft an intro paragraph"))
} catch (e: PlanLimitException) {
    // Route the reader to checkout instead of reporting a bare failure.
    println("${e.plan} plan is out of credits — upgrade at ${e.upgradeUrl}")
} catch (e: BlogNetworkException) {
    println("could not reach the API: ${e.message}")
} catch (e: BlogApiException) {
    println("${e.status} ${e.message}")
}
```

Unlike the TypeScript, Python and Go clients, the 403 scope details
(`required_scope`, `granted_scopes`) are not promoted to properties here — the
raw error body ends up in `message`.

## Links

- Misar.Blog — <https://misar.blog>
- API docs — <https://docs.misar.io/blog>
- OpenAPI spec — <https://api.misar.io/blog/v1/openapi.json>
- Mint an API key — <https://www.misar.blog/dashboard/settings/api>

## License

MIT — see [LICENSE](LICENSE).
