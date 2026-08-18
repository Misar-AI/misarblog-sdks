# Changelog

All notable changes to this SDK are documented here. Versions follow
[semantic versioning](https://semver.org/).

## 5.0.1 — 2026-08-19

Republished so that every SDK, including the tag-versioned ones, ships through the same automated release pipeline. No API changes.

### Changed

- The module path gained its `/v5` suffix, which Go requires at v2 and above: `go get github.com/Misar-AI/misarblog-sdks/go/v5`.

## 5.0.0 — 2026-08-19

One version across every SDK in every Misar product, replacing the drift between separately-numbered clients.

### Changed

- The module path gained its `/v5` suffix, which Go requires at v2 and above: `go get github.com/Misar-AI/misarblog-sdks/go/v5`.

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

### Changed
- Module path is now `github.com/Misar-AI/misarblog-sdks/go/v5`, matching the
  repository that actually serves it. Release tags are `go/vX.Y.Z`.
- The response body is read once per attempt so the retry decision can inspect
  it, rather than being discarded before the error is parsed.

## 1.0.0

- Initial release: 23 developer-API operations, typed models, retry with
  exponential back-off.
