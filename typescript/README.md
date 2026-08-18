# Misar.Blog TypeScript SDK

[Misar.Blog](https://misar.blog) is a hosted blogging platform. Authors write in
Markdown, publish or schedule articles, group them into series, and get
comments, reactions, follows, subscriber- and paid-gated posts, AI writing
helpers and per-account analytics. This package is the official
TypeScript/JavaScript client for its developer API at
`https://api.misar.io/blog/v1` — for anyone automating publishing, syncing a
blog out of CI or another CMS, or building a reader, dashboard or integration
on top of a Misar.Blog account.

## Features

The API surface this SDK covers, in full:

- **Articles** — list and filter by status, fetch by slug or UUID, publish or
  schedule from Markdown, update in place, and save drafts.
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
- **Embeds** — build a public iframe URL, or mount an iframe, for a profile or
  a single article. Unauthenticated and unmetered.

That is all 25 key-authenticated operations.

## What's in the package

- `MisarBlog` — the client. Constructed with `{ apiKey, baseUrl?, maxRetries?,
  timeoutMs?, fetch? }`.
- Resource accessors on the client: `articles`, `series`, `reactions`,
  `comments`, `follows`, `ai`, `images`, `profiles`, `analytics`, `plan`,
  `upsell`.
- `BlogApiClient` — the raw transport (`get` / `post` / `patch` / `delete`),
  exported for calls this SDK does not wrap yet.
- Errors: `BlogApiError`, `PlanLimitError`, `NetworkError`.
- `embed(container, options)` and `embedUrl(options)` — DOM helpers for public
  embeds; `embed` needs a browser, `embedUrl` is pure string building.
- Full type declarations for every request and response shape (`Article`,
  `ArticleSummary`, `Comment`, `Series`, `Profile`, `AnalyticsSummary`,
  `Plan`, …), shipped as ESM, CJS and an IIFE browser bundle.

**Transport.** Base URL `https://api.misar.io/blog/v1`; the key goes on
`Authorization: Bearer`. Statuses 429/500/502/503/504 and transport failures
are retried up to `maxRetries` attempts (default 3) with exponential back-off
from 300 ms; the final attempt is always sent. Per-request timeout defaults to
30 s. A `204` resolves to `{}`.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

## Install

```bash
npm install @misarblog/sdk
```

Requires Node 18+ (for global `fetch`), or any modern browser.

## Quick start

```ts
import { MisarBlog, PlanLimitError } from "@misarblog/sdk";

const blog = new MisarBlog({ apiKey: process.env.MISARBLOG_API_KEY! });

const me = await blog.profiles.me();
console.log(`authenticated as @${me.username}`);

const article = await blog.articles.create({
  title: "Shipping a blog from CI",
  body_markdown: "# Shipping a blog from CI\n\nMarkdown in, article out.",
  tags: ["ci", "automation"],
});
console.log(article.url);
```

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
itself is a cookie-session flow and is deliberately not exposed here.

## Primary functions

### Publish (or schedule) an article

```ts
const article = await blog.articles.create({
  title: "Hello, Misar",
  body_markdown: "# Hello\n\nFirst post.",
  tags: ["intro"],
  cover_image_url: "https://cdn.example.com/cover.png",
  visibility: "public",              // public | subscribers | paid | private | webhook_only
  schedule_at: "2026-09-01T09:00:00Z", // omit to publish immediately
});
console.log(article.slug, article.status, article.url);
```

### Save a draft

```ts
const draft = await blog.articles.createDraft({
  title: "Work in progress",
  body_markdown: "Notes so far…",
  tags: ["draft"],
});
console.log(draft.editor_url); // open in the Misar.Blog editor
```

### List your articles

```ts
const { articles, total } = await blog.articles.list({
  status: "published", // draft | published | scheduled | archived | flagged | all
  limit: 20,
});
for (const a of articles) console.log(a.slug, a.view_count);
console.log(`${articles.length} of ${total}`);
```

### Update an article — and publish a draft

```ts
const updated = await blog.articles.update("work-in-progress", {
  title: "Finished at last",
  body_markdown: "The complete post.",
  publish: true, // flips a draft to published in the same call
});
console.log(updated.status, updated.published_at);
```

### Read an article's comment thread

```ts
const { comments, totalCount, hasMore } = await blog.comments.list(article.id, {
  limit: 50,
  offset: 0,
});
for (const c of comments) {
  console.log(`@${c.user.username}: ${c.content} (${c.reply_count} replies)`);
}
console.log({ totalCount, hasMore });
```

### Read and add reactions

```ts
const counts = await blog.reactions.get(article.id);
console.log(counts.counts.clap, counts.total, counts.user_reactions);

await blog.reactions.add(article.id, "clap");   // like | clap | bookmark
await blog.reactions.remove(article.id, "clap");
```

### Generate SEO titles

```ts
const { titles } = await blog.ai.titles({
  action: "seo", // "seo" from a keyword, "suggest" from existing copy
  prompt: "shipping a static blog from GitHub Actions",
});
for (const t of titles) console.log(t.title, "—", t.hint);
```

### Read the analytics summary

```ts
const summary = await blog.analytics.summary(30); // trailing days
console.log(summary.views, summary.revenue_cents, summary.active_subscribers);
```

### Embed a public article

```ts
import { embed, embedUrl } from "@misarblog/sdk";

const url = embedUrl({ username: "gulshan", slug: "hello-misar", theme: "dark" });

// In the browser — appends a lazy iframe and hands back a destructor.
const { destroy } = embed(document.querySelector("#slot")!, {
  username: "gulshan",
  slug: "hello-misar",
  height: "800px",
});
```

## Errors

Every failure throws. All three types extend `Error` and carry `status` and the
decoded `body`.

| Type | Thrown when | Extra |
| --- | --- | --- |
| `BlogApiError` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `status`, `body`, and on 403 `requiredScope` / `grantedScopes` |
| `PlanLimitError` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `plan`, `upgradeUrl`, `retryAfter`, `upgrade` |
| `NetworkError` | The request never reached the API — DNS, TLS, connection, timeout — or the retry budget was exhausted | `cause`, `status` is `0` |

```ts
import { BlogApiError, NetworkError, PlanLimitError } from "@misarblog/sdk";

try {
  await blog.ai.complete({ prompt: "Draft an intro paragraph" });
} catch (err) {
  if (err instanceof PlanLimitError) {
    // Route the reader to checkout instead of reporting a bare failure.
    console.log(`${err.plan} plan is out of credits — upgrade at ${err.upgradeUrl}`);
  } else if (err instanceof NetworkError) {
    console.error("could not reach the API:", err.cause);
  } else if (err instanceof BlogApiError) {
    console.error(err.status, err.message, err.requiredScope);
  }
}
```

`PlanLimitError` extends `BlogApiError`, so order your `instanceof` checks
narrowest-first.

## Links

- Misar.Blog — <https://misar.blog>
- API docs — <https://docs.misar.io/blog>
- OpenAPI spec — <https://api.misar.io/blog/v1/openapi.json>
- Mint an API key — <https://www.misar.blog/dashboard/settings/api>

## License

MIT — see [LICENSE](LICENSE).
