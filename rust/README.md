# Misar.Blog Rust SDK

[Misar.Blog](https://misar.blog) is a hosted blogging platform. Authors write in
Markdown, publish or schedule articles, group them into series, and get
comments, reactions, follows, subscriber- and paid-gated posts, AI writing
helpers and per-account analytics. This crate is the official Rust client for
its developer API at `https://api.misar.io/blog/v1` — for anyone automating
publishing, syncing a blog out of CI or another CMS, or building a reader,
dashboard or integration on top of a Misar.Blog account.

## Features

The API surface this crate covers, in full:

- **Articles** — list and filter by status or visibility, fetch by slug or
  UUID, publish or schedule from Markdown, update in place, and save drafts.
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

## What's in the crate

- `MisarBlog` — the client. `MisarBlog::new(api_key)`, then
  `.with_base_url(url)` and `.with_max_retries(n)` to reconfigure.
- Resource fields on the client: `articles`, `series`, `reactions`, `ai`,
  `images`, `account`, `analytics`, `plan`, `comments`, `follows`. Series/trial
  live under `plan` (`trial_status`, `start_trial`) and the upsell funnel under
  `analytics` (`upsell_funnel`).
- `misarblog::types` — `Serialize` request bodies (`PublishArticleRequest`,
  `CreateDraftRequest`, `UpdateArticleRequest`, `CreateSeriesRequest`,
  `AddToSeriesRequest`, `AddReactionRequest`, `AiCompleteRequest`,
  `GenerateTitlesRequest`, `GenerateImageRequest`, `StartTrialRequest`,
  `ListArticlesParams`, `SearchParams`) and `Deserialize` responses (`Article`,
  `Series`, `Comment`, `CommentsResult`, `FollowStatus`).
- `errors::BlogApiError` — one enum with `Api`, `PlanLimit`, `Network` and
  `Json` variants, plus `.status()` and `.upgrade_url()` helpers.
- `misarblog::embed_url(username, slug, theme)` — a free function, independent
  of the client.
- `DEFAULT_BASE_URL`.

**Typed vs. free-form.** Endpoints with a stable schema — `articles.get`,
`publish`, `update`, `create_draft`, `series.create`, `comments.list`,
`follows.status` — deserialize into structs. The rest (analytics, search, plan,
reactions, AI, images, profile, trial, recommendations) return
`serde_json::Value` so no field is silently dropped as the API grows.

**Transport.** Built on `reqwest` + `tokio`. Base URL
`https://api.misar.io/blog/v1`; the key goes on `Authorization: Bearer`.
Statuses 429/500/502/503/504 and network errors are retried up to `max_retries`
attempts (default 3) with exponential back-off from 500 ms; the final attempt is
always sent. Request timeout is 30 s. A `204` yields `Value::Null`.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

## Install

```toml
[dependencies]
misarblog = "1.1"
tokio = { version = "1", features = ["full"] }
```

Or `cargo add misarblog tokio -F tokio/full`. Edition 2021.

## Quick start

```rust
use misarblog::{types, BlogApiError, MisarBlog};

#[tokio::main]
async fn main() -> Result<(), BlogApiError> {
    let blog = MisarBlog::new(&std::env::var("MISARBLOG_API_KEY").unwrap());

    let me = blog.account.me().await?;
    println!("authenticated as @{}", me["username"]);

    let article = blog
        .articles
        .publish(&types::PublishArticleRequest {
            title: "Shipping a blog from CI".into(),
            body_markdown: "# Shipping a blog from CI\n\nMarkdown in, article out.".into(),
            tags: vec!["ci".into(), "automation".into()],
            ..Default::default()
        })
        .await?;
    println!("{}", article.url);

    Ok(())
}
```

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
itself is a cookie-session flow and is deliberately not exposed here.

## Primary functions

### Publish (or schedule) an article

```rust
use misarblog::types::PublishArticleRequest;

let article = blog
    .articles
    .publish(&PublishArticleRequest {
        title: "Hello, Misar".into(),
        body_markdown: "# Hello\n\nFirst post.".into(),
        tags: vec!["intro".into()],
        cover_image_url: Some("https://cdn.example.com/cover.png".into()),
        // public | subscribers | paid | private | webhook_only
        visibility: Some("public".into()),
        // omit to publish immediately
        schedule_at: Some("2026-09-01T09:00:00Z".into()),
    })
    .await?;
println!("{} {} {}", article.slug, article.status, article.url);
```

### Save a draft

```rust
use misarblog::types::CreateDraftRequest;

let draft = blog
    .articles
    .create_draft(&CreateDraftRequest {
        title: "Work in progress".into(),
        body_markdown: "Notes so far…".into(),
        tags: vec!["draft".into()],
    })
    .await?;
println!("{}", draft.editor_url); // open in the Misar.Blog editor
```

### List your articles

```rust
use misarblog::types::ListArticlesParams;

// Returns serde_json::Value — the list envelope is `{ articles: [...], total }`.
let page = blog
    .articles
    .list(&ListArticlesParams {
        status: Some("published".into()), // draft|published|scheduled|archived|flagged
        limit: Some(20),
        ..Default::default()
    })
    .await?;
for a in page["articles"].as_array().unwrap_or(&vec![]) {
    println!("{} {}", a["slug"], a["view_count"]);
}
println!("total {}", page["total"]);
```

### Update an article — and publish a draft

```rust
use misarblog::types::UpdateArticleRequest;

let updated = blog
    .articles
    .update(
        "work-in-progress",
        &UpdateArticleRequest {
            title: Some("Finished at last".into()),
            body_markdown: Some("The complete post.".into()),
            publish: Some(true), // flips a draft to published in the same call
            ..Default::default()
        },
    )
    .await?;
println!("{} {:?}", updated.status, updated.published_at);
```

### Read an article's comment thread

```rust
let thread = blog.comments.list(&article.id, Some(50), Some(0)).await?;
for c in &thread.comments {
    println!("@{}: {} ({} replies)", c.user.username, c.content, c.reply_count);
}
println!("{} {}", thread.total_count, thread.has_more);
```

### Read and add reactions

```rust
use misarblog::types::AddReactionRequest;

let counts = blog.reactions.get(&article.id).await?;
println!("{} {}", counts["counts"]["clap"], counts["total"]);

blog.reactions
    .add(&AddReactionRequest {
        article_id: article.id.clone(),
        kind: "clap".into(), // like | clap | bookmark
    })
    .await?;
blog.reactions.remove(&article.id, "clap").await?;
```

### Generate SEO titles

```rust
use misarblog::types::GenerateTitlesRequest;

let result = blog
    .ai
    .titles(&GenerateTitlesRequest {
        action: "seo".into(), // "seo" from a keyword, "suggest" from existing copy
        prompt: "shipping a static blog from GitHub Actions".into(),
        context: None,
    })
    .await?;
for t in result["titles"].as_array().unwrap_or(&vec![]) {
    println!("{} — {}", t["title"], t["hint"]);
}
```

### Read the analytics summary

```rust
let summary = blog.analytics.summary(Some(30)).await?; // trailing days
println!(
    "{} views, {} cents, {} subscribers",
    summary["views"], summary["revenue_cents"], summary["active_subscribers"]
);
```

### Embed a public article

```rust
let url = misarblog::embed_url("gulshan", Some("hello-misar"), "dark");
// https://misar.blog/gulshan/hello-misar/embed?theme=dark
```

## Errors

Every fallible call returns `Result<_, BlogApiError>`. One enum covers all four
failure modes.

| Variant | Returned when | Fields |
| --- | --- | --- |
| `BlogApiError::Api` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `status`, `message` |
| `BlogApiError::PlanLimit` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `status`, `message`, `plan`, `upgrade_url`, `retry_after` |
| `BlogApiError::Network` | The request never reached the API — DNS, TLS, connection, timeout (wraps `reqwest::Error`) | — |
| `BlogApiError::Json` | Request serialization or response deserialization failed (wraps `serde_json::Error`) | — |

```rust
match blog.ai.complete(&types::AiCompleteRequest {
    prompt: "Draft an intro paragraph".into(),
    ..Default::default()
}).await {
    Ok(v) => println!("{}", v["text"]),
    // Route the reader to checkout instead of reporting a bare failure.
    Err(BlogApiError::PlanLimit { plan, upgrade_url, retry_after, .. }) => {
        println!("{plan:?} is out of credits — upgrade at {upgrade_url:?} ({retry_after:?}s)");
    }
    Err(e) => eprintln!("{} {e}", e.status()),
}
```

`e.status()` returns `0` for `Network` and `Json`; `e.upgrade_url()` returns
`Some(_)` only for `PlanLimit`.

## Links

- Misar.Blog — <https://misar.blog>
- API docs — <https://docs.misar.io/blog>
- OpenAPI spec — <https://api.misar.io/blog/v1/openapi.json>
- Mint an API key — <https://www.misar.blog/dashboard/settings/api>

## License

MIT — see [LICENSE](LICENSE).
