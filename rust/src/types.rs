//! Typed request and response models for the Misar.Blog developer API.
//!
//! Response endpoints whose OpenAPI schema is well-defined (`Article`, `Series`)
//! deserialize into the structs below. Free-form object responses (analytics,
//! search, plan, reactions, AI, images, profile, trial) are returned as
//! [`serde_json::Value`] so no field is silently dropped as the API evolves.

use serde::{Deserialize, Serialize};

// ── Response models ─────────────────────────────────────────────────────────

/// A blog article as returned by publish/draft/get/update endpoints.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Article {
    pub id: String,
    pub slug: String,
    pub title: String,
    pub status: String,
    pub url: String,
    pub editor_url: String,
    #[serde(default)]
    pub excerpt: Option<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub visibility: Option<String>,
    #[serde(default)]
    pub published_at: Option<String>,
    #[serde(default)]
    pub created_at: Option<String>,
}

/// A series (collection) of articles.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Series {
    pub id: String,
    pub slug: String,
    pub title: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub article_count: i64,
    #[serde(default)]
    pub created_at: Option<String>,
}

/// Standard error envelope (`{ "error": ..., "required_scope": ..., "granted_scopes": [...] }`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiErrorBody {
    pub error: serde_json::Value,
    #[serde(default)]
    pub required_scope: Option<String>,
    #[serde(default)]
    pub granted_scopes: Option<Vec<String>>,
}

// ── Request models ──────────────────────────────────────────────────────────

/// Query parameters for `GET /articles`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct ListArticlesParams {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub visibility: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub webhook_only: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub limit: Option<u32>,
}

/// Query parameters for `GET /search`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct SearchParams {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub q: Option<String>,
    #[serde(rename = "type", skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tag: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub author: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub from: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub to: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub limit: Option<u32>,
}

/// Body for `POST /articles`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct PublishArticleRequest {
    pub title: String,
    pub body_markdown: String,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub tags: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cover_image_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub schedule_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub visibility: Option<String>,
}

/// Body for `POST /drafts`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct CreateDraftRequest {
    pub title: String,
    pub body_markdown: String,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub tags: Vec<String>,
}

/// Body for `PATCH /articles/{slug}`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct UpdateArticleRequest {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub body_markdown: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tags: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub publish: Option<bool>,
}

/// Body for `POST /series`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct CreateSeriesRequest {
    pub title: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
}

/// Body for `POST /series/{slug}/articles`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct AddToSeriesRequest {
    pub article_slug: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub position: Option<i64>,
}

/// Body for `POST /reactions`.
#[derive(Debug, Clone, Serialize)]
pub struct AddReactionRequest {
    pub article_id: String,
    /// One of `like`, `clap`, `bookmark`.
    #[serde(rename = "type")]
    pub kind: String,
}

/// Body for `POST /ai/complete`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct AiCompleteRequest {
    pub system: String,
    pub prompt: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_tokens: Option<u32>,
}

/// Body for `POST /ai/titles`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct GenerateTitlesRequest {
    /// One of `suggest`, `seo`.
    pub action: String,
    pub prompt: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub context: Option<String>,
}

/// Body for `POST /images/generate`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct GenerateImageRequest {
    pub prompt: String,
    /// One of `1024x1024`, `1792x1024`, `1024x1792`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub size: Option<String>,
}

/// Body for `POST /trial`.
#[derive(Debug, Clone, Default, Serialize)]
pub struct StartTrialRequest {
    pub feature: String,
    #[serde(rename = "ref", skip_serializing_if = "Option::is_none")]
    pub referrer: Option<String>,
}

// ── Comments ────────────────────────────────────────────────────────────────

/// Comment author, as embedded in each [`Comment`].
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommentAuthor {
    pub id: String,
    pub username: String,
    pub display_name: Option<String>,
    pub avatar_url: Option<String>,
}

/// A single comment on an article.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Comment {
    pub id: String,
    pub article_id: String,
    pub user_id: String,
    pub parent_id: Option<String>,
    pub content: String,
    pub is_edited: bool,
    pub is_hidden: bool,
    pub reply_count: i64,
    pub created_at: String,
    pub updated_at: String,
    pub user: CommentAuthor,
    /// Nested one level deep; absent on reply objects themselves.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub replies: Option<Vec<Comment>>,
}

/// Response of `GET /comments`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommentsResult {
    pub comments: Vec<Comment>,
    #[serde(rename = "totalCount")]
    pub total_count: i64,
    #[serde(rename = "hasMore")]
    pub has_more: bool,
}

// ── Follows ─────────────────────────────────────────────────────────────────

/// Response of `GET /follows`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FollowStatus {
    #[serde(rename = "isFollowing")]
    pub is_following: bool,
    #[serde(rename = "followerCount")]
    pub follower_count: i64,
    #[serde(rename = "followingCount")]
    pub following_count: i64,
}
