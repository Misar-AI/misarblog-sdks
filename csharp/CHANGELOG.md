# Changelog

All notable changes to this SDK are documented here. Versions follow
[semantic versioning](https://semver.org/).

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

### Removed
- The `auth` token-refresh helper. It posted to `misar.blog/api/auth/refresh`,
  a route that no longer exists, and did not use API-key authentication.

## 1.0.0

- Initial release: 23 developer-API operations, typed models, retry with
  exponential back-off.
