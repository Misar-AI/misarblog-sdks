# Misar.Blog Swift SDK

Official Swift client for the Misar.Blog developer API. async/await, retry with back-off, iOS 15+ / macOS 12+.

## Install

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Misar-AI/misarblog-swift.git", from: "1.1.0")
]
```

> The standalone repository carries **no version tag yet**, so a `from:`
> requirement cannot resolve until the first release publishes one. Until
> then, depend on `branch: "main"`.

## Quick start

```swift
import MisarBlog

let blog = MisarBlogClient(apiKey: "mbk_...")

let me = try await blog.profile.get()
let thread = try await blog.comments.list(articleID: "article-id", limit: 50)

do {
    _ = try await blog.ai.complete(prompt: "Draft an intro paragraph")
} catch let MisarBlogError.planLimitExceeded(_, _, plan, upgradeURL, _) {
    print("\(plan ?? "current") plan is out of credits — upgrade at \(upgradeURL ?? "")")
}
```

## Authentication and plan gating

Every call goes through the metered gateway at `https://api.misar.io/blog/v1`
with your developer key as a Bearer token. Mint a key in the dashboard at
<https://www.misar.blog/dashboard/settings/api> — key management is a
cookie-session flow and is deliberately not exposed by this SDK.

Feature access and throughput follow the subscription attached to that key:

| Signal | Meaning |
| --- | --- |
| `401` | Missing, expired or revoked key |
| `403` | The key is scoped and lacks the scope this route needs |
| `429` (plain) | Rate limit — 100 requests/minute per key. The SDK retries with back-off |
| `429` + `plan_limit_exceeded` | A metered allowance is spent. Retrying will not help until it resets |
| `402` + `plan_limit_exceeded` | The feature is not on this plan |

The last two raise ``MisarBlogError.planLimitExceeded`` rather than a generic error, carrying the
plan slug, the pricing URL and (when the API supplies it) seconds until reset.
Show the upgrade URL instead of reporting a bare failure — the SDK does not
retry these, because retrying cannot change the outcome.

## Covered operations

All 25 key-authenticated operations:

| Group | Operations |
| --- | --- |
| Articles | list, get, create, update, create draft, search, recommendations |
| Series | list, create, add article |
| Reactions | get, add, remove |
| Comments | list |
| Follows | status |
| AI | complete, titles |
| Images | generate, upload |
| Account | profile, plan, trial status, start trial |
| Analytics | summary, upsell funnel |

The API exposes no SSE or WebSocket endpoint that accepts an API key, so this
SDK is request/response only. See [`openapi/blog.openapi.json`][spec] for the
machine-readable contract.

[spec]: https://api.misar.io/blog/v1/openapi.json

## Links

- API docs — <https://docs.misar.io/blog>
- OpenAPI spec — <https://api.misar.io/blog/v1/openapi.json>
- Dashboard — <https://www.misar.blog/dashboard/settings/api>

## License

MIT — see [LICENSE](LICENSE).
