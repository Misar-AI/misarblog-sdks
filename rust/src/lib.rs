//! Official Rust SDK for the **Misar.Blog developer API**.
//!
//! ```no_run
//! use misarblog::{MisarBlog, types::PublishArticleRequest};
//!
//! # async fn demo() -> Result<(), misarblog::BlogApiError> {
//! let blog = MisarBlog::new("mbk_your_key");
//!
//! let article = blog.articles.publish(&PublishArticleRequest {
//!     title: "Hello, Misar".into(),
//!     body_markdown: "# Hi\nFrom the Rust SDK.".into(),
//!     ..Default::default()
//! }).await?;
//! println!("published: {}", article.url);
//! # Ok(()) }
//! ```
//!
//! Authentication uses a developer key sent as `Authorization: Bearer mbk_...`.
//! OAuth 2.1 access tokens are accepted on the same header. The default base URL
//! is `https://api.misar.io/blog/v1` (the gateway strips `/api`).

pub mod errors;
pub mod types;

use std::sync::Arc;
use std::time::Duration;

use reqwest::{Client as HttpClient, Method};
use serde::Serialize;
use serde_json::Value;
use tokio::time::sleep;

pub use errors::BlogApiError;

// ── Constants ───────────────────────────────────────────────────────────────

/// Default gateway base URL (`/api` is stripped by the gateway).
pub const DEFAULT_BASE_URL: &str = "https://api.misar.io/blog/v1";
const DEFAULT_MAX_RETRIES: u32 = 3;
const RETRY_BASE_MS: u64 = 500;
static RETRYABLE: &[u16] = &[429, 500, 502, 503, 504];

// ── Inner transport ─────────────────────────────────────────────────────────

struct Inner {
    api_key: String,
    base_url: String,
    http: HttpClient,
    max_retries: u32,
}

impl Inner {
    fn new(api_key: &str, base_url: &str, max_retries: u32) -> Self {
        Self {
            api_key: api_key.to_owned(),
            base_url: base_url.trim_end_matches('/').to_owned(),
            http: HttpClient::builder()
                .timeout(Duration::from_secs(30))
                .build()
                .expect("failed to build HTTP client"),
            max_retries: max_retries.max(1),
        }
    }

    /// Core request path. Retries retryable statuses (429/5xx) and network
    /// errors with exponential back-off. Critically, the request is sent on
    /// **every** attempt including the last one — the final attempt is never
    /// skipped, so a request is never silently dropped after exhausting retries.
    async fn execute(
        &self,
        method: Method,
        path: &str,
        query: &[(String, String)],
        body: Option<Value>,
    ) -> Result<Value, BlogApiError> {
        let url = format!("{}{}", self.base_url, path);
        let mut last_err: Option<BlogApiError> = None;

        for attempt in 0..self.max_retries {
            if attempt > 0 {
                sleep(Duration::from_millis(RETRY_BASE_MS * (1 << (attempt - 1)))).await;
            }

            let mut req = self
                .http
                .request(method.clone(), &url)
                .header("Authorization", format!("Bearer {}", self.api_key))
                .header("Accept", "application/json");

            if !query.is_empty() {
                req = req.query(query);
            }
            if let Some(ref b) = body {
                req = req.json(b);
            }

            match req.send().await {
                Err(e) => {
                    // Network failure — retry if attempts remain, else surface it.
                    last_err = Some(BlogApiError::Network(e));
                    continue;
                }
                Ok(resp) => {
                    let status = resp.status().as_u16();

                    if status == 204 {
                        return Ok(Value::Null);
                    }

                    // Headers must be lifted out before `.text()` consumes the
                    // response — the plan-limit offer arrives in both.
                    let hdrs = PlanHeaders::from(resp.headers());
                    let text = resp.text().await.unwrap_or_default();

                    // A plan-limit 429 is not "slow down": retrying cannot help
                    // until the allowance resets or the plan changes, so break
                    // out of the retry loop and surface it immediately.
                    if is_plan_limit(&text) {
                        return Err(parse_plan_limit(status, &text, &hdrs));
                    }

                    // Retry only when attempts remain; on the final attempt fall
                    // through and return the real response/error.
                    if RETRYABLE.contains(&status) && attempt + 1 < self.max_retries {
                        last_err = Some(parse_api_error(status, &text));
                        continue;
                    }

                    if !(200..300).contains(&status) {
                        return Err(parse_api_error(status, &text));
                    }
                    if text.is_empty() {
                        return Ok(Value::Null);
                    }
                    return serde_json::from_str(&text).map_err(BlogApiError::Json);
                }
            }
        }

        Err(last_err.unwrap_or(BlogApiError::Api {
            status: 0,
            message: "max retries exceeded".to_owned(),
        }))
    }

