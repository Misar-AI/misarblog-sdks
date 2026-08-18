# Misar.Blog Go SDK

Official Go client for the Misar.Blog developer API. Context-aware, typed responses, retry with back-off.

## Install

```bash
go get github.com/Misar-AI/misarblog-sdks/go
```

## Quick start

```go
package main

import (
	"context"
	"errors"
	"fmt"

	misarblog "github.com/Misar-AI/misarblog-sdks/go"
)

func main() {
	blog := misarblog.New("mbk_...")
	ctx := context.Background()

	me, err := blog.Me.Get(ctx)
	if err != nil {
		panic(err)
	}

	thread, err := blog.Comments.List(ctx, "article-id", 50, 0)
	if err != nil {
		panic(err)
	}
	fmt.Println(me.Username, thread.TotalCount)

	if _, err := blog.AI.Complete(ctx, &misarblog.CompleteRequest{Prompt: "Draft an intro"}); err != nil {
		var limit *misarblog.PlanLimitError
		if errors.As(err, &limit) {
			fmt.Printf("%s plan is out of credits — upgrade at %s\n", limit.Plan, limit.UpgradeURL)
		}
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

The last two raise ``*PlanLimitError`` rather than a generic error, carrying the
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
