# Changelog

All notable changes to this SDK are documented here. Versions follow
[semantic versioning](https://semver.org/).

## 5.0.1 — 2026-08-19

Republished so that every SDK, including the tag-versioned ones, ships through the same automated release pipeline. No API changes.

## 5.0.0 — 2026-08-19

One version across every SDK in every Misar product, replacing the drift between separately-numbered clients.

### Documentation

- Rewritten README: every resource and method is listed with the endpoint it calls, the examples are verified against the API contract, and package links are consistent across all SDKs.
- Manifest metadata filled in — homepage, repository, issue tracker, documentation and author.

## 1.1.0 — 2026-08-16

### Added
- `comments.list(...)` — `GET /comments`, an article's thread with replies
  nested one level deep.
- `follows.status(...)` — `GET /follows`, follower/following counts plus
  whether the key's owner follows the profile.
- A dedicated plan-limit error type carrying the plan slug, the pricing URL and
  seconds until the allowance resets. The API answers a spent allowance with
  429 and a locked feature with 402, both tagged `plan_limit_exceeded`.

### Changed
- Plan refusals no longer consume the retry budget. A `plan_limit_exceeded`
  response is surfaced immediately instead of being retried three times with
  back-off — retrying cannot help until the allowance resets or the plan
  changes. Plain rate-limit 429s still retry as before.
- The SDK now covers all 25 key-authenticated operations.

### Fixed
- `series.get(slug)` issued a `GET` against a `POST`-only route and always
  returned 405. Replaced by `series.addArticle(slug, articleSlug, position?)`.
- `FollowStatus` described a shape the API never returns. It is now
  `{ isFollowing, followerCount, followingCount }`.
- `Comment` was missing `is_edited`, `is_hidden`, `reply_count`, `user` and
  `replies`.
- `comments` and `follows` were documented as needing no API key. Both are
  key-authenticated and metered like every other operation.

### Added
- `articles.update(...)`, `ai.complete(...)`, `images.generate/upload(...)`,
  `plan.get/trialStatus/startTrial(...)` and `upsell.funnel(...)` — nine
  operations the SDK previously lacked.
- Retry with exponential back-off, a request timeout, and `NetworkError`.

### Removed
- The `newsletter` resource. It targeted session + CSRF browser routes that are
  not served by the API gateway, so it could not succeed with an API key.
- The `apiKeys` resource, which threw on every call by design. Key management is
  a dashboard flow: https://www.misar.blog/dashboard/settings/api
- The `auth` token-refresh helper, which posted to a route that no longer exists.

## 1.0.0

- Initial release: 23 developer-API operations, typed models, retry with
  exponential back-off.