    async fn get(&self, path: &str, query: &[(String, String)]) -> Result<Value, BlogApiError> {
        self.execute(Method::GET, path, query, None).await
    }

    async fn send_json<B: Serialize>(
        &self,
        method: Method,
        path: &str,
        body: &B,
    ) -> Result<Value, BlogApiError> {
        let v = serde_json::to_value(body).map_err(BlogApiError::Json)?;
        self.execute(method, path, &[], Some(v)).await
    }
}

/// Serialize any `Serialize` value into a flat list of query-string pairs,
/// dropping `null`/absent fields. Non-scalar values are JSON-encoded.
fn to_query<T: Serialize>(params: &T) -> Result<Vec<(String, String)>, BlogApiError> {
    let value = serde_json::to_value(params).map_err(BlogApiError::Json)?;
    let mut out = Vec::new();
    if let Some(obj) = value.as_object() {
        for (k, v) in obj {
            let s = match v {
                Value::Null => continue,
                Value::String(s) => s.clone(),
                Value::Bool(b) => b.to_string(),
                Value::Number(n) => n.to_string(),
                other => other.to_string(),
            };
            out.push((k.clone(), s));
        }
    }
    Ok(out)
}

/// The plan-refusal signal the API sets alongside a 402/429 body.
#[derive(Default)]
struct PlanHeaders {
    plan: Option<String>,
    upgrade_url: Option<String>,
    retry_after: Option<u64>,
}

impl PlanHeaders {
    fn from(h: &reqwest::header::HeaderMap) -> Self {
        let get = |k: &str| h.get(k).and_then(|v| v.to_str().ok()).map(str::to_owned);
        Self {
            plan: get("x-misar-plan"),
            upgrade_url: get("x-misar-upgrade-url"),
            retry_after: get("retry-after").and_then(|v| v.parse().ok()),
        }
    }
}

/// True when the error envelope carries the API's plan-limit code.
fn is_plan_limit(text: &str) -> bool {
    serde_json::from_str::<Value>(text)
        .ok()
        .and_then(|v| v.get("code").and_then(Value::as_str).map(str::to_owned))
        .is_some_and(|c| c == "plan_limit_exceeded")
}

fn parse_plan_limit(status: u16, text: &str, hdrs: &PlanHeaders) -> BlogApiError {
    let body: Value = serde_json::from_str(text).unwrap_or(Value::Null);
    let message = body
        .get("error")
        .and_then(Value::as_str)
        .unwrap_or("plan limit exceeded")
        .to_owned();

    // Headers are authoritative; fall back to the offer body when a proxy has
    // stripped them.
    let upgrade_url = hdrs.upgrade_url.clone().or_else(|| {
        body.pointer("/upgrade/urls/pricing")
            .and_then(Value::as_str)
            .map(str::to_owned)
    });
    let plan = hdrs.plan.clone().or_else(|| {
        body.pointer("/upgrade/current_plan/slug")
            .and_then(Value::as_str)
            .map(str::to_owned)
    });

    BlogApiError::PlanLimit {
        status,
        message,
        plan,
        upgrade_url,
        retry_after: hdrs.retry_after,
    }
}

fn parse_api_error(status: u16, text: &str) -> BlogApiError {
    let message = serde_json::from_str::<Value>(text)
        .ok()
        .and_then(|v| {
            v.get("error")
                .or_else(|| v.get("message"))
                .map(|m| match m {
                    Value::String(s) => s.clone(),
                    other => other.to_string(),
                })
        })
        .unwrap_or_else(|| {
            if text.is_empty() {
                format!("HTTP {}", status)
            } else {
                text.to_owned()
            }
        });
    BlogApiError::Api { status, message }
}

// ── Client ──────────────────────────────────────────────────────────────────

