# Changelog

All notable changes to this SDK are documented here. Versions follow
[semantic versioning](https://semver.org/).

## 5.0.3 — 2026-08-19

Republished so that every SDK, including the tag-versioned ones, ships through the same automated release pipeline. No API changes.

## 5.0.2 — 2026-08-19

Republished so that every SDK, including the tag-versioned ones, ships through the same automated release pipeline. No API changes.

## 5.0.1 — 2026-08-19

Republished so that every SDK, including the tag-versioned ones, ships through the same automated release pipeline. No API changes.

## 5.0.0 — 2026-08-19

One version across every SDK in every Misar product, replacing the drift between separately-numbered clients.

### Documentation

- Rewritten README: every resource and method is listed with the endpoint it calls, the examples are verified against the API contract, and package links are consistent across all SDKs.
- Manifest metadata filled in — homepage, repository, issue tracker, documentation and author.

### Fixed

- An error response with an empty body was reported as success. A bare 401, or any response stripped by a proxy, came back as an empty result instead of raising, so callers could not tell "no results" from "not authorised".

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
- The package declared PSR-4 autoloading but packed twenty classes into three
  files, so `MisarBlog\\ApiError` and the resource classes could never be
  autoloaded — every error path would have fatalled after a fresh install.
  Each class now lives in its own correctly-named file.

### Removed
- The `auth` token-refresh helper. It posted to `misar.blog/api/auth/refresh`,
  a route that no longer exists, and did not use API-key authentication.

## 1.0.0

- Initial release: 23 developer-API operations, typed models, retry with
  exponential back-off.
