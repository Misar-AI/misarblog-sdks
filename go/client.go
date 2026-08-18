// Package misarblog is the Go client for Misar.Blog (https://www.misar.blog), a
// hosted blogging platform: publish and schedule Markdown articles, manage
// drafts and series, read comments, reactions, follows and per-account
// analytics, generate SEO titles, completions and AI cover images, and search
// articles, profiles and tags.
//
// Base URL is https://api.misar.io/blog/v1 — the blog gateway strips /api, so
// request paths never carry an /api prefix. Authenticate with a developer key
// (mbk_...) or an OAuth 2.1 access token, sent as a Bearer token. Mint a key at
// https://www.misar.blog/dashboard/settings/api; key management itself is a
// cookie-session flow and is deliberately not exposed here.
//
// The 25 key-authenticated operations are grouped into resources hanging off
// [Client]: Articles, Series, Reactions, Comments, Follows, AI, Images, Me,
// Analytics, Plan, Trial and UpsellFunnel. Every method takes a
// [context.Context] and returns a typed struct plus an error.
//
//	blog := misarblog.New("mbk_...")
//	me, err := blog.Me.Get(context.Background())
//	article, err := blog.Articles.Publish(context.Background(), &misarblog.PublishArticleRequest{
//		Title:        "Hello, Misar",
//		BodyMarkdown: "# Hello\n\nFirst post.",
//	})
//
// Failures come back as [*APIError] for any non-2xx, [*PlanLimitError] when the
// subscription attached to the key blocks the call (it carries the plan slug and
// upgrade URL, and is never retried) or [*NetworkError] when the request never
// reached the API. Statuses 429/500/502/503/504 and transport failures are
// retried up to three attempts with exponential back-off from 200ms; tune the
// client with [WithMaxRetries], [WithTimeout], [WithBaseURL] and
// [WithHTTPClient].
//
// Every operation is a single request/response — the API exposes no SSE or
// WebSocket endpoint that accepts an API key, and no webhook registration route.
//
// [EmbedURL] builds the public iframe URL for a profile or a single article; it
// needs no key and is unmetered.
//
// Homepage https://www.misar.blog. Documentation https://docs.misar.io/blog.
// Source https://github.com/Misar-AI/misarblog-sdks — the mirror keeps each
// language in a subdirectory, so this module lives at the /go suffix and its
// release tags are go/vX.Y.Z. Issues
// https://github.com/Misar-AI/misarblog-sdks/issues. MIT licensed by Misar AI
// (https://misar.io).
package misarblog

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

const (
	defaultBaseURL    = "https://api.misar.io/blog/v1"
	defaultMaxRetries = 3
	defaultTimeout    = 30 * time.Second
	retryBaseMS       = 200 * time.Millisecond
)

var retryable = map[int]bool{429: true, 500: true, 502: true, 503: true, 504: true}

// ── Options ───────────────────────────────────────────────────────────────────

type Option func(*Client)

// WithBaseURL overrides the API base (default https://api.misar.io/blog/v1).
func WithBaseURL(u string) Option {
	return func(c *Client) { c.baseURL = strings.TrimRight(u, "/") }
}

// WithMaxRetries sets the total number of attempts for 429/5xx and transport errors.
func WithMaxRetries(n int) Option {
	return func(c *Client) {
		if n < 1 {
			n = 1
		}
		c.maxRetries = n
	}
}

// WithTimeout sets the per-request timeout.
func WithTimeout(d time.Duration) Option {
	return func(c *Client) { c.httpClient = &http.Client{Timeout: d} }
}

// WithHTTPClient injects a custom *http.Client (used by tests).
func WithHTTPClient(h *http.Client) Option { return func(c *Client) { c.httpClient = h } }

// ── Client ────────────────────────────────────────────────────────────────────