/// The Misar.Blog API client. Groups the 23 developer-API operations into
/// resource accessors.
pub struct MisarBlog {
    pub articles: ArticlesResource,
    pub series: SeriesResource,
    pub reactions: ReactionsResource,
    pub ai: AiResource,
    pub images: ImagesResource,
    pub account: AccountResource,
    pub analytics: AnalyticsResource,
    pub plan: PlanResource,
    pub comments: CommentsResource,
    pub follows: FollowsResource,
}

impl MisarBlog {
    /// Create a client with the default base URL and 3 retries.
    pub fn new(api_key: &str) -> Self {
        Self::build(api_key, DEFAULT_BASE_URL, DEFAULT_MAX_RETRIES)
    }

    /// Override the base URL (e.g. the app origin `https://www.misar.blog/api/v1`).
    pub fn with_base_url(self, url: &str) -> Self {
        let inner = Arc::clone(&self.articles.0);
        Self::build(&inner.api_key, url, inner.max_retries)
    }

    /// Override the maximum number of attempts (minimum 1).
    pub fn with_max_retries(self, n: u32) -> Self {
        let inner = Arc::clone(&self.articles.0);
        let base = inner.base_url.clone();
        Self::build(&inner.api_key, &base, n)
    }

    fn build(api_key: &str, base_url: &str, max_retries: u32) -> Self {
        let inner = Arc::new(Inner::new(api_key, base_url, max_retries));
        Self {
            articles: ArticlesResource(Arc::clone(&inner)),
            series: SeriesResource(Arc::clone(&inner)),
            reactions: ReactionsResource(Arc::clone(&inner)),
            ai: AiResource(Arc::clone(&inner)),
            images: ImagesResource(Arc::clone(&inner)),
            account: AccountResource(Arc::clone(&inner)),
            analytics: AnalyticsResource(Arc::clone(&inner)),
            plan: PlanResource(Arc::clone(&inner)),
            comments: CommentsResource(Arc::clone(&inner)),
            follows: FollowsResource(Arc::clone(&inner)),
        }
    }
}

// ── Resource: Articles ──────────────────────────────────────────────────────

/// Articles, drafts, search and recommendations.
pub struct ArticlesResource(Arc<Inner>);

impl ArticlesResource {
    /// `GET /articles` — list your articles.
    pub async fn list(&self, params: &types::ListArticlesParams) -> Result<Value, BlogApiError> {
        self.0.get("/articles", &to_query(params)?).await
    }

    /// `GET /articles/{slug}` — get a single article by slug or UUID.
    pub async fn get(&self, slug: &str) -> Result<types::Article, BlogApiError> {
        let v = self
            .0
            .get(&format!("/articles/{}", urlencode(slug)), &[])
            .await?;
        serde_json::from_value(v).map_err(BlogApiError::Json)
    }

    /// `POST /articles` — publish or schedule an article.
    pub async fn publish<B: Serialize>(&self, body: &B) -> Result<types::Article, BlogApiError> {
        let v = self.0.send_json(Method::POST, "/articles", body).await?;
        serde_json::from_value(v).map_err(BlogApiError::Json)
    }

    /// `PATCH /articles/{slug}` — update a draft's title/body/tags, or publish it.
    pub async fn update<B: Serialize>(
        &self,
        slug: &str,
        body: &B,
    ) -> Result<types::Article, BlogApiError> {
        let v = self
            .0
            .send_json(
                Method::PATCH,
                &format!("/articles/{}", urlencode(slug)),
                body,
            )
            .await?;
        serde_json::from_value(v).map_err(BlogApiError::Json)
    }

    /// `POST /drafts` — save an article as a draft.
    pub async fn create_draft<B: Serialize>(
        &self,
        body: &B,
    ) -> Result<types::Article, BlogApiError> {
        let v = self.0.send_json(Method::POST, "/drafts", body).await?;
        serde_json::from_value(v).map_err(BlogApiError::Json)
    }

    /// `GET /search` — search across articles, profiles, and tags.
    pub async fn search(&self, params: &types::SearchParams) -> Result<Value, BlogApiError> {
        self.0.get("/search", &to_query(params)?).await
    }

