package misarblog

// ── Articles ──────────────────────────────────────────────────────────────────

// ListArticlesParams are the optional filters for ArticlesResource.List.
type ListArticlesParams struct {
	Status      string // draft|published|scheduled|archived|flagged|all
	Visibility  string // public|subscribers|paid|private|webhook_only
	WebhookOnly *bool
	Sort        string // newest|views
	Limit       int
}

type ArticleSummary struct {
	ID          string   `json:"id"`
	Slug        string   `json:"slug"`
	Title       string   `json:"title"`
	Excerpt     *string  `json:"excerpt"`
	Status      string   `json:"status"`
	Tags        []string `json:"tags"`
	PublishedAt *string  `json:"published_at"`
	CreatedAt   string   `json:"created_at"`
	ViewCount   int      `json:"view_count"`
	IsPremium   bool     `json:"is_premium"`
	PriceCents  int      `json:"price_cents"`
	URL         string   `json:"url"`
}

type Article struct {
	ArticleSummary
	ContentMarkdown *string `json:"content_markdown"`
	ContentHTML     *string `json:"content_html"`
	Visibility      string  `json:"visibility"`
	UpdatedAt       *string `json:"updated_at"`
	ReadCount       int     `json:"read_count"`
	FeaturedImage   *string `json:"featured_image_url"`
	EditorURL       string  `json:"editor_url"`
}

type ArticleListResult struct {
	Articles []ArticleSummary `json:"articles"`
	Total    int              `json:"total"`
}

// PublishArticleRequest is the body for ArticlesResource.Publish.
type PublishArticleRequest struct {
	Title         string   `json:"title"`
	BodyMarkdown  string   `json:"body_markdown"`
	Tags          []string `json:"tags,omitempty"`
	CoverImageURL string   `json:"cover_image_url,omitempty"`
	ScheduleAt    string   `json:"schedule_at,omitempty"`
	Visibility    string   `json:"visibility,omitempty"`
}

// UpdateArticleRequest is the body for ArticlesResource.Update. Use pointers so
// zero values are distinguishable from "unset".
type UpdateArticleRequest struct {
	Title        *string   `json:"title,omitempty"`
	BodyMarkdown *string   `json:"body_markdown,omitempty"`
	Tags         *[]string `json:"tags,omitempty"`
	Publish      *bool     `json:"publish,omitempty"`
}

type CreateDraftRequest struct {
	Title        string   `json:"title"`
	BodyMarkdown string   `json:"body_markdown"`
	Tags         []string `json:"tags,omitempty"`
}

type MutateArticleResult struct {
	ID          string  `json:"id"`
	Slug        string  `json:"slug"`
	Title       string  `json:"title"`
	Status      string  `json:"status"`
	URL         string  `json:"url,omitempty"`
	EditorURL   string  `json:"editor_url,omitempty"`
	PublishedAt *string `json:"published_at,omitempty"`
	CreatedAt   string  `json:"created_at,omitempty"`
}

// ── Search / Recommendations ──────────────────────────────────────────────────

type SearchParams struct {
	Q      string
	Type   string // all|articles|profiles|tags
	Tag    string
	Author string
	Sort   string // relevance|newest|oldest|popular
	From   string
	To     string
	Limit  int
}

type SearchResult struct {
	Articles []map[string]any `json:"articles"`
	Profiles []map[string]any `json:"profiles"`
	Tags     []map[string]any `json:"tags"`
}

type RecommendationsResult struct {
	Recommendations []map[string]any `json:"recommendations"`
}

// ── AI ────────────────────────────────────────────────────────────────────────

type CompleteRequest struct {
	Prompt    string `json:"prompt"`
	System    string `json:"system,omitempty"`
	MaxTokens int    `json:"max_tokens,omitempty"`
}

type CompletionResponse struct {
	Text   string `json:"text"`
	Tokens int    `json:"tokens,omitempty"`
}

type TitlesRequest struct {
	Action  string `json:"action"` // suggest|seo
	Prompt  string `json:"prompt,omitempty"`
	Context string `json:"context,omitempty"`
}

type TitleResult struct {
	Title string `json:"title"`
	Hint  string `json:"hint"`
}

type TitlesResponse struct {
	Titles []TitleResult `json:"titles"`
	Raw    string        `json:"raw"`
}

// ── Images ────────────────────────────────────────────────────────────────────