type Client struct {
	apiKey     string
	baseURL    string
	maxRetries int
	httpClient *http.Client

	Articles     *ArticlesResource
	AI           *AIResource
	Images       *ImagesResource
	Analytics    *AnalyticsResource
	Me           *MeResource
	Plan         *PlanResource
	Reactions    *ReactionsResource
	Series       *SeriesResource
	Comments     *CommentsResource
	Follows      *FollowsResource
	Trial        *TrialResource
	UpsellFunnel *UpsellFunnelResource
}

// New creates a Misar.Blog API client.
func New(apiKey string, opts ...Option) *Client {
	c := &Client{
		apiKey:     apiKey,
		baseURL:    defaultBaseURL,
		maxRetries: defaultMaxRetries,
		httpClient: &http.Client{Timeout: defaultTimeout},
	}
	for _, o := range opts {
		o(c)
	}
	c.Articles = &ArticlesResource{c}
	c.AI = &AIResource{c}
	c.Images = &ImagesResource{c}
	c.Analytics = &AnalyticsResource{c}
	c.Me = &MeResource{c}
	c.Plan = &PlanResource{c}
	c.Reactions = &ReactionsResource{c}
	c.Series = &SeriesResource{c}
	c.Comments = &CommentsResource{c}
	c.Follows = &FollowsResource{c}
	c.Trial = &TrialResource{c}
	c.UpsellFunnel = &UpsellFunnelResource{c}
	return c
}

// ── Core HTTP ─────────────────────────────────────────────────────────────────

func (c *Client) do(ctx context.Context, method, path string, body, out any) error {
	var lastErr error
	for attempt := 0; attempt < c.maxRetries; attempt++ {
		var bodyReader io.Reader
		if body != nil {
			b, err := json.Marshal(body)
			if err != nil {
				return err
			}
			bodyReader = bytes.NewReader(b)
		}
		req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, bodyReader)
		if err != nil {
			return err
		}
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
		req.Header.Set("Accept", "application/json")
		if body != nil {
			req.Header.Set("Content-Type", "application/json")
		}

		resp, err := c.httpClient.Do(req)
		if err != nil {
			lastErr = &NetworkError{Message: err.Error(), Cause: err}
			if attempt < c.maxRetries-1 {
				time.Sleep(retryBaseMS * (1 << attempt))
				continue
			}
			return lastErr
		}

		// Read the body once: deciding whether to retry needs to see whether a
		// 429 is a rate limit or a plan-limit refusal, and the body cannot be
		// read twice.
		raw, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		if retryable[resp.StatusCode] && attempt < c.maxRetries-1 && !isPlanLimit(raw) {
			time.Sleep(retryBaseMS * (1 << attempt))
			continue
		}

		return decodeResponse(resp, raw, out)
	}
	if lastErr != nil {
		return lastErr
	}
	return &NetworkError{Message: "max retries exceeded"}
}

// isPlanLimit reports whether an error body carries the API's plan-limit code.
func isPlanLimit(raw []byte) bool {
	if len(raw) == 0 {
		return false
	}
	var probe struct {
		Code string `json:"code"`
	}
	return json.Unmarshal(raw, &probe) == nil && probe.Code == "plan_limit_exceeded"
}

func planLimitFrom(resp *http.Response, raw []byte) *PlanLimitError {
	var body struct {
		Error   string         `json:"error"`
		Upgrade map[string]any `json:"upgrade"`
	}
	_ = json.Unmarshal(raw, &body)

	e := &PlanLimitError{
		Status:     resp.StatusCode,
		Message:    body.Error,
		Plan:       resp.Header.Get("X-Misar-Plan"),
		UpgradeURL: resp.Header.Get("X-Misar-Upgrade-Url"),
		Upgrade:    body.Upgrade,
	}
	if e.Message == "" {
		e.Message = resp.Status
	}
	// Headers are authoritative, but fall back to the offer body when a proxy
	// has stripped them.
	if e.UpgradeURL == "" {
		if urls, ok := body.Upgrade["urls"].(map[string]any); ok {
			if p, ok := urls["pricing"].(string); ok {
				e.UpgradeURL = p
			}
		}
	}
	if ra := resp.Header.Get("Retry-After"); ra != "" {
		if n, err := strconv.Atoi(ra); err == nil {
			e.RetryAfter = n
		}
	}
	return e
}