    /// `GET /recommendations` — semantically similar public articles.
    pub async fn recommendations(
        &self,
        article_id: &str,
        limit: Option<u32>,
    ) -> Result<Value, BlogApiError> {
        let mut q = vec![("article_id".to_owned(), article_id.to_owned())];
        if let Some(l) = limit {
            q.push(("limit".to_owned(), l.to_string()));
        }
        self.0.get("/recommendations", &q).await
    }
}

// ── Resource: Series ────────────────────────────────────────────────────────

/// Series (collections of articles).
pub struct SeriesResource(Arc<Inner>);

impl SeriesResource {
    /// `GET /series` — list your series.
    pub async fn list(&self) -> Result<Value, BlogApiError> {
        self.0.get("/series", &[]).await
    }

    /// `POST /series` — create a new series.
    pub async fn create<B: Serialize>(&self, body: &B) -> Result<types::Series, BlogApiError> {
        let v = self.0.send_json(Method::POST, "/series", body).await?;
        serde_json::from_value(v).map_err(BlogApiError::Json)
    }

    /// `POST /series/{slug}/articles` — add an article to a series.
    pub async fn add_article<B: Serialize>(
        &self,
        slug: &str,
        body: &B,
    ) -> Result<Value, BlogApiError> {
        self.0
            .send_json(
                Method::POST,
                &format!("/series/{}/articles", urlencode(slug)),
                body,
            )
            .await
    }
}

// ── Resource: Reactions ─────────────────────────────────────────────────────

/// Article reactions (like/clap/bookmark).
pub struct ReactionsResource(Arc<Inner>);

impl ReactionsResource {
    /// `GET /reactions` — reaction counts plus the caller's own reactions.
    pub async fn get(&self, article_id: &str) -> Result<Value, BlogApiError> {
        self.0
            .get(
                "/reactions",
                &[("article_id".to_owned(), article_id.to_owned())],
            )
            .await
    }

    /// `POST /reactions` — add or toggle a reaction on an article.
    pub async fn add<B: Serialize>(&self, body: &B) -> Result<Value, BlogApiError> {
        self.0.send_json(Method::POST, "/reactions", body).await
    }

    /// `DELETE /reactions` — remove a reaction from an article.
    pub async fn remove(&self, article_id: &str, kind: &str) -> Result<Value, BlogApiError> {
        self.0
            .execute(
                Method::DELETE,
                "/reactions",
                &[
                    ("article_id".to_owned(), article_id.to_owned()),
                    ("type".to_owned(), kind.to_owned()),
                ],
                None,
            )
            .await
    }
}

// ── Resource: AI ────────────────────────────────────────────────────────────

/// Credit-spending AI helpers (completions and title generation).
pub struct AiResource(Arc<Inner>);

impl AiResource {
    /// `POST /ai/complete` — generic system+user prompt completion.
    pub async fn complete<B: Serialize>(&self, body: &B) -> Result<Value, BlogApiError> {
        self.0.send_json(Method::POST, "/ai/complete", body).await
    }

    /// `POST /ai/titles` — generate SEO/AEO/GEO title suggestions.
    pub async fn titles<B: Serialize>(&self, body: &B) -> Result<Value, BlogApiError> {
        self.0.send_json(Method::POST, "/ai/titles", body).await
    }
}

// ── Resource: Images ────────────────────────────────────────────────────────

/// CDN image upload and AI cover-image generation.
pub struct ImagesResource(Arc<Inner>);

impl ImagesResource {
    /// `POST /images/generate` — generate a cover image via AI and upload it.
    pub async fn generate<B: Serialize>(&self, body: &B) -> Result<Value, BlogApiError> {
        self.0
            .send_json(Method::POST, "/images/generate", body)
            .await
    }

    /// `POST /images/upload` — upload an image to the CDN.
    pub async fn upload<B: Serialize>(&self, body: &B) -> Result<Value, BlogApiError> {
        self.0.send_json(Method::POST, "/images/upload", body).await
    }
}

// ── Resource: Account ───────────────────────────────────────────────────────

/// The authenticated creator's profile.
pub struct AccountResource(Arc<Inner>);

impl AccountResource {
    /// `GET /me` — get the authenticated creator's profile.
    pub async fn me(&self) -> Result<Value, BlogApiError> {
        self.0.get("/me", &[]).await
    }
}

