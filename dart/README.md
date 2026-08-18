# Misar.Blog Dart SDK

[Misar.Blog](https://misar.blog) is a hosted blogging platform. Authors write in
Markdown, publish or schedule articles, group them into series, and get
comments, reactions, follows, subscriber- and paid-gated posts, AI writing
helpers and per-account analytics. This package is the official Dart client for
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

- `MisarBlogClient` — constructed with
  `MisarBlogClient(apiKey: ..., baseUrl: ..., maxRetries: 3, httpClient: ...)`.
  Call `close()` when you are done to release the underlying HTTP client.
- Resource fields on the client: `articles`, `series`, `reactions`, `comments`,
  `follows`, `ai`, `images`, `account`, `analytics`. Plan, trial and upsell live
  on `account`.
- Errors: `MisarBlogError`, `MisarBlogPlanLimitError`, `MisarBlogNetworkError`.
- `embedUrl(username, slug: ..., theme: ...)` — a top-level function, pure
  string building for public embeds.
- Models: `Article`, `ArticleList`, `Series`, `SeriesList`, `Profile`, `Plan`,
  `PlanUsage`, `Analytics`, `ArticleReactions`, `ReactionResult`, `Comment`,
  `CommentAuthor`, `CommentsResult`, `FollowStatus`, `TitlesResult`,
  `TitleSuggestion`, `AiText`, `ImageResult`, `TrialStatus`. Every one wraps the
  decoded JSON and exposes it as `.raw`, so a field the API adds after this
  release is still reachable as `model.raw['new_field']`. Getters are nullable
  because the API omits fields that do not apply.
- `ArticleStatus` and `ArticleVisibility` enums document the accepted values;
  the methods themselves take plain `String`s (`status: 'published'`).

**Transport.** Built on `package:http`. Base URL
`https://api.misar.io/blog/v1`; the key goes on `Authorization: Bearer`.
Statuses 429/500/502/503/504 and transport failures are retried up to
`maxRetries` attempts (default 3) with exponential back-off from 300 ms; the
final attempt is always surfaced. Pass your own `http.Client` to control
timeouts or to inject `MockClient` in tests — the SDK sets no timeout of its
own. A `204` or empty body decodes to `{}`.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

## Install

```bash
dart pub add misarblog
```

Or pin it in `pubspec.yaml`:

```yaml
dependencies:
  misarblog: ^1.1.0
```

Dart SDK 3.0+. Pulls in `http ^1.2.0`.

## Quick start

```dart
import 'dart:io';
import 'package:misarblog/misarblog.dart';

Future<void> main() async {
  final blog = MisarBlogClient(apiKey: Platform.environment['MISARBLOG_API_KEY']!);

  final me = await blog.account.profile();
  print('authenticated as @${me.username}');

  final article = await blog.articles.publish(
    title: 'Shipping a blog from CI',
    bodyMarkdown: '# Shipping a blog from CI\n\nMarkdown in, article out.',
    tags: ['ci', 'automation'],
  );
  print(article.url);

  blog.close();
}
```

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
itself is a cookie-session flow and is deliberately not exposed here.

## Primary functions

### Publish (or schedule) an article

```dart
final article = await blog.articles.publish(
  title: 'Hello, Misar',
  bodyMarkdown: '# Hello\n\nFirst post.',
  tags: ['intro'],
  coverImageUrl: 'https://cdn.example.com/cover.png',
  visibility: 'public',                 // public | subscribers | paid | private | webhook_only
  scheduleAt: '2026-09-01T09:00:00Z',   // omit to publish immediately
);
print('${article.slug} ${article.status} ${article.url}');
```

### Save a draft

```dart
final draft = await blog.articles.createDraft(
  title: 'Work in progress',
  bodyMarkdown: 'Notes so far…',
  tags: ['draft'],
);
print(draft.editorUrl); // open in the Misar.Blog editor
```

### List your articles

```dart
final result = await blog.articles.list(status: 'published', limit: 20);
for (final a in result.articles) {
  print('${a.slug} ${a.raw['view_count']}');
}
print('${result.articles.length} of ${result.total}');
```

`status` accepts `draft`, `published`, `scheduled`, `archived` or `flagged`;
`visibility`, `webhookOnly` and `sort` narrow it further. `Article` exposes the
common fields as getters and everything else through `.raw`.

### Update an article — and publish a draft

```dart
final updated = await blog.articles.update(
  'work-in-progress',
  title: 'Finished at last',
  bodyMarkdown: 'The complete post.',
  publish: true, // flips a draft to published in the same call
);
print('${updated.status} ${updated.publishedAt}');
```

Omitted named arguments are left out of the request body, so the article keeps
those fields unchanged.

### Read an article's comment thread

```dart
final thread = await blog.comments.list(article.id!, limit: 50, offset: 0);
for (final c in thread.comments) {
  print('@${c.user?.username}: ${c.content} (${c.replyCount} replies)');
}
print('${thread.totalCount} ${thread.hasMore}');
```

`limit` defaults to 20 server-side (max 100) and `offset` to 0.

### Read and add reactions

```dart
final counts = await blog.reactions.get(article.id!);
print('${counts.counts['clap']} ${counts.total} ${counts.userReactions}');

await blog.reactions.add(articleId: article.id!, type: 'clap'); // like | clap | bookmark
await blog.reactions.remove(articleId: article.id!, type: 'clap');
```

### Generate SEO titles

```dart
final result = await blog.ai.titles(
  action: 'seo', // 'seo' from a keyword, 'suggest' from existing copy
  prompt: 'shipping a static blog from GitHub Actions',
);
for (final t in result.titles) {
  print('${t.title} — ${t.hint}');
}
```

For `'suggest'`, pass the article text as `context:` instead of `prompt:`.

### Read the analytics summary

```dart
final summary = await blog.analytics.get(days: 30);
print('${summary.views} ${summary.revenueCents} ${summary.activeSubscribers}');
```

### Generate a cover image

```dart
final image = await blog.images.generate(
  prompt: 'a dark editorial illustration of a printing press',
  size: '1792x1024',
);
print(image.url);
```

`blog.images.upload(payload)` posts to the CDN upload route as JSON — pass the
body the API expects (a base64 `data` field). This SDK does not build a
multipart request for you; the Go and Python clients do.

### Embed a public article

```dart
print(embedUrl('gulshan', slug: 'hello-misar', theme: 'dark'));
// https://misar.blog/gulshan/hello-misar/embed?theme=dark
```

Omit `slug` to embed the whole profile.

## Errors

Every failure throws. `MisarBlogPlanLimitError` and `MisarBlogNetworkError` both
extend `MisarBlogError`, so a single `on MisarBlogError` catches everything —
order narrowest-first when you want to tell them apart.

| Type | Thrown when | Extra fields |
| --- | --- | --- |
| `MisarBlogError` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `status`, `message`, `body` (the decoded error JSON, or `null`) |
| `MisarBlogPlanLimitError` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `plan`, `upgradeUrl`, `retryAfter`, `upgrade` |
| `MisarBlogNetworkError` | The request never reached the API — DNS, TLS, connection, socket failure — or the retry budget was exhausted | `status` is `0` |

```dart
try {
  await blog.ai.complete(prompt: 'Draft an intro paragraph');
} on MisarBlogPlanLimitError catch (e) {
  // Route the reader to checkout instead of reporting a bare failure.
  print('${e.plan} plan is out of credits — upgrade at ${e.upgradeUrl}');
} on MisarBlogNetworkError catch (e) {
  print('could not reach the API: ${e.message}');
} on MisarBlogError catch (e) {
  print('${e.status} ${e.message} ${e.body?['required_scope']}');
}
```

The 403 scope details (`required_scope`, `granted_scopes`) are not promoted to
named fields in this SDK — read them off `e.body`.

## Links

- Misar.Blog — <https://misar.blog>
- API docs — <https://docs.misar.io/blog>
- OpenAPI spec — <https://api.misar.io/blog/v1/openapi.json>
- Mint an API key — <https://www.misar.blog/dashboard/settings/api>

## License

MIT — see [LICENSE](LICENSE).
