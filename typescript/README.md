# Misar.Blog TypeScript SDK

Official TypeScript/JavaScript client for the Misar.Blog developer API. Fully typed, retry with back-off, works in Node and the browser.

## Install

```bash
npm install @misarblog/sdk
```

## Quick start

```ts
import { MisarBlog, PlanLimitError } from "@misarblog/sdk";

const blog = new MisarBlog({ apiKey: "mbk_..." });

const me = await blog.profiles.me();
const article = await blog.articles.create({ title: "Hello", body_markdown: "# Hi" });
const thread = await blog.comments.list(article.id, { limit: 50 });
const follows = await blog.follows.status(me.id);

try {
  await blog.ai.complete({ prompt: "Draft an intro paragraph" });
} catch (err) {
  if (err instanceof PlanLimitError) {
    console.log(`${err.plan} plan is out of credits — upgrade at ${err.upgradeUrl}`);
  }
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

The last two raise ``PlanLimitError`` rather than a generic error, carrying the
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
