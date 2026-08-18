# Misar.Blog Kotlin SDK

> Publish, schedule and manage a Misar.Blog account from Kotlin coroutines.

[![Maven Central](https://img.shields.io/badge/maven--central-blog.misar%3Amisarblog--kotlin-blue)](https://central.sonatype.com/artifact/blog.misar/misarblog-kotlin) [![JVM](https://img.shields.io/badge/jvm-17-orange)](https://openjdk.org) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**10 resource groups · 25 suspend functions · coroutines on java.net.http**

Works with any coroutine-aware JVM codebase on toolchain 17 — a `runBlocking`
script, an Android `viewModelScope`, a Ktor or Spring service syncing a blog out
of another CMS. Covers the developer API at `https://api.misar.io/blog/v1` in
full.

---

## Install

### Gradle (Kotlin DSL)

```kotlin
implementation("blog.misar:misarblog-kotlin:5.0.2")
```

### Gradle (Groovy)

```groovy
implementation 'blog.misar:misarblog-kotlin:5.0.2'
```

### Maven

```xml
<dependency>
    <groupId>blog.misar</groupId>
    <artifactId>misarblog-kotlin</artifactId>
    <version>5.0.2</version>
</dependency>
```

JVM toolchain 17. Note the artifact id is `misarblog-kotlin`; `blog.misar:misarblog`
is the separate Java SDK.

---

## Authentication

Mint a key in the dashboard at
<https://www.misar.blog/dashboard/settings/api>. Keys are prefixed `mbk_` and
travel on `Authorization: Bearer`; an OAuth 2.1 access token works on the same
header. Key management itself is a cookie-session flow and is deliberately not
exposed here. Construct the client with
`MisarBlog(System.getenv("MISARBLOG_API_KEY"))`, as the first example below
does.

The machine-readable contract for every route below is the OpenAPI spec at
<https://api.misar.io/blog/v1/openapi.json>.

---

## API surface

Every operation is a `suspend` function dispatched on `Dispatchers.IO`. Call
them from a coroutine — `runBlocking` in a script, `viewModelScope` in an app,
`kotlinx-coroutines-test` in tests.

| Resource | Method | Endpoint | What it does |
| --- | --- | --- | --- |
| `articles` | `list` | `GET /articles` | List your articles, filtered by status/visibility/sort |
| `articles` | `get` | `GET /articles/{slug}` | Fetch one article by slug or UUID, full Markdown body |
| `articles` | `publish` | `POST /articles` | Publish or schedule an article from Markdown |
| `articles` | `update` | `PATCH /articles/{slug}` | Update title/body/tags in place; `publish: true` flips a draft live |
| `articles` | `createDraft` | `POST /drafts` | Save a draft without publishing |
| `articles` | `search` | `GET /search` | Full-text search across articles, profiles and tags |
| `articles` | `recommendations` | `GET /recommendations` | Related articles for an article id |
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
| `account` | `me` | `GET /me` | The authenticated creator profile |
| `analytics` | `summary` | `GET /analytics` | Views, gross/net revenue, active subscribers for trailing N days |
| `analytics` | `upsellFunnel` | `GET /upsell-funnel` | Per-feature upsell funnel (platform-admin keys only; a creator key gets 403) |
| `plan` | `get` | `GET /plan` | Live plan and per-feature quota |
| `plan` | `trialStatus` | `GET /trial` | Whether a self-serve trial is active |
| `plan` | `startTrial` | `POST /trial` | Start a self-serve trial |

Note `upsellFunnel` hangs off `analytics`, not `plan`.

---

## What's in the package

| Item | What it is |
| --- | --- |
| `blog.misar.sdk.MisarBlog` | The client: `MisarBlog(apiKey, baseUrl = "https://api.misar.io/blog/v1", maxRetries = 3)` |
| Resource properties | `articles`, `series`, `reactions`, `comments`, `follows`, `ai`, `images`, `account`, `analytics`, `plan` |
| `MisarBlog.embedUrl(username, slug, theme)` | A companion-object function, pure string building for public embeds. Unauthenticated and unmetered |
| `Article`, `Series` | Data classes in `Models.kt`, Jackson-mapped with `@JsonIgnoreProperties(ignoreUnknown = true)` so a field the API adds later will not break deserialisation |
| `TokenResult` | A data class in `Models.kt` (`token`, `expiresAt`) mirroring the embed-token refresh payload |
| `BlogApiException` | `open`, the base of the hierarchy. Property: `status` |
| `PlanLimitException` | Extends `BlogApiException`. Properties: `plan`, `upgradeUrl`, `retryAfter` |
| `BlogNetworkException` | Extends `BlogApiException` with `status` `0` — transport failure or exhausted retry budget |

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

---

## Examples

### Authenticate and publish

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

---

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

---

## Links

- Website — https://www.misar.blog
- App — https://www.misar.blog
- Parent — https://misar.io
- Documentation — https://docs.misar.io/blog
- Source — https://github.com/Misar-AI/misarblog-sdks
- Maven Central — https://central.sonatype.com/artifact/blog.misar/misarblog-kotlin

MIT © [Misar AI](https://misar.io)
