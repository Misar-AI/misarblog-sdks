# Misar.Blog Java SDK

> Publish, schedule and manage a Misar.Blog account from Java.

[![Maven Central](https://img.shields.io/maven-central/v/blog.misar/misarblog)](https://central.sonatype.com/artifact/blog.misar/misarblog) [![Java](https://img.shields.io/badge/java-17%2B-orange)](https://openjdk.org) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**10 resource groups · 25 operations · blocking calls plus a CompletableFuture wrapper**

Works with any JVM application on Java 17 or newer — a CI job that syncs a blog
out of another CMS, a Spring service, a desktop reader, or a dashboard built on
a Misar.Blog account. Covers the developer API at `https://api.misar.io/blog/v1`
in full.

---

## Install

### Maven

```xml
<dependency>
    <groupId>blog.misar</groupId>
    <artifactId>misarblog</artifactId>
    <version>5.0.3</version>
</dependency>
```

### Gradle (Kotlin DSL)

```kotlin
implementation("blog.misar:misarblog:5.0.3")
```

### Gradle (Groovy)

```groovy
implementation 'blog.misar:misarblog:5.0.3'
```

Java 17+. Pulls in `com.fasterxml.jackson.core:jackson-databind`.

---

## Authentication

Mint a key in the dashboard at
<https://www.misar.blog/dashboard/settings/api>. Keys are prefixed `mbk_` and
travel on `Authorization: Bearer`; an OAuth 2.1 access token works on the same
header. Key management itself is a cookie-session flow and is deliberately not
exposed here. Construct the client with
`new MisarBlog(System.getenv("MISARBLOG_API_KEY"))`, as the first example below
does.

The machine-readable contract for every route below is the OpenAPI spec at
<https://api.misar.io/blog/v1/openapi.json>.

---

## API surface

25 operations across 10 resource groups, exposed as 27 methods — `articles.list`
and `comments.list` each carry a convenience overload.

| Resource | Method | Endpoint | What it does |
| --- | --- | --- | --- |
| `articles` | `list(Map)` | `GET /articles` | List your articles, filtered by status/visibility/sort |
| `articles` | `list()` | `GET /articles` | Same call with no params — convenience overload |
| `articles` | `get(String)` | `GET /articles/{slug}` | Fetch one article by slug or UUID, full Markdown body |
| `articles` | `publish(Map)` | `POST /articles` | Publish or schedule an article from Markdown |
| `articles` | `update(String, Map)` | `PATCH /articles/{slug}` | Update title/body/tags in place; `publish: true` flips a draft live |
| `articles` | `createDraft(Map)` | `POST /drafts` | Save a draft without publishing |
| `articles` | `search(Map)` | `GET /search` | Full-text search across articles, profiles and tags |
| `articles` | `recommendations(String, Integer)` | `GET /recommendations` | Related articles for an article id |
| `series` | `list()` | `GET /series` | List your series |
| `series` | `create(Map)` | `POST /series` | Create a series |
| `series` | `addArticle(String, Map)` | `POST /series/{slug}/articles` | Add an article to a series at a position |
| `reactions` | `get(String)` | `GET /reactions` | Reaction counts and the caller's own reactions |
| `reactions` | `add(Map)` | `POST /reactions` | Add a `like` / `clap` / `bookmark` |
| `reactions` | `remove(String, String)` | `DELETE /reactions` | Remove a reaction |
| `comments` | `list(String, Integer, Integer)` | `GET /comments` | An article's comment thread, newest first, replies one level deep |
| `comments` | `list(String)` | `GET /comments` | Same call with the server's default paging — convenience overload |
| `follows` | `status(String)` | `GET /follows` | Follower/following counts and whether the key's owner follows |
| `ai` | `complete(Map)` | `POST /ai/complete` | Free-form system + user completion |
| `ai` | `titles(Map)` | `POST /ai/titles` | SEO/AEO/GEO title suggestions (`seo` from a keyword, `suggest` from copy) |
| `images` | `generate(Map)` | `POST /images/generate` | AI cover image (`1024x1024`, `1792x1024`, `1024x1792`) |
| `images` | `upload(Map)` | `POST /images/upload` | Upload an image to the CDN |
| `account` | `me()` | `GET /me` | The authenticated creator profile |
| `analytics` | `summary(Integer)` | `GET /analytics` | Views, gross/net revenue, active subscribers for trailing N days |
| `analytics` | `upsellFunnel(Integer, String)` | `GET /upsell-funnel` | Per-feature upsell funnel (platform-admin keys only; a creator key gets 403) |
| `plan` | `get()` | `GET /plan` | Live plan and per-feature quota |
| `plan` | `trialStatus()` | `GET /trial` | Whether a self-serve trial is active |
| `plan` | `startTrial(Map)` | `POST /trial` | Start a self-serve trial |

---

## What's in the package

| Item | What it is |
| --- | --- |
| `blog.misar.sdk.MisarBlog` | The client. `new MisarBlog(apiKey)` for the defaults |
| `MisarBlog.Builder` | `new MisarBlog.Builder(apiKey).baseUrl(...).maxRetries(...).httpClient(...).build()` |
| Resource fields | `articles`, `series`, `reactions`, `comments`, `follows`, `ai`, `images`, `account`, `analytics`, `plan` — all `public final` |
| `async(BlogSupplier<T>)` | Runs any blocking call on the common `ForkJoinPool` and hands back a `CompletableFuture<T>`, wrapping the checked exception in a `CompletionException`. There is no separately implemented async transport |
| `BlogSupplier<T>` | The `@FunctionalInterface` `async` takes — a supplier that may throw `BlogApiException` |
| `MisarBlog.embedUrl(username, slug, theme)` | Static, pure string building for public embeds. Unauthenticated and unmetered |
| `blog.misar.sdk.models.Article`, `.Series` | Jackson-mapped POJOs with `@JsonIgnoreProperties(ignoreUnknown = true)`, so a field the API adds later will not break deserialisation |
| `BlogApiException` | Checked. Every call declares `throws BlogApiException`. Accessor: `getStatus()` |
| `PlanLimitException` | Extends `BlogApiException`. Accessors: `getPlan()`, `getUpgradeUrl()`, `getRetryAfter()` |

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

---

## Examples

### Authenticate and publish

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

---

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

---

## Links

- Website — https://www.misar.blog
- App — https://www.misar.blog
- Parent — https://misar.io
- Documentation — https://docs.misar.io/blog
- Source — https://github.com/Misar-AI/misarblog-sdks
- Maven Central — https://central.sonatype.com/artifact/blog.misar/misarblog

MIT © [Misar AI](https://misar.io)