func decodeResponse(resp *http.Response, raw []byte, out any) error {
	if resp.StatusCode == http.StatusNoContent {
		return nil
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		if isPlanLimit(raw) {
			return planLimitFrom(resp, raw)
		}
		apiErr := &APIError{Status: resp.StatusCode}
		if len(raw) > 0 {
			_ = json.Unmarshal(raw, apiErr)
		}
		if apiErr.Message == "" {
			apiErr.Message = resp.Status
		}
		return apiErr
	}
	if out != nil && len(raw) > 0 {
		if err := json.Unmarshal(raw, out); err != nil {
			return fmt.Errorf("misarblog: decode: %w", err)
		}
	}
	return nil
}

// doMultipart posts a raw pre-built multipart body (used for image uploads).
func (c *Client) doMultipart(ctx context.Context, path, contentType string, payload []byte, out any) error {
	var lastErr error
	for attempt := 0; attempt < c.maxRetries; attempt++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+path, bytes.NewReader(payload))
		if err != nil {
			return err
		}
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
		req.Header.Set("Accept", "application/json")
		req.Header.Set("Content-Type", contentType)

		resp, err := c.httpClient.Do(req)
		if err != nil {
			lastErr = &NetworkError{Message: err.Error(), Cause: err}
			if attempt < c.maxRetries-1 {
				time.Sleep(retryBaseMS * (1 << attempt))
				continue
			}
			return lastErr
		}
		raw, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		if retryable[resp.StatusCode] && attempt < c.maxRetries-1 && !isPlanLimit(raw) {
			time.Sleep(retryBaseMS * (1 << attempt))
			continue
		}
		return decodeResponse(resp, raw, out)
	}
	if lastErr != nil {
		return lastErr
	}
	return &NetworkError{Message: "max retries exceeded"}
}

// ── Articles ──────────────────────────────────────────────────────────────────

type ArticlesResource struct{ c *Client }

func (r *ArticlesResource) List(ctx context.Context, p *ListArticlesParams) (*ArticleListResult, error) {
	q := url.Values{}
	if p != nil {
		if p.Status != "" && p.Status != "all" {
			q.Set("status", p.Status)
		}
		if p.Visibility != "" {
			q.Set("visibility", p.Visibility)
		}
		if p.WebhookOnly != nil {
			q.Set("webhook_only", strconv.FormatBool(*p.WebhookOnly))
		}
		if p.Sort != "" {
			q.Set("sort", p.Sort)
		}
		if p.Limit > 0 {
			q.Set("limit", strconv.Itoa(p.Limit))
		}
	}
	var out ArticleListResult
	return &out, r.c.do(ctx, http.MethodGet, "/articles"+encodeQuery(q), nil, &out)
}

func (r *ArticlesResource) Get(ctx context.Context, slug string) (*Article, error) {
	var out Article
	return &out, r.c.do(ctx, http.MethodGet, "/articles/"+url.PathEscape(slug), nil, &out)
}

func (r *ArticlesResource) Publish(ctx context.Context, req *PublishArticleRequest) (*MutateArticleResult, error) {
	var out MutateArticleResult
	return &out, r.c.do(ctx, http.MethodPost, "/articles", req, &out)
}

func (r *ArticlesResource) Update(ctx context.Context, slug string, req *UpdateArticleRequest) (*MutateArticleResult, error) {
	var out MutateArticleResult
	return &out, r.c.do(ctx, http.MethodPatch, "/articles/"+url.PathEscape(slug), req, &out)
}

func (r *ArticlesResource) CreateDraft(ctx context.Context, req *CreateDraftRequest) (*MutateArticleResult, error) {
	var out MutateArticleResult
	return &out, r.c.do(ctx, http.MethodPost, "/drafts", req, &out)
}

