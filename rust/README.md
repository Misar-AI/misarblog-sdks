# Misar.Blog Rust SDK

Official Rust client for the Misar.Blog developer API. Async, typed models, retry with back-off.

## Install

```toml
[dependencies]
misarblog = "1.1"
tokio = { version = "1", features = ["full"] }
```

## Quick start

```rust
use misarblog::{BlogApiError, MisarBlog};

#[tokio::main]
async fn main() -> Result<(), BlogApiError> {
    let blog = MisarBlog::new("mbk_...");

    let me = blog.account.me().await?;
    let thread = blog.comments.list("article-id", Some(50), None).await?;
    println!("{} comments", thread.total_count);

    let req = misarblog::types::AiCompleteRequest {
        prompt: "Draft an intro".into(),
        ..Default::default()
    };
    match blog.ai.complete(&req).await {
        Err(BlogApiError::PlanLimit { plan, upgrade_url, .. }) => {
            println!("{plan:?} plan is out of credits — upgrade at {upgrade_url:?}");
        }
        other => { other?; }
    }

    let _ = me;
    Ok(())
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

The last two raise ``BlogApiError::PlanLimit`` rather than a generic error, carrying the
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
