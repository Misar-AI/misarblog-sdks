# Misar.Blog Go SDK

> The official Go client for the Misar.Blog developer API.

[![Go Reference](https://pkg.go.dev/badge/github.com/Misar-AI/misarblog-sdks/go/v5.svg)](https://pkg.go.dev/github.com/Misar-AI/misarblog-sdks/go/v5) [![Go](https://img.shields.io/badge/go-%3E%3D1.22-00ADD8)](https://go.dev) [![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**12 resource groups · 25 operations · context-aware, no third-party dependencies**

Works with any Go 1.22+ program that needs to drive a [Misar.Blog](https://www.misar.blog)
account: automating publishing, syncing a blog out of CI or another CMS, or
building a reader, dashboard or integration on top of the API at
`https://api.misar.io/blog/v1`.

---

## Install

```bash
go get github.com/Misar-AI/misarblog-sdks/go/v5
```

The module lives in the `go/` subdirectory of the SDK repository, so its release
tags are `go/vX.Y.Z` and the import path carries the `/go` suffix:

```go
import misarblog "github.com/Misar-AI/misarblog-sdks/go/v5"
```

---

## Authentication

Mint a key at <https://www.misar.blog/dashboard/settings/api>. Keys are prefixed
`mbk_`; an OAuth 2.1 access token works on the same header. Key management
itself is a cookie-session flow and is deliberately not exposed here.

Pass the key to `misarblog.New`; it is sent as `Authorization: Bearer`. See the
first example below. The full request/response contract
is published as an OpenAPI document at
<https://api.misar.io/blog/v1/openapi.json>.

---

## API surface

Every method takes a `context.Context` first.

| Resource | Method | Endpoint | What it does |
| --- | --- | --- | --- |
| `Articles` | `List` | `GET /articles` | list your articles, filtered by status/visibility/sort |
| `Articles` | `Get` | `GET /articles/{slug}` | fetch one article by slug or UUID, full Markdown body |
| `Articles` | `Publish` | `POST /articles` | publish or schedule an article from Markdown |
| `Articles` | `Update` | `PATCH /articles/{slug}` | update title/body/tags in place; `publish: true` flips a draft live |
| `Articles` | `CreateDraft` | `POST /drafts` | save a draft without publishing |
| `Articles` | `Search` | `GET /search` | full-text search across articles, profiles and tags |
| `Articles` | `Recommendations` | `GET /recommendations` | related articles for an article id |
| `Series` | `List` | `GET /series` | list your series |
| `Series` | `Create` | `POST /series` | create a series |
| `Series` | `AddArticle` | `POST /series/{slug}/articles` | add an article to a series at a position |
| `Reactions` | `Get` | `GET /reactions` | reaction counts and the caller's own reactions |
| `Reactions` | `Add` | `POST /reactions` | add a `like` / `clap` / `bookmark` |
| `Reactions` | `Remove` | `DELETE /reactions` | remove a reaction |
| `Comments` | `List` | `GET /comments` | an article's comment thread, newest first, replies one level deep |
| `Follows` | `Status` | `GET /follows` | follower/following counts and whether the key's owner follows |
| `AI` | `Complete` | `POST /ai/complete` | free-form system + user completion |
| `AI` | `Titles` | `POST /ai/titles` | SEO/AEO/GEO title suggestions (`seo` from a keyword, `suggest` from copy) |
| `Images` | `Generate` | `POST /images/generate` | AI cover image (`1024x1024`, `1792x1024`, `1024x1792`) |
| `Images` | `Upload` | `POST /images/upload` | upload an image to the CDN |
| `Me` | `Get` | `GET /me` | the authenticated creator profile |
| `Analytics` | `Summary` | `GET /analytics` | views, gross/net revenue, active subscribers for trailing N days |
| `Plan` | `Get` | `GET /plan` | live plan and per-feature quota |
| `Trial` | `Status` | `GET /trial` | whether a self-serve trial is active |
| `Trial` | `Start` | `POST /trial` | start a self-serve trial |
| `UpsellFunnel` | `Get` | `GET /upsell-funnel` | per-feature upsell funnel (platform-admin keys only; a creator key gets 403) |

---

## What's in the package

| Item | What it is |
| --- | --- |
| `Client` | The client, constructed with `misarblog.New(apiKey, opts...)`. Resource fields: `Articles`, `Series`, `Reactions`, `Comments`, `Follows`, `AI`, `Images`, `Me`, `Analytics`, `Plan`, `Trial`, `UpsellFunnel`. |
| Options | `WithBaseURL`, `WithMaxRetries`, `WithTimeout`, `WithHTTPClient` (inject your own `*http.Client`, as the test suite does). |
| Errors | `*APIError`, `*PlanLimitError`, `*NetworkError` — match with `errors.As`. |
| Models | Typed request and response structs for every operation — `Article`, `ArticleSummary`, `PublishArticleRequest`, `UpdateArticleRequest`, `Comment`, `Series`, `Profile`, `AnalyticsSummary`, `Plan`, `TrialStatus`, `ArticleReactions`, `TitlesResponse` and the rest. |
| `EmbedURL(username, slug, theme)` | Pure string building for public embeds; pass an empty `slug` for the profile embed and `""` or `"auto"` for the default theme. |
| `RefreshToken(token, baseURL)` | A legacy helper for the web app's session token endpoint, not the developer API. Irrelevant if you authenticate with an `mbk_` key. |

**Transport.** Standard library `net/http`, no third-party dependencies. Base
URL `https://api.misar.io/blog/v1`; the key goes on `Authorization: Bearer`.
Statuses 429/500/502/503/504 and transport failures are retried up to
`WithMaxRetries` attempts (default 3) with exponential back-off from 200 ms; the
final attempt is always returned. Per-request timeout defaults to 30 s and is
also bounded by the `context.Context` you pass. A `204` decodes to the zero
value.

**No streaming or webhooks.** Every operation is a single request/response. No
SSE or WebSocket endpoint accepts an API key, and the API has no webhook
registration route — `webhook_only` is an article *visibility* value, not a
subscription.

---

## Examples

### Authenticate and publish

```go
package main

import (
	"context"
	"fmt"
	"os"

	misarblog "github.com/Misar-AI/misarblog-sdks/go/v5"
)

func main() {
	blog := misarblog.New(os.Getenv("MISARBLOG_API_KEY"))
	ctx := context.Background()

	me, err := blog.Me.Get(ctx)
	if err != nil {
		panic(err)
	}
	fmt.Printf("authenticated as @%s\n", me.Username)

	article, err := blog.Articles.Publish(ctx, &misarblog.PublishArticleRequest{
		Title:        "Shipping a blog from CI",
		BodyMarkdown: "# Shipping a blog from CI\n\nMarkdown in, article out.",
		Tags:         []string{"ci", "automation"},
	})
	if err != nil {
		panic(err)
	}
	fmt.Println(article.URL)
}
```

### Publish (or schedule) an article

```go
article, err := blog.Articles.Publish(ctx, &misarblog.PublishArticleRequest{
	Title:         "Hello, Misar",
	BodyMarkdown:  "# Hello\n\nFirst post.",
	Tags:          []string{"intro"},
	CoverImageURL: "https://cdn.example.com/cover.png",
	Visibility:    "public",                // public | subscribers | paid | private | webhook_only
	ScheduleAt:    "2026-09-01T09:00:00Z",  // omit to publish immediately
})
fmt.Println(article.Slug, article.Status, article.URL)
```

### Save a draft

```go
draft, err := blog.Articles.CreateDraft(ctx, &misarblog.CreateDraftRequest{
	Title:        "Work in progress",
	BodyMarkdown: "Notes so far…",
	Tags:         []string{"draft"},
})
fmt.Println(draft.EditorURL) // open in the Misar.Blog editor
```

### List your articles

```go
result, err := blog.Articles.List(ctx, &misarblog.ListArticlesParams{
	Status: "published", // draft | published | scheduled | archived | flagged | all
	Limit:  20,
})
for _, a := range result.Articles {
	fmt.Println(a.Slug, a.ViewCount)
}
fmt.Printf("%d of %d\n", len(result.Articles), result.Total)
```

`Visibility`, `WebhookOnly` and `Sort` narrow the list further; pass `nil` for
no filters at all.

### Update an article — and publish a draft

```go
title := "Finished at last"
body := "The complete post."
publish := true

updated, err := blog.Articles.Update(ctx, "work-in-progress", &misarblog.UpdateArticleRequest{
	Title:        &title,
	BodyMarkdown: &body,
	Publish:      &publish, // flips a draft to published in the same call
})
fmt.Println(updated.Status, updated.PublishedAt)
```

The update fields are pointers so an omitted field stays unchanged rather than
being cleared to its zero value.

### Read an article's comment thread

```go
thread, err := blog.Comments.List(ctx, article.ID, 50, 0) // articleID, limit, offset
for _, c := range thread.Comments {
	fmt.Printf("@%s: %s (%d replies)\n", c.User.Username, c.Content, c.ReplyCount)
}
fmt.Println(thread.TotalCount, thread.HasMore)
```

Pass `0` for `limit`/`offset` to take the API defaults (20 and 0; limit maxes at
100).

### Read and add reactions

```go
counts, err := blog.Reactions.Get(ctx, article.ID)
fmt.Println(counts.Counts.Clap, counts.Total, counts.UserReactions)

_, err = blog.Reactions.Add(ctx, article.ID, "clap") // like | clap | bookmark
_, err = blog.Reactions.Remove(ctx, article.ID, "clap")
```

### Generate SEO titles

```go
titles, err := blog.AI.Titles(ctx, &misarblog.TitlesRequest{
	Action: "seo", // "seo" from a keyword, "suggest" from existing copy
	Prompt: "shipping a static blog from GitHub Actions",
})
for _, t := range titles.Titles {
	fmt.Println(t.Title, "—", t.Hint)
}
```

For `"suggest"`, put the article text in `Context` instead of `Prompt`.

### Read the analytics summary

```go
summary, err := blog.Analytics.Summary(ctx, 30) // trailing days
fmt.Println(summary.Views, summary.RevenueCents, summary.ActiveSubscribers)
```

### Generate or upload a cover image

```go
image, err := blog.Images.Generate(ctx, &misarblog.GenerateImageRequest{
	Prompt: "a dark editorial illustration of a printing press",
	Size:   "1792x1024",
})
fmt.Println(image.URL)

data, err := os.ReadFile("cover.png")
uploaded, err := blog.Images.Upload(ctx, "cover.png", data) // multipart, "file" field
fmt.Println(uploaded["url"])
```

### Embed a public article

```go
url := misarblog.EmbedURL("gulshan", "hello-misar", "dark")
// https://misar.blog/gulshan/hello-misar/embed?theme=dark
```

---

## Errors

Every failure returns a non-nil error. All three types are pointer types —
match them with `errors.As`.

| Type | Returned when | Fields |
| --- | --- | --- |
| `*APIError` | Any non-2xx the SDK did not classify further — `400` bad payload, `401` missing/expired/revoked key, `403` the key lacks the route's scope, `404` unknown slug, plain `429` rate limit (100 req/min per key) after retries are exhausted, `5xx` after retries | `Status`, `Message`, and on 403 `RequiredScope` / `GrantedScopes` |
| `*PlanLimitError` | The subscription blocks the call: `429` + `code: "plan_limit_exceeded"` (a metered allowance is spent) or `402` (the feature is not on this plan). **Never retried** — retrying cannot help until the allowance resets or the plan changes | `Status`, `Message`, `Plan`, `UpgradeURL`, `RetryAfter`, `Upgrade` |
| `*NetworkError` | The request never reached the API — DNS, TLS, connection, timeout, cancelled context — or the retry budget was exhausted | `Message`, `Cause` (reachable with `errors.Unwrap`) |

```go
_, err := blog.AI.Complete(ctx, &misarblog.CompleteRequest{Prompt: "Draft an intro paragraph"})
if err != nil {
	var limit *misarblog.PlanLimitError
	var apiErr *misarblog.APIError
	var netErr *misarblog.NetworkError

	switch {
	case errors.As(err, &limit):
		// Route the reader to checkout instead of reporting a bare failure.
		fmt.Printf("%s plan is out of credits — upgrade at %s\n", limit.Plan, limit.UpgradeURL)
	case errors.As(err, &netErr):
		fmt.Println("could not reach the API:", netErr.Cause)
	case errors.As(err, &apiErr):
		fmt.Println(apiErr.Status, apiErr.Message, apiErr.RequiredScope)
	}
}
```

The three are independent types — `*PlanLimitError` does not wrap `*APIError` —
so check for the one you care about rather than relying on an ordering.

---

## Links

- Website — https://www.misar.blog
- App — https://www.misar.blog
- Parent — https://misar.io
- Documentation — https://docs.misar.io/blog
- Source — https://github.com/Misar-AI/misarblog-sdks
- pkg.go.dev — https://pkg.go.dev/github.com/Misar-AI/misarblog-sdks/go/v5

MIT © [Misar AI](https://misar.io)
