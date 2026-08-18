# Misar.Blog PHP SDK

[Misar.Blog](https://misar.blog) is a hosted blogging platform. Authors write in
Markdown, publish or schedule articles, group them into series, and get
comments, reactions, follows, subscriber- and paid-gated posts, AI writing
helpers and per-account analytics. This package is the official PHP client for
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

- `MisarBlog\Client` — the client:
  `new Client($apiKey, $baseUrl = null, $timeout = 30)`.
- Readonly resource properties on the client: `$articles`, `$series`,
  `$reactions`, `$comments`, `$follows`, `$ai`, `$images`, `$profile`,
  `$analytics`, `$plan`, `$trial`, `$upsell`, `$search`, `$recommendations`.
  Search and recommendations are their own resources here, not methods on
  `$articles`.
- Exceptions: `MisarBlog\ApiError` (extends `RuntimeException`),
  `MisarBlog\PlanLimitError` and `MisarBlog\NetworkError`, both of which extend
  `ApiError`.
- `MisarBlog\Embed::url($username, $slug, $theme)` — static, pure string
  building for public embeds.
- `MisarBlog\Article` and `MisarBlog\Series` — readonly value objects with a
  `::from(array $json)` factory, for when you want a typed view of a response.
- `$client->request($method, $path, $data)` is public, so an endpoint this SDK
  does not wrap yet is still one call away.

**Responses are associative arrays.** Every resource method returns the decoded
JSON as `array<string,mixed>`; a `204` or empty body returns `[]`. Request
bodies are arrays too.

**Transport.** ext-curl directly — no Guzzle, no PSR-18. Base URL
`https://api.misar.io/blog/v1`; the key goes on `Authorization: Bearer`.
Statuses 429/500/502/503/504 and cURL failures are retried up to 3 attempts with
exponential back-off from 500 ms; the final attempt is always surfaced. The
retry count is a class constant, not a constructor argument — only `$timeout`
(default 30 s, connect timeout fixed at 10 s) is tunable.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

## Install

```bash
composer require misarai/misarblog-php
```

Or pin it in `composer.json`:

```json
{
  "require": {
    "misarai/misarblog-php": "^1.1"
  }
}
```

PHP 8.1+ with `ext-curl` and `ext-json`.

## Quick start

```php
<?php

require __DIR__ . '/vendor/autoload.php';

use MisarBlog\Client;

$blog = new Client(getenv('MISARBLOG_API_KEY'));

$me = $blog->profile->get();
echo "authenticated as @{$me['username']}\n";

$article = $blog->articles->publish([
    'title'         => 'Shipping a blog from CI',
    'body_markdown' => "# Shipping a blog from CI\n\nMarkdown in, article out.",
    'tags'          => ['ci', 'automation'],
]);
echo $article['url'], "\n";
```

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
itself is a cookie-session flow and is deliberately not exposed here.

## Primary functions

### Publish (or schedule) an article

```php
$article = $blog->articles->publish([
    'title'           => 'Hello, Misar',
    'body_markdown'   => "# Hello\n\nFirst post.",
    'tags'            => ['intro'],
    'cover_image_url' => 'https://cdn.example.com/cover.png',
    'visibility'      => 'public',                // public | subscribers | paid | private | webhook_only
    'schedule_at'     => '2026-09-01T09:00:00Z',  // omit to publish immediately
]);

echo $article['slug'], ' ', $article['status'], ' ', $article['url'], "\n";
```

Only `title` and `body_markdown` are required.

### Save a draft

```php
$draft = $blog->articles->createDraft([
    'title'         => 'Work in progress',
    'body_markdown' => 'Notes so far…',
    'tags'          => ['draft'],
]);
echo $draft['editor_url'], "\n"; // open in the Misar.Blog editor
```

### List your articles

```php
$result = $blog->articles->list(['status' => 'published', 'limit' => 20]);

foreach ($result['articles'] as $a) {
    echo $a['slug'], ' ', $a['view_count'], "\n";
}
echo count($result['articles']), ' of ', $result['total'], "\n";
```

`status` accepts `draft`, `published`, `scheduled`, `archived`, `flagged` or
`all`; `visibility`, `webhook_only` and `sort` narrow it further. For a typed
view of one row:

```php
use MisarBlog\Article;

$typed = Article::from($result['articles'][0]);
echo $typed->slug, ' ', $typed->title, "\n";
```

### Update an article — and publish a draft

```php
$updated = $blog->articles->update('work-in-progress', [
    'title'         => 'Finished at last',
    'body_markdown' => 'The complete post.',
    'publish'       => true, // flips a draft to published in the same call
]);
echo $updated['status'], ' ', $updated['published_at'], "\n";
```

Omitted fields are left unchanged.

### Read an article's comment thread

```php
$thread = $blog->comments->list($article['id'], limit: 50, offset: 0);

foreach ($thread['comments'] as $c) {
    echo "@{$c['user']['username']}: {$c['content']} ({$c['reply_count']} replies)\n";
}
echo $thread['totalCount'], ' ', var_export($thread['hasMore'], true), "\n";
```

Leave `limit` and `offset` out to take the server defaults of 20 (max 100) and 0.

### Read and add reactions

```php
$counts = $blog->reactions->get($article['id']);
echo $counts['counts']['clap'], ' ', $counts['total'], "\n";

$blog->reactions->add($article['id'], 'clap');    // like | clap | bookmark
$blog->reactions->remove($article['id'], 'clap');
```

### Generate SEO titles

```php
$result = $blog->ai->titles(
    'seo', // 'seo' from a keyword, 'suggest' from existing copy
    prompt: 'shipping a static blog from GitHub Actions',
);

foreach ($result['titles'] as $t) {
    echo $t['title'], ' — ', $t['hint'], "\n";
}
```

For `'suggest'`, pass the article text as `context:` instead of `prompt:`.

### Read the analytics summary

```php
$summary = $blog->analytics->get(30); // trailing days
echo $summary['views'], ' ',
     $summary['revenue_cents'], ' ',
     $summary['active_subscribers'], "\n";
```

### Generate a cover image

```php
$image = $blog->images->generate(
    'a dark editorial illustration of a printing press',
    '1792x1024',
);
echo $image['url'], "\n";
```

`$blog->images->upload($data)` posts to the CDN upload route as JSON — pass the
body the API expects (a base64 `data` field). This SDK does not build a
multipart request for you; the Go and Python clients do.

### Embed a public article

```php
use MisarBlog\Embed;

echo Embed::url('gulshan', 'hello-misar', 'dark'), "\n";
// https://misar.blog/gulshan/hello-misar/embed?theme=dark
```

Pass `null` for `$slug` to embed the whole profile; `'auto'` adds no query
parameter.

## Errors

Every failure throws. `PlanLimitError` and `NetworkError` both extend `ApiError`,
which extends `RuntimeException` — so `catch (ApiError $e)` catches everything
from this SDK, and `catch (\RuntimeException $e)` catches it alongside your own.
Order narrowest-first.

| Type | Thrown when | Readonly properties |
| --- | --- | --- |
| `ApiError` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `$status`, and on 403 `$requiredScope` / `$grantedScopes` |
| `PlanLimitError` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `$plan`, `$upgradeUrl`, `$retryAfter`, `$upgrade` |
| `NetworkError` | The request never reached the API — DNS, TLS, connection, timeout — or the retry budget was exhausted. The cURL errno and message are in the exception message | `$status` is `0` |

```php
use MisarBlog\ApiError;
use MisarBlog\NetworkError;
use MisarBlog\PlanLimitError;

try {
    $blog->ai->complete('Draft an intro paragraph');
} catch (PlanLimitError $e) {
    // Route the reader to checkout instead of reporting a bare failure.
    echo "{$e->plan} plan is out of credits — upgrade at {$e->upgradeUrl}\n";
} catch (NetworkError $e) {
    echo 'could not reach the API: ', $e->getMessage(), "\n";
} catch (ApiError $e) {
    echo $e->status, ' ', $e->getMessage(), ' ', $e->requiredScope, "\n";
}
```

## Links

- Misar.Blog — <https://misar.blog>
- API docs — <https://docs.misar.io/blog>
- OpenAPI spec — <https://api.misar.io/blog/v1/openapi.json>
- Mint an API key — <https://www.misar.blog/dashboard/settings/api>

## License

MIT — see [LICENSE](LICENSE).