// ── Resource: Analytics ─────────────────────────────────────────────────────

/// Analytics summaries and the per-feature upsell funnel.
pub struct AnalyticsResource(Arc<Inner>);

impl AnalyticsResource {
    /// `GET /analytics` — analytics summary for the caller.
    pub async fn summary(&self, days: Option<u32>) -> Result<Value, BlogApiError> {
        let q = days
            .map(|d| vec![("days".to_owned(), d.to_string())])
            .unwrap_or_default();
        self.0.get("/analytics", &q).await
    }

    /// `GET /upsell-funnel` — per-feature upsell conversion funnel (admin-only).
    pub async fn upsell_funnel(
        &self,
        days: Option<u32>,
        feature: Option<&str>,
    ) -> Result<Value, BlogApiError> {
        let mut q = Vec::new();
        if let Some(d) = days {
            q.push(("days".to_owned(), d.to_string()));
        }
        if let Some(f) = feature {
            q.push(("feature".to_owned(), f.to_owned()));
        }
        self.0.get("/upsell-funnel", &q).await
    }
}

// ── Resource: Plan & trial ──────────────────────────────────────────────────

/// Live plan/quota information and the self-serve trial.
pub struct PlanResource(Arc<Inner>);

impl PlanResource {
    /// `GET /plan` — live plan, quota and upgrade information.
    pub async fn get(&self) -> Result<Value, BlogApiError> {
        self.0.get("/plan", &[]).await
    }

    /// `GET /trial` — self-serve, no-card trial eligibility and status.
    pub async fn trial_status(&self) -> Result<Value, BlogApiError> {
        self.0.get("/trial", &[]).await
    }

    /// `POST /trial` — start the self-serve, no-card trial (tightly rate-limited).
    pub async fn start_trial<B: Serialize>(&self, body: &B) -> Result<Value, BlogApiError> {
        self.0.send_json(Method::POST, "/trial", body).await
    }
}

// ── Embed helpers (public, unauthenticated) ─────────────────────────────────

// ── Comments ────────────────────────────────────────────────────────────────

/// `GET /comments` — an article's comment thread.
pub struct CommentsResource(Arc<Inner>);

impl CommentsResource {
    /// List an article's comments, newest first, replies nested one level deep.
    /// `limit` defaults to 20 (max 100) and `offset` to 0 when omitted.
    pub async fn list(
        &self,
        article_id: &str,
        limit: Option<u32>,
        offset: Option<u32>,
    ) -> Result<types::CommentsResult, BlogApiError> {
        let mut q = vec![("article_id".to_owned(), article_id.to_owned())];
        if let Some(l) = limit {
            q.push(("limit".to_owned(), l.to_string()));
        }
        if let Some(o) = offset {
            q.push(("offset".to_owned(), o.to_string()));
        }
        let v = self.0.get("/comments", &q).await?;
        serde_json::from_value(v).map_err(BlogApiError::Json)
    }
}

// ── Follows ─────────────────────────────────────────────────────────────────

/// `GET /follows` — follower counts and the caller's follow state.
pub struct FollowsResource(Arc<Inner>);

impl FollowsResource {
    /// Follower/following counts for a profile, plus whether the key's owner
    /// follows it.
    pub async fn status(&self, user_id: &str) -> Result<types::FollowStatus, BlogApiError> {
        let q = vec![("user_id".to_owned(), user_id.to_owned())];
        let v = self.0.get("/follows", &q).await?;
        serde_json::from_value(v).map_err(BlogApiError::Json)
    }
}

/// Build a public embed URL for a creator profile or a specific article.
///
/// This is unauthenticated and independent of the developer API client.
pub fn embed_url(username: &str, slug: Option<&str>, theme: &str) -> String {
    const EMBED_BASE: &str = "https://misar.blog";
    let path = match slug {
        Some(s) => format!("{}/{}/embed", username, s),
        None => format!("{}/embed", username),
    };
    if theme != "auto" {
        format!("{}/{}?theme={}", EMBED_BASE, path, theme)
    } else {
        format!("{}/{}", EMBED_BASE, path)
    }
}

fn urlencode(s: &str) -> String {
    // Minimal path-segment encoding for slugs/UUIDs.
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char)
            }
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}
