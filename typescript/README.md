# Misar.Blog TypeScript SDK

> Typed client for the Misar.Blog developer API — publish, schedule and manage Markdown articles from TypeScript or JavaScript.

[![npm](https://img.shields.io/npm/v/%40misarblog%2Fsdk)](https://www.npmjs.com/package/@misarblog/sdk) [![Node](https://img.shields.io/badge/node-%3E%3D18-brightgreen)](https://nodejs.org) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**11 resource accessors · 25 operations · ESM, CJS and a browser IIFE bundle**

Works against the Misar.Blog developer API at `https://api.misar.io/blog/v1` — for
anyone automating publishing, syncing a blog out of CI or another CMS, or building
a reader, dashboard or integration on top of a Misar.Blog account.

---

## Install

### npm

```bash
npm install @misarblog/sdk
```

### pnpm

```bash
pnpm install @misarblog/sdk
```

### yarn

```bash
yarn add @misarblog/sdk
```

### bun

```bash
bun add @misarblog/sdk
```

Requires Node 18+ (for global `fetch`), or any modern browser.

---

## Authentication

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_` and go on the `Authorization: Bearer` header; an OAuth 2.1 access token
works on the same header. Key management itself is a cookie-session flow and is
deliberately not exposed here.

Feature access and throughput follow the subscription attached to the key. The
machine-readable contract for every route below is the OpenAPI spec at
<https://api.misar.io/blog/v1/openapi.json>.

---

## API surface

| Resource | Method | Endpoint | What it does |
| --- | --- | --- | --- |
| `articles` | `list` | `GET /articles` | list your articles, filtered by status/visibility/sort |
| `articles` | `get` | `GET /articles/{slug}` | fetch one article by slug or UUID, full Markdown body |
| `articles` | `create` | `POST /articles` | publish or schedule an article from Markdown |
| `articles` | `update` | `PATCH /articles/{slug}` | update title/body/tags in place; `publish: true` flips a draft live |
| `articles` | `createDraft` | `POST /drafts` | save a draft without publishing |
| `articles` | `search` | `GET /search` | full-text search across articles, profiles and tags |
| `articles` | `recommendations` | `GET /recommendations` | related articles for an article id |
| `series` | `list` | `GET /series` | list your series |
| `series` | `create` | `POST /series` | create a series |
| `series` | `addArticle` | `POST /series/{slug}/articles` | add an article to a series at a position |
| `reactions` | `get` | `GET /reactions` | reaction counts and the caller's own reactions |
| `reactions` | `add` | `POST /reactions` | add a `like` / `clap` / `bookmark` |
| `reactions` | `remove` | `DELETE /reactions` | remove a reaction |
| `comments` | `list` | `GET /comments` | an article's comment thread, newest first, replies one level deep |
| `follows` | `status` | `GET /follows` | follower/following counts and whether the key's owner follows |
| `ai` | `complete` | `POST /ai/complete` | free-form system + user completion |
| `ai` | `titles` | `POST /ai/titles` | SEO/AEO/GEO title suggestions (`seo` from a keyword, `suggest` from copy) |
| `images` | `generate` | `POST /images/generate` | AI cover image (`1024x1024`, `1792x1024`, `1024x1792`) |
| `images` | `upload` | `POST /images/upload` | upload an image to the CDN |
| `profiles` | `me` | `GET /me` | the authenticated creator profile |
| `analytics` | `summary` | `GET /analytics` | views, gross/net revenue, active subscribers for trailing N days |
| `plan` | `get` | `GET /plan` | live plan and per-feature quota |
| `plan` | `trialStatus` | `GET /trial` | whether a self-serve trial is active |
| `plan` | `startTrial` | `POST /trial` | start a self-serve trial |
| `upsell` | `funnel` | `GET /upsell-funnel` | per-feature upsell funnel (platform-admin keys only; a creator key gets 403) |

That is all 25 key-authenticated operations.

---

## What's in the package

| Item | What it is |
| --- | --- |
| `MisarBlog` | The client. Constructed with `{ apiKey, baseUrl?, maxRetries?, timeoutMs?, fetch? }`. |
| Resource accessors | `articles`, `series`, `reactions`, `comments`, `follows`, `ai`, `images`, `profiles`, `analytics`, `plan`, `upsell` — the 11 groups in the table above. |
| `BlogApiClient` | The raw transport (`get` / `post` / `patch` / `delete`), exported for calls this SDK does not wrap yet. |
| `BlogApiError`, `PlanLimitError`, `NetworkError` | The three error types; all extend `Error` and carry `status` and the decoded `body`. |
| `embed(container, options)`, `embedUrl(options)` | DOM helpers for public embeds; `embed` needs a browser, `embedUrl` is pure string building. Unauthenticated and unmetered. |
| Type declarations | Every request and response shape (`Article`, `ArticleSummary`, `Comment`, `Series`, `Profile`, `AnalyticsSummary`, `Plan`, …), shipped as ESM, CJS and an IIFE browser bundle. |

**Transport.** Base URL `https://api.misar.io/blog/v1`; the key goes on
`Authorization: Bearer`. Statuses 429/500/502/503/504 and transport failures
are retried up to `maxRetries` attempts (default 3) with exponential back-off
from 300 ms; the final attempt is always sent. Per-request timeout defaults to
30 s. A `204` resolves to `{}`.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

---

## Examples

### Authenticate and publish

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

---

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

---

## Links

- Website — https://www.misar.blog
- App — https://www.misar.blog
- Parent — https://misar.io
- Documentation — https://docs.misar.io/blog
- Source — https://github.com/Misar-AI/misarblog-sdks
- npm — https://www.npmjs.com/package/@misarblog/sdk

MIT © [Misar AI](https://misar.io)