func (r *ArticlesResource) Search(ctx context.Context, p *SearchParams) (*SearchResult, error) {
	q := url.Values{}
	if p != nil {
		set(q, "q", p.Q)
		set(q, "type", p.Type)
		set(q, "tag", p.Tag)
		set(q, "author", p.Author)
		set(q, "sort", p.Sort)
		set(q, "from", p.From)
		set(q, "to", p.To)
		if p.Limit > 0 {
			q.Set("limit", strconv.Itoa(p.Limit))
		}
	}
	var out SearchResult
	return &out, r.c.do(ctx, http.MethodGet, "/search"+encodeQuery(q), nil, &out)
}

func (r *ArticlesResource) Recommendations(ctx context.Context, articleID string, limit int) (*RecommendationsResult, error) {
	q := url.Values{}
	q.Set("article_id", articleID)
	if limit > 0 {
		q.Set("limit", strconv.Itoa(limit))
	}
	var out RecommendationsResult
	return &out, r.c.do(ctx, http.MethodGet, "/recommendations"+encodeQuery(q), nil, &out)
}

// ── AI ────────────────────────────────────────────────────────────────────────

type AIResource struct{ c *Client }

func (r *AIResource) Complete(ctx context.Context, req *CompleteRequest) (*CompletionResponse, error) {
	var out CompletionResponse
	return &out, r.c.do(ctx, http.MethodPost, "/ai/complete", req, &out)
}

func (r *AIResource) Titles(ctx context.Context, req *TitlesRequest) (*TitlesResponse, error) {
	var out TitlesResponse
	return &out, r.c.do(ctx, http.MethodPost, "/ai/titles", req, &out)
}

// ── Images ────────────────────────────────────────────────────────────────────

type ImagesResource struct{ c *Client }

func (r *ImagesResource) Generate(ctx context.Context, req *GenerateImageRequest) (*GeneratedImage, error) {
	var out GeneratedImage
	return &out, r.c.do(ctx, http.MethodPost, "/images/generate", req, &out)
}

// Upload sends a file to the CDN as multipart/form-data under the "file" field.
func (r *ImagesResource) Upload(ctx context.Context, filename string, data []byte) (map[string]any, error) {
	body, contentType, err := buildMultipart("file", filename, data)
	if err != nil {
		return nil, err
	}
	var out map[string]any
	return out, r.c.doMultipart(ctx, "/images/upload", contentType, body, &out)
}

// ── Analytics ─────────────────────────────────────────────────────────────────

type AnalyticsResource struct{ c *Client }

func (r *AnalyticsResource) Summary(ctx context.Context, days int) (*AnalyticsSummary, error) {
	q := url.Values{}
	if days > 0 {
		q.Set("days", strconv.Itoa(days))
	}
	var out AnalyticsSummary
	return &out, r.c.do(ctx, http.MethodGet, "/analytics"+encodeQuery(q), nil, &out)
}

// ── Me / Profile ──────────────────────────────────────────────────────────────

type MeResource struct{ c *Client }

func (r *MeResource) Get(ctx context.Context) (*Profile, error) {
	var out Profile
	return &out, r.c.do(ctx, http.MethodGet, "/me", nil, &out)
}

// ── Plan ──────────────────────────────────────────────────────────────────────

type PlanResource struct{ c *Client }

func (r *PlanResource) Get(ctx context.Context) (*Plan, error) {
	var out Plan
	return &out, r.c.do(ctx, http.MethodGet, "/plan", nil, &out)
}

// ── Reactions ─────────────────────────────────────────────────────────────────

type ReactionsResource struct{ c *Client }

func (r *ReactionsResource) Get(ctx context.Context, articleID string) (*ArticleReactions, error) {
	q := url.Values{}
	q.Set("article_id", articleID)
	var out ArticleReactions
	return &out, r.c.do(ctx, http.MethodGet, "/reactions"+encodeQuery(q), nil, &out)
}

