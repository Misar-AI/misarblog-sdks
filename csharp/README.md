# Misar.Blog C# SDK

> The official C#/.NET client for the Misar.Blog developer API.

[![NuGet](https://img.shields.io/nuget/v/MisarBlog)](https://www.nuget.org/packages/MisarBlog) [![.NET](https://img.shields.io/badge/.NET-8.0-512BD4)](https://dotnet.microsoft.com) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**14 operation groups · 25 async methods · .NET 8, returns JsonElement**

Works with any .NET 8 application — an ASP.NET service, a console job that syncs
a blog out of CI or another CMS, a desktop reader, a dashboard. No third-party
dependencies. Covers the developer API at `https://api.misar.io/blog/v1` in
full: publish or schedule Markdown articles, group them into series, and read
comments, reactions, follows, AI writing helpers and per-account analytics.

---

## Install

### .NET CLI

```bash
dotnet add package MisarBlog
```

### Package Manager

```powershell
Install-Package MisarBlog
```

### PackageReference

```xml
<PackageReference Include="MisarBlog" Version="5.0.1" />
```

Targets .NET 8. No third-party dependencies.

---

## Authentication

Mint a key at <https://www.misar.blog/dashboard/settings/api> and pass it to the
constructor — `new MisarBlogClient(apiKey)`. It travels on
`Authorization: Bearer`. Keys are prefixed `mbk_`; an OAuth 2.1 access token
works on the same header. Key management itself is a cookie-session flow and is
deliberately not exposed here.

The full request/response schema for every route below is published as an
OpenAPI document at <https://api.misar.io/blog/v1/openapi.json>.

---

## API surface

`MisarBlogClient` is flat — there are no resource objects. Every operation is a
public `async` method named `Group_ActionAsync`, returns `Task<JsonElement>`,
and takes a trailing optional `CancellationToken ct`. The 14 groups below are
name prefixes, not properties.

| Resource | Method | Endpoint | What it does |
| --- | --- | --- | --- |
| Articles | `Articles_ListAsync` | `GET /articles` | list your articles, filtered by status/visibility/sort |
| Articles | `Articles_GetAsync` | `GET /articles/{slug}` | fetch one article by slug or UUID, full Markdown body |
| Articles | `Articles_PublishAsync` | `POST /articles` | publish or schedule an article from Markdown |
| Articles | `Articles_UpdateAsync` | `PATCH /articles/{slug}` | update title/body/tags in place; `publish: true` flips a draft live |
| Articles | `Articles_CreateDraftAsync` | `POST /drafts` | save a draft without publishing |
| Search | `SearchAsync` | `GET /search` | full-text search across articles, profiles and tags |
| Recommendations | `Recommendations_GetAsync` | `GET /recommendations` | related articles for an article id |
| Series | `Series_ListAsync` | `GET /series` | list your series |
| Series | `Series_CreateAsync` | `POST /series` | create a series |
| Series | `Series_AddArticleAsync` | `POST /series/{slug}/articles` | add an article to a series at a position |
| Reactions | `Reactions_GetAsync` | `GET /reactions` | reaction counts and the caller's own reactions |
| Reactions | `Reactions_AddAsync` | `POST /reactions` | add a `like` / `clap` / `bookmark` |
| Reactions | `Reactions_RemoveAsync` | `DELETE /reactions` | remove a reaction |
| Comments | `Comments_ListAsync` | `GET /comments` | an article's comment thread, newest first, replies one level deep |
| Follows | `Follows_StatusAsync` | `GET /follows` | follower/following counts and whether the key's owner follows |
| AI | `Ai_CompleteAsync` | `POST /ai/complete` | free-form system + user completion |
| AI | `Ai_TitlesAsync` | `POST /ai/titles` | SEO/AEO/GEO title suggestions (`seo` from a keyword, `suggest` from copy) |
| Images | `Images_GenerateAsync` | `POST /images/generate` | AI cover image (`1024x1024`, `1792x1024`, `1024x1792`) |
| Images | `Images_UploadAsync` | `POST /images/upload` | upload an image to the CDN |
| Profile | `Profile_GetAsync` | `GET /me` | the authenticated creator profile |
| Analytics | `Analytics_GetAsync` | `GET /analytics` | views, gross/net revenue, active subscribers for trailing N days |
| Plan | `Plan_GetAsync` | `GET /plan` | live plan and per-feature quota |
| Trial | `Trial_StatusAsync` | `GET /trial` | whether a self-serve trial is active |
| Trial | `Trial_StartAsync` | `POST /trial` | start a self-serve trial |
| Upsell | `Upsell_FunnelAsync` | `GET /upsell-funnel` | per-feature upsell funnel (platform-admin keys only; a creator key gets 403) |

---

## What's in the package

| Item | What it is |
| --- | --- |
| `MisarBlogClient` | The client, `IDisposable`, constructed with `new MisarBlogClient(apiKey, baseUrl, maxRetries, httpClient)`. `MaxRetries` is readable; `Dispose()` releases the SDK's own `HttpClient` |
| `MisarBlogException` | Base exception for any non-2xx the SDK did not classify further. Carries `Status`, and on 403 `RequiredScope` / `GrantedScopes` |
| `MisarBlogPlanLimitException` | Derives from `MisarBlogException`. The subscription blocks the call. Carries `Plan`, `UpgradeUrl`, `RetryAfter` |
| `MisarBlogNetworkException` | Derives from `MisarBlogException`. Every attempt failed at the transport level; `Status` is `0` |
| `Embed.Url(username, slug, theme)` | Static, pure string building for public iframe embeds. Unauthenticated and unmetered |
| `Article`, `Series` | `sealed record`s with `From(JsonElement)` projections, for when you want a typed view of one response element |

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

---

## Examples

### Authenticate and publish

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

---

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

---

## Links

- Website — https://www.misar.blog
- App — https://www.misar.blog
- Parent — https://misar.io
- Documentation — https://docs.misar.io/blog
- Source — https://github.com/Misar-AI/misarblog-sdks
- NuGet — https://www.nuget.org/packages/MisarBlog

MIT © [Misar AI](https://misar.io)
