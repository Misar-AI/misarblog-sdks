# Misar.Blog Dart SDK

> The official Dart client for the Misar.Blog developer API.

[![pub](https://img.shields.io/pub/v/misarblog)](https://pub.dev/packages/misarblog) [![Dart](https://img.shields.io/badge/dart-%3E%3D3.0-0175C2)](https://dart.dev) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**9 resource groups · 25 operations · Dart 3, one `package:http` dependency**

Works with any Dart 3 program and any Flutter app — a reader UI, a CLI that
syncs a blog out of CI or another CMS, a server-side handler. Covers the
developer API at `https://api.misar.io/blog/v1` in full: publish or schedule
Markdown articles, group them into series, and read comments, reactions,
follows, AI writing helpers and per-account analytics.

---

## Install

### Dart

```bash
dart pub add misarblog
```

### Flutter

```bash
flutter pub add misarblog
```

### pubspec.yaml

```yaml
dependencies:
  misarblog: ^5.0.1
```

Dart SDK `>=3.0.0 <4.0.0`. Pulls in `http ^1.2.0`.

---

## Authentication

Mint a key at <https://www.misar.blog/dashboard/settings/api> and pass it to the
constructor — `MisarBlogClient(apiKey: ...)`. It travels on
`Authorization: Bearer`. Keys are prefixed `mbk_`; an OAuth 2.1 access token
works on the same header. Key management itself is a cookie-session flow and is
deliberately not exposed here.

The full request/response schema for every route below is published as an
OpenAPI document at <https://api.misar.io/blog/v1/openapi.json>.

---

## API surface

Nine resource fields hang off `MisarBlogClient`. Note that this SDK folds
search and recommendations onto `articles`, and profile, plan, trial and upsell
onto `account`. Every method returns a `Future`.

| Resource | Method | Endpoint | What it does |
| --- | --- | --- | --- |
| `articles` | `list` | `GET /articles` | list your articles, filtered by status/visibility/sort |
| `articles` | `get` | `GET /articles/{slug}` | fetch one article by slug or UUID, full Markdown body |
| `articles` | `publish` | `POST /articles` | publish or schedule an article from Markdown |
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
| `account` | `profile` | `GET /me` | the authenticated creator profile |
| `account` | `plan` | `GET /plan` | live plan and per-feature quota |
| `account` | `trialStatus` | `GET /trial` | whether a self-serve trial is active |
| `account` | `startTrial` | `POST /trial` | start a self-serve trial |
| `account` | `upsellFunnel` | `GET /upsell-funnel` | per-feature upsell funnel (platform-admin keys only; a creator key gets 403) |
| `analytics` | `get` | `GET /analytics` | views, gross/net revenue, active subscribers for trailing N days |

---

## What's in the package

| Item | What it is |
| --- | --- |
| `MisarBlogClient` | The client, constructed with `MisarBlogClient(apiKey: ..., baseUrl: ..., maxRetries: 3, httpClient: ...)`. Call `close()` when you are done to release the underlying HTTP client |
| `MisarBlogClient.request` | Public escape hatch — `request(method, path, {body, query})` returns the decoded JSON for a route this SDK does not wrap yet |
| `MisarBlogError` | Base error for any non-2xx the SDK did not classify further. Carries `status`, `message`, `body` |
| `MisarBlogPlanLimitError` | Extends `MisarBlogError`. The subscription blocks the call. Carries `plan`, `upgradeUrl`, `retryAfter`, `upgrade` |
| `MisarBlogNetworkError` | Extends `MisarBlogError`. The request never reached the API; `status` is `0` |
| `embedUrl` / `embedBase` | Top-level function and constant — pure string building for public iframe embeds. Unauthenticated and unmetered |
| Models | `Article`, `ArticleList`, `Series`, `SeriesList`, `Profile`, `Plan`, `PlanUsage`, `Analytics`, `ArticleReactions`, `ReactionResult`, `Comment`, `CommentAuthor`, `CommentsResult`, `FollowStatus`, `TitlesResult`, `TitleSuggestion`, `AiText`, `ImageResult`, `TrialStatus` |
| Enums | `ArticleStatus` and `ArticleVisibility` document the accepted values; the methods themselves take plain `String`s (`status: 'published'`) |

Every model wraps the decoded JSON and exposes it as `.raw`, so a field the API
adds after this release is still reachable as `model.raw['new_field']`. Getters
are nullable because the API omits fields that do not apply.

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

---

## Examples

### Authenticate and publish

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

---

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

---

## Links

- Website — https://www.misar.blog
- App — https://www.misar.blog
- Parent — https://misar.io
- Documentation — https://docs.misar.io/blog
- Source — https://github.com/Misar-AI/misarblog-sdks
- pub.dev — https://pub.dev/packages/misarblog

MIT © [Misar AI](https://misar.io)