type GenerateImageRequest struct {
	Prompt string `json:"prompt"`
	Size   string `json:"size,omitempty"` // 1024x1024|1792x1024|1024x1792
}

type GeneratedImage struct {
	URL  string `json:"url"`
	Size string `json:"size,omitempty"`
}

// ── Analytics / Plan / Me / Trial ─────────────────────────────────────────────

type AnalyticsSummary struct {
	PeriodDays        int `json:"period_days"`
	Views             int `json:"views"`
	RevenueCents      int `json:"revenue_cents"`
	RevenueNetCents   int `json:"revenue_net_cents"`
	ActiveSubscribers int `json:"active_subscribers"`
}

type Profile struct {
	ID          string  `json:"id"`
	Username    string  `json:"username"`
	DisplayName string  `json:"display_name"`
	Bio         *string `json:"bio"`
	AvatarURL   *string `json:"avatar_url"`
	URL         string  `json:"url"`
}

type Plan struct {
	Plan       string         `json:"plan"`
	Status     string         `json:"status"`
	Quota      map[string]any `json:"quota"`
	UpgradeURL string         `json:"upgrade_url"`
}

type TrialStatus struct {
	Eligible  bool    `json:"eligible"`
	Active    bool    `json:"active"`
	StartedAt *string `json:"started_at"`
	EndsAt    *string `json:"ends_at"`
}

type StartTrialRequest struct {
	Feature string `json:"feature,omitempty"`
	Ref     string `json:"ref,omitempty"`
}

// ── Reactions ─────────────────────────────────────────────────────────────────

type ReactionCounts struct {
	Like     int `json:"like"`
	Clap     int `json:"clap"`
	Bookmark int `json:"bookmark"`
}

type ArticleReactions struct {
	ArticleID     string         `json:"article_id"`
	Counts        ReactionCounts `json:"counts"`
	Total         int            `json:"total"`
	UserReactions []string       `json:"user_reactions"`
}

type ReactionMutationResult struct {
	Success bool `json:"success"`
	Reacted bool `json:"reacted"`
	Toggled bool `json:"toggled,omitempty"`
}

// ── Series ────────────────────────────────────────────────────────────────────

type Series struct {
	ID            string  `json:"id"`
	Slug          string  `json:"slug"`
	Title         string  `json:"title"`
	Description   *string `json:"description"`
	CoverImageURL *string `json:"cover_image_url"`
	Visibility    string  `json:"visibility"`
	CreatedAt     string  `json:"created_at"`
	URL           string  `json:"url"`
}

type SeriesListResult struct {
	Series []Series `json:"series"`
}

type CreateSeriesRequest struct {
	Title       string `json:"title"`
	Description string `json:"description,omitempty"`
}

type AddToSeriesRequest struct {
	ArticleSlug string `json:"article_slug"`
	Position    *int   `json:"position,omitempty"`
}

// ── Comments ──────────────────────────────────────────────────────────────────

type CommentAuthor struct {
	ID          string  `json:"id"`
	Username    string  `json:"username"`
	DisplayName *string `json:"display_name"`
	AvatarURL   *string `json:"avatar_url"`
}

type Comment struct {
	ID         string        `json:"id"`
	ArticleID  string        `json:"article_id"`
	UserID     string        `json:"user_id"`
	ParentID   *string       `json:"parent_id"`
	Content    string        `json:"content"`
	IsEdited   bool          `json:"is_edited"`
	IsHidden   bool          `json:"is_hidden"`
	ReplyCount int           `json:"reply_count"`
	CreatedAt  string        `json:"created_at"`
	UpdatedAt  string        `json:"updated_at"`
	User       CommentAuthor `json:"user"`
	// Replies is nested one level deep; nil on reply objects themselves.
	Replies []Comment `json:"replies,omitempty"`
}

type CommentsResult struct {
	Comments   []Comment `json:"comments"`
	TotalCount int       `json:"totalCount"`
	HasMore    bool      `json:"hasMore"`
}

// ── Follows ───────────────────────────────────────────────────────────────────

type FollowStatus struct {
	IsFollowing    bool `json:"isFollowing"`
	FollowerCount  int  `json:"followerCount"`
	FollowingCount int  `json:"followingCount"`
}

// ── Upsell Funnel ─────────────────────────────────────────────────────────────

type UpsellFunnelParams struct {
	Days    int
	Feature string
}
