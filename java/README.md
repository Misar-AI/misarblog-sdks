# Misar.Blog Java SDK

[Misar.Blog](https://misar.blog) is a hosted blogging platform. Authors write in
Markdown, publish or schedule articles, group them into series, and get
comments, reactions, follows, subscriber- and paid-gated posts, AI writing
helpers and per-account analytics. This artifact is the official Java client for
its developer API at `https://api.misar.io/blog/v1` — for anyone automating
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

- `blog.misar.sdk.MisarBlog` — the client. `new MisarBlog(apiKey)` for the
  defaults, or `new MisarBlog.Builder(apiKey).baseUrl(...).maxRetries(...)
  .httpClient(...).build()`.
- Resource fields on the client: `articles`, `series`, `reactions`, `comments`,
  `follows`, `ai`, `images`, `account`, `analytics`, `plan`.
- Exceptions: `BlogApiException` (checked) and `PlanLimitException`, which
  extends it.
- `MisarBlog.embedUrl(username, slug, theme)` — static, pure string building for
  public embeds.
- `blog.misar.sdk.models.Article` and `.Series` — Jackson-mapped POJOs with
  `@JsonIgnoreProperties(ignoreUnknown = true)`, so a field the API adds later
  will not break deserialisation.
- `blog.async(() -> blog.articles.list())` — runs any blocking call on the
  common `ForkJoinPool` and hands back a `CompletableFuture`, wrapping the
  checked exception in a `CompletionException`. There is no separately
  implemented async transport.

**Mostly `Map<String, Object>`.** Only `articles.get`, `articles.publish`,
`articles.update`, `articles.createDraft` and `series.create` return typed
objects; every other method hands back the decoded JSON as a
`Map<String, Object>`, and request bodies are `Map`s too. Build them with
`Map.of(...)` and read results with `get(...)`.

**Transport.** `java.net.http.HttpClient` from the JDK plus Jackson Databind for
JSON — no other dependencies. Base URL `https://api.misar.io/blog/v1`; the key
goes on `Authorization: Bearer`. Statuses 429/500/502/503/504 and I/O failures
are retried up to `maxRetries` attempts (default 3) with exponential back-off
from 500 ms; the final attempt is always surfaced. Connect timeout 10 s, request
timeout 30 s; pass your own `HttpClient` to the builder to change the former or
to inject a stub in tests.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

## Install

Maven:

```xml
<dependency>
    <groupId>blog.misar</groupId>
    <artifactId>misarblog</artifactId>
    <version>1.1.0</version>
</dependency>
```

Gradle:

```kotlin
implementation("blog.misar:misarblog:1.1.0")
```

Java 17+. Pulls in `com.fasterxml.jackson.core:jackson-databind`.

## Quick start

```java
import blog.misar.sdk.MisarBlog;
import blog.misar.sdk.BlogApiException;
import blog.misar.sdk.models.Article;

import java.util.List;
import java.util.Map;

public class Example {
    public static void main(String[] args) throws BlogApiException {
        MisarBlog blog = new MisarBlog(System.getenv("MISARBLOG_API_KEY"));

        Map<String, Object> me = blog.account.me();
        System.out.println("authenticated as @" + me.get("username"));

        Article article = blog.articles.publish(Map.of(
                "title", "Shipping a blog from CI",
                "body_markdown", "# Shipping a blog from CI\n\nMarkdown in, article out.",
                "tags", List.of("ci", "automation")));
        System.out.println(article.url);
    }
}
```

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
itself is a cookie-session flow and is deliberately not exposed here.

## Primary functions

### Publish (or schedule) an article

```java
Article article = blog.articles.publish(Map.of(
        "title", "Hello, Misar",
        "body_markdown", "# Hello\n\nFirst post.",
        "tags", List.of("intro"),
        "cover_image_url", "https://cdn.example.com/cover.png",
        "visibility", "public",                // public | subscribers | paid | private | webhook_only
        "schedule_at", "2026-09-01T09:00:00Z"  // omit to publish immediately
));
System.out.println(article.slug + " " + article.status + " " + article.url);
```

Only `title` and `body_markdown` are required. `Map.of` rejects null values, so
build the body with a `LinkedHashMap` when a field is conditionally present.

### Save a draft

```java
Article draft = blog.articles.createDraft(Map.of(
        "title", "Work in progress",
        "body_markdown", "Notes so far…",
        "tags", List.of("draft")));
System.out.println(draft.editorUrl); // open in the Misar.Blog editor
```

### List your articles

```java
Map<String, Object> result = blog.articles.list(Map.of("status", "published", "limit", 20));

@SuppressWarnings("unchecked")
List<Map<String, Object>> articles = (List<Map<String, Object>>) result.get("articles");
for (Map<String, Object> a : articles) {
    System.out.println(a.get("slug") + " " + a.get("view_count"));
}
System.out.println(articles.size() + " of " + result.get("total"));
```

`status` accepts `draft`, `published`, `scheduled`, `archived`, `flagged` or
`all`; `visibility`, `webhook_only` and `sort` narrow it further.
`blog.articles.list()` with no argument sends no filters.

### Update an article — and publish a draft

```java
Article updated = blog.articles.update("work-in-progress", Map.of(
        "title", "Finished at last",
        "body_markdown", "The complete post.",
        "publish", true  // flips a draft to published in the same call
));
System.out.println(updated.status + " " + updated.publishedAt);
```

Omitted fields are left unchanged.

### Read an article's comment thread

```java
Map<String, Object> thread = blog.comments.list(article.id, 50, 0); // articleId, limit, offset

@SuppressWarnings("unchecked")
List<Map<String, Object>> comments = (List<Map<String, Object>>) thread.get("comments");
for (Map<String, Object> c : comments) {
    @SuppressWarnings("unchecked")
    Map<String, Object> user = (Map<String, Object>) c.get("user");
    System.out.println("@" + user.get("username") + ": " + c.get("content"));
}
System.out.println(thread.get("totalCount") + " " + thread.get("hasMore"));
```

Pass `null` for `limit`/`offset` — or call `blog.comments.list(articleId)` — to
take the server defaults of 20 (max 100) and 0.

### Read and add reactions

```java
Map<String, Object> counts = blog.reactions.get(article.id);
System.out.println(counts.get("counts") + " " + counts.get("total"));

blog.reactions.add(Map.of("article_id", article.id, "type", "clap")); // like | clap | bookmark
blog.reactions.remove(article.id, "clap");
```

Note the asymmetry: `add` takes the request body as a `Map`, `remove` takes the
article id and type as positional arguments.

### Generate SEO titles

```java
Map<String, Object> result = blog.ai.titles(Map.of(
        "action", "seo", // "seo" from a keyword, "suggest" from existing copy
        "prompt", "shipping a static blog from GitHub Actions"));

@SuppressWarnings("unchecked")
List<Map<String, Object>> titles = (List<Map<String, Object>>) result.get("titles");
for (Map<String, Object> t : titles) {
    System.out.println(t.get("title") + " — " + t.get("hint"));
}
```

For `"suggest"`, put the article text under `"context"` instead of `"prompt"`.

### Read the analytics summary

```java
Map<String, Object> summary = blog.analytics.summary(30); // trailing days
System.out.println(summary.get("views") + " "
        + summary.get("revenue_cents") + " "
        + summary.get("active_subscribers"));
```

### Generate a cover image

```java
Map<String, Object> image = blog.images.generate(Map.of(
        "prompt", "a dark editorial illustration of a printing press",
        "size", "1792x1024"));
System.out.println(image.get("url"));
```

`blog.images.upload(body)` posts to the CDN upload route as JSON — pass the body
the API expects (a base64 `data` field). This SDK does not build a multipart
request for you; the Go and Python clients do.

### Embed a public article

```java
String url = MisarBlog.embedUrl("gulshan", "hello-misar", "dark");
// https://misar.blog/gulshan/hello-misar/embed?theme=dark
```

Pass `null` for `slug` to embed the whole profile, and `"auto"` or `null` for
the default theme.

## Errors

`BlogApiException` is a **checked** exception, so every call declares `throws
BlogApiException` (or you wrap it). `PlanLimitException` extends it — catch that
first.

| Type | Thrown when | Accessors |
| --- | --- | --- |
| `BlogApiException` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `getStatus()` |
| `PlanLimitException` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `getPlan()`, `getUpgradeUrl()`, `getRetryAfter()` |

```java
try {
    blog.ai.complete(Map.of("prompt", "Draft an intro paragraph"));
} catch (PlanLimitException e) {
    // Route the reader to checkout instead of reporting a bare failure.
    System.out.println(e.getPlan() + " plan is out of credits — upgrade at " + e.getUpgradeUrl());
} catch (BlogApiException e) {
    System.out.println(e.getStatus() + " " + e.getMessage());
}
```

Two differences from the TypeScript, Python, Go and Dart clients worth knowing:

- **No dedicated network-error type.** A transport failure, an interrupted
  back-off or an exhausted retry budget arrives as a `BlogApiException` with
  `getStatus() == 0` and the underlying `IOException` as its `getCause()`.
- **No 403 scope accessors.** `required_scope` and `granted_scopes` are not
  promoted to fields here; the raw error body is embedded in `getMessage()`.

## Links

- Misar.Blog — <https://misar.blog>
- API docs — <https://docs.misar.io/blog>
- OpenAPI spec — <https://api.misar.io/blog/v1/openapi.json>
- Mint an API key — <https://www.misar.blog/dashboard/settings/api>

## License

MIT — see [LICENSE](LICENSE).