func (r *ReactionsResource) Add(ctx context.Context, articleID, reactionType string) (*ReactionMutationResult, error) {
	var out ReactionMutationResult
	body := map[string]string{"article_id": articleID, "type": reactionType}
	return &out, r.c.do(ctx, http.MethodPost, "/reactions", body, &out)
}

func (r *ReactionsResource) Remove(ctx context.Context, articleID, reactionType string) (*ReactionMutationResult, error) {
	q := url.Values{}
	q.Set("article_id", articleID)
	q.Set("type", reactionType)
	var out ReactionMutationResult
	return &out, r.c.do(ctx, http.MethodDelete, "/reactions"+encodeQuery(q), nil, &out)
}

// ── Series ────────────────────────────────────────────────────────────────────

type SeriesResource struct{ c *Client }

func (r *SeriesResource) List(ctx context.Context) (*SeriesListResult, error) {
	var out SeriesListResult
	return &out, r.c.do(ctx, http.MethodGet, "/series", nil, &out)
}

func (r *SeriesResource) Create(ctx context.Context, req *CreateSeriesRequest) (*Series, error) {
	var out Series
	return &out, r.c.do(ctx, http.MethodPost, "/series", req, &out)
}

func (r *SeriesResource) AddArticle(ctx context.Context, slug string, req *AddToSeriesRequest) (map[string]any, error) {
	var out map[string]any
	return out, r.c.do(ctx, http.MethodPost, "/series/"+url.PathEscape(slug)+"/articles", req, &out)
}

// ── Comments ──────────────────────────────────────────────────────────────────

type CommentsResource struct{ c *Client }

// List returns an article's comment thread, newest first, with replies nested
// one level deep. limit defaults to 20 (max 100) and offset to 0 when zero.
func (r *CommentsResource) List(ctx context.Context, articleID string, limit, offset int) (*CommentsResult, error) {
	q := url.Values{}
	set(q, "article_id", articleID)
	if limit > 0 {
		set(q, "limit", strconv.Itoa(limit))
	}
	if offset > 0 {
		set(q, "offset", strconv.Itoa(offset))
	}
	var out CommentsResult
	return &out, r.c.do(ctx, http.MethodGet, "/comments"+encodeQuery(q), nil, &out)
}

// ── Follows ───────────────────────────────────────────────────────────────────

type FollowsResource struct{ c *Client }

// Status returns a profile's follower/following counts plus whether the key's
// owner follows it.
func (r *FollowsResource) Status(ctx context.Context, userID string) (*FollowStatus, error) {
	q := url.Values{}
	set(q, "user_id", userID)
	var out FollowStatus
	return &out, r.c.do(ctx, http.MethodGet, "/follows"+encodeQuery(q), nil, &out)
}

// ── Trial ─────────────────────────────────────────────────────────────────────

type TrialResource struct{ c *Client }

func (r *TrialResource) Status(ctx context.Context) (*TrialStatus, error) {
	var out TrialStatus
	return &out, r.c.do(ctx, http.MethodGet, "/trial", nil, &out)
}

func (r *TrialResource) Start(ctx context.Context, req *StartTrialRequest) (map[string]any, error) {
	var out map[string]any
	return out, r.c.do(ctx, http.MethodPost, "/trial", req, &out)
}

// ── Upsell Funnel (platform-admin only) ───────────────────────────────────────

type UpsellFunnelResource struct{ c *Client }

func (r *UpsellFunnelResource) Get(ctx context.Context, p *UpsellFunnelParams) (map[string]any, error) {
	q := url.Values{}
	if p != nil {
		if p.Days > 0 {
			q.Set("days", strconv.Itoa(p.Days))
		}
		set(q, "feature", p.Feature)
	}
	var out map[string]any
	return out, r.c.do(ctx, http.MethodGet, "/upsell-funnel"+encodeQuery(q), nil, &out)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

func set(q url.Values, k, v string) {
	if v != "" {
		q.Set(k, v)
	}
}

func encodeQuery(q url.Values) string {
	if s := q.Encode(); s != "" {
		return "?" + s
	}
	return ""
}
