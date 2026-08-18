# Misar.Blog C# SDK

[Misar.Blog](https://misar.blog) is a hosted blogging platform. Authors write in
Markdown, publish or schedule articles, group them into series, and get
comments, reactions, follows, subscriber- and paid-gated posts, AI writing
helpers and per-account analytics. This package is the official C#/.NET client
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

- `MisarBlogClient` — one flat client, `IDisposable`, constructed with
  `new MisarBlogClient(apiKey, baseUrl, maxRetries, httpClient)`. Every
  operation is an `async` method named `Group_ActionAsync` and every one takes
  an optional `CancellationToken ct`.
- Methods, grouped by prefix: `Articles_*`, `Series_*`, `Reactions_*`,
  `Comments_*`, `Follows_*`, `Ai_*`, `Images_*`, `Profile_*`, `Plan_*`,
  `Trial_*`, `Analytics_*`, `Upsell_*`, plus `SearchAsync` and
  `Recommendations_GetAsync`.
- Exceptions: `MisarBlogException`, `MisarBlogPlanLimitException`,
  `MisarBlogNetworkException`.
- `Embed.Url(username, slug, theme)` — static, pure string building for public
  embeds.
- `Article` and `Series` records with `From(JsonElement)` projections.

**Responses are `JsonElement`.** Unlike the TypeScript and Go clients, this SDK
does not deserialise every route into a generated model — each method hands back
`System.Text.Json.JsonElement` so you read fields with `GetProperty(...)`, or
project one into the `Article` / `Series` records, or `Deserialize<T>()` into
your own type. That keeps new API fields readable without a package bump.

**Transport.** `System.Net.Http.HttpClient`, no third-party dependencies. Base
URL `https://api.misar.io/blog/v1`; the key goes on `Authorization: Bearer`.
Statuses 429/500/502/503/504 and transport failures are retried up to
`maxRetries` attempts (default 3) with exponential back-off from 500 ms; the
final attempt is always surfaced. Pass your own `HttpClient` to control timeout,
proxy or handler — the SDK's own instance defaults to a 30 s timeout and is
disposed with the client; one you supply is left alone.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

## Install

```bash
dotnet add package MisarBlog --version 1.1.0
```

Targets .NET 8.

## Quick start

```csharp
using System.Text.Json;
using MisarBlog;

using var blog = new MisarBlogClient(Environment.GetEnvironmentVariable("MISARBLOG_API_KEY")!);

JsonElement me = await blog.Profile_GetAsync();
Console.WriteLine($"authenticated as @{me.GetProperty("username").GetString()}");

JsonElement article = await blog.Articles_PublishAsync(new
{
    title = "Shipping a blog from CI",
    body_markdown = "# Shipping a blog from CI\n\nMarkdown in, article out.",
    tags = new[] { "ci", "automation" },
});
Console.WriteLine(article.GetProperty("url").GetString());
```

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
itself is a cookie-session flow and is deliberately not exposed here.

## Primary functions

### Publish (or schedule) an article

```csharp
JsonElement article = await blog.Articles_PublishAsync(new
{
    title = "Hello, Misar",
    body_markdown = "# Hello\n\nFirst post.",
    tags = new[] { "intro" },
    cover_image_url = "https://cdn.example.com/cover.png",
    visibility = "public",                 // public | subscribers | paid | private | webhook_only
    schedule_at = "2026-09-01T09:00:00Z",  // omit to publish immediately
});

Console.WriteLine(article.GetProperty("slug").GetString());
Console.WriteLine(article.GetProperty("status").GetString());
```

`Articles_PublishAsync` takes the request body as an object — an anonymous type
as above, a `Dictionary<string, object>`, or any type your serializer emits with
the API's snake_case field names. Only `title` and `body_markdown` are required.

### Save a draft

```csharp
JsonElement draft = await blog.Articles_CreateDraftAsync(new
{
    title = "Work in progress",
    body_markdown = "Notes so far…",
    tags = new[] { "draft" },
});
Console.WriteLine(draft.GetProperty("editor_url").GetString()); // open in the editor
```

### List your articles

```csharp
JsonElement result = await blog.Articles_ListAsync(status: "published", limit: 20);

foreach (JsonElement a in result.GetProperty("articles").EnumerateArray())
    Console.WriteLine($"{a.GetProperty("slug").GetString()} {a.GetProperty("view_count").GetInt32()}");

Console.WriteLine($"total {result.GetProperty("total").GetInt32()}");
```

`status` accepts `draft`, `published`, `scheduled`, `archived`, `flagged` or
`all`; `visibility`, `webhookOnly` and `sort` narrow it further. Or project each
element with the bundled record:

```csharp
Article? typed = Article.From(result.GetProperty("articles")[0]);
Console.WriteLine(typed?.Title);
```

### Update an article — and publish a draft

```csharp
JsonElement updated = await blog.Articles_UpdateAsync("work-in-progress", new
{
    title = "Finished at last",
    body_markdown = "The complete post.",
    publish = true, // flips a draft to published in the same call
});
Console.WriteLine(updated.GetProperty("status").GetString());
```

Omitted fields are left unchanged.

### Read an article's comment thread

```csharp
string articleId = article.GetProperty("id").GetString()!;
JsonElement thread = await blog.Comments_ListAsync(articleId, limit: 50, offset: 0);

foreach (JsonElement c in thread.GetProperty("comments").EnumerateArray())
{
    string author = c.GetProperty("user").GetProperty("username").GetString()!;
    Console.WriteLine($"@{author}: {c.GetProperty("content").GetString()}");
}
Console.WriteLine(thread.GetProperty("hasMore").GetBoolean());
```

`limit` defaults to 20 server-side (max 100) and `offset` to 0.

### Read and add reactions

```csharp
JsonElement counts = await blog.Reactions_GetAsync(articleId);
Console.WriteLine(counts.GetProperty("counts").GetProperty("clap").GetInt32());
Console.WriteLine(counts.GetProperty("total").GetInt32());

await blog.Reactions_AddAsync(articleId, "clap");    // like | clap | bookmark
await blog.Reactions_RemoveAsync(articleId, "clap");
```

### Generate SEO titles

```csharp
JsonElement result = await blog.Ai_TitlesAsync(
    action: "seo", // "seo" from a keyword, "suggest" from existing copy
    prompt: "shipping a static blog from GitHub Actions");

foreach (JsonElement t in result.GetProperty("titles").EnumerateArray())
    Console.WriteLine($"{t.GetProperty("title").GetString()} — {t.GetProperty("hint").GetString()}");
```

For `"suggest"`, pass the article text as `context:` instead of `prompt:`.

### Read the analytics summary

```csharp
JsonElement summary = await blog.Analytics_GetAsync(days: 30);
Console.WriteLine(summary.GetProperty("views").GetInt32());
Console.WriteLine(summary.GetProperty("revenue_cents").GetInt32());
Console.WriteLine(summary.GetProperty("active_subscribers").GetInt32());
```

### Generate a cover image

```csharp
JsonElement image = await blog.Images_GenerateAsync(
    "a dark editorial illustration of a printing press", size: "1792x1024");
Console.WriteLine(image.GetProperty("url").GetString());
```

`Images_UploadAsync(payload)` posts to the CDN upload route as JSON — pass the
body the API expects (a base64 `data` field). This SDK does not build a
multipart request for you; the Go and Python clients do.

### Embed a public article

```csharp
string url = Embed.Url("gulshan", "hello-misar", theme: "dark");
// https://misar.blog/gulshan/hello-misar/embed?theme=dark
```

Pass `null` for `slug` to embed the whole profile.

## Errors

Every failure throws. `MisarBlogPlanLimitException` and
`MisarBlogNetworkException` both derive from `MisarBlogException`, so order your
`catch` blocks narrowest-first, or catch the base type for everything.

| Type | Thrown when | Members |
| --- | --- | --- |
| `MisarBlogException` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `Status`, and on 403 `RequiredScope` / `GrantedScopes` |
| `MisarBlogPlanLimitException` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `Plan`, `UpgradeUrl`, `RetryAfter` |
| `MisarBlogNetworkException` | Every attempt failed at the transport level — DNS, TLS, connection, timeout, cancellation | `Status` is `0`. The last transport failure's message is folded into `Message`; the exception itself carries no `InnerException` |

```csharp
try
{
    await blog.Ai_CompleteAsync("Draft an intro paragraph");
}
catch (MisarBlogPlanLimitException e)
{
    // Route the reader to checkout instead of reporting a bare failure.
    Console.WriteLine($"{e.Plan} plan is out of credits — upgrade at {e.UpgradeUrl}");
}
catch (MisarBlogNetworkException e)
{
    Console.WriteLine($"could not reach the API: {e.Message}");
}
catch (MisarBlogException e)
{
    Console.WriteLine($"{e.Status} {e.Message} {e.RequiredScope}");
}
```

## Links

- Misar.Blog — <https://misar.blog>
- API docs — <https://docs.misar.io/blog>
- OpenAPI spec — <https://api.misar.io/blog/v1/openapi.json>
- Mint an API key — <https://www.misar.blog/dashboard/settings/api>

## License

MIT — see [LICENSE](LICENSE).
