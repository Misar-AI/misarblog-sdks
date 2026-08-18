"""Typed models for the Misar.Blog developer API.

These are :class:`typing.TypedDict` shapes — at runtime the client returns plain
``dict`` objects, so these serve as documentation and static-type hints only.
"""

from __future__ import annotations

from typing import Any, Literal, Optional, TypedDict

ArticleStatus = Literal[
    "draft", "published", "scheduled", "archived", "flagged", "all"
]
ArticleVisibility = Literal[
    "public", "subscribers", "paid", "private", "webhook_only"
]
ReactionType = Literal["like", "clap", "bookmark"]
SearchType = Literal["all", "articles", "profiles", "tags"]
SearchSort = Literal["relevance", "newest", "oldest", "popular"]
ImageSize = Literal["1024x1024", "1792x1024", "1024x1792"]
TitleAction = Literal["suggest", "seo"]


class ArticleSummary(TypedDict, total=False):
    id: str
    slug: str
    title: str
    excerpt: Optional[str]
    status: str
    tags: list[str]
    published_at: Optional[str]
    created_at: str
    view_count: int
    is_premium: bool
    price_cents: int
    url: str


class Article(ArticleSummary, total=False):
    content_markdown: Optional[str]
    content_html: Optional[str]
    visibility: str
    updated_at: Optional[str]
    read_count: int
    featured_image_url: Optional[str]
    editor_url: str


class ArticleListResult(TypedDict, total=False):
    articles: list[ArticleSummary]
    total: int


class Series(TypedDict, total=False):
    id: str
    slug: str
    title: str
    description: Optional[str]
    cover_image_url: Optional[str]
    visibility: str
    created_at: str
    url: str


class SeriesListResult(TypedDict, total=False):
    series: list[Series]


class Profile(TypedDict, total=False):
    id: str
    username: str
    display_name: str
    bio: Optional[str]
    avatar_url: Optional[str]
    url: str


class AnalyticsSummary(TypedDict, total=False):
    period_days: int
    views: int
    revenue_cents: int
    revenue_net_cents: int
    active_subscribers: int


class Plan(TypedDict, total=False):
    plan: str
    status: str
    quota: dict[str, Any]
    upgrade_url: str


class TrialStatus(TypedDict, total=False):
    eligible: bool
    active: bool
    started_at: Optional[str]
    ends_at: Optional[str]


class ReactionCounts(TypedDict, total=False):
    like: int
    clap: int
    bookmark: int


class ArticleReactions(TypedDict, total=False):
    article_id: str
    counts: ReactionCounts
    total: int
    user_reactions: list[ReactionType]


class TitleResult(TypedDict, total=False):
    title: str
    hint: str


class TitlesResponse(TypedDict, total=False):
    titles: list[TitleResult]
    raw: str


class CompletionResponse(TypedDict, total=False):
    text: str
    tokens: int


class GeneratedImage(TypedDict, total=False):
    url: str
    size: str


class SearchResult(TypedDict, total=False):
    articles: list[dict[str, Any]]
    profiles: list[dict[str, Any]]
    tags: list[dict[str, Any]]


class RecommendationsResult(TypedDict, total=False):
    recommendations: list[dict[str, Any]]


class CommentAuthor(TypedDict, total=False):
    id: str
    username: str
    display_name: Optional[str]
    avatar_url: Optional[str]


class Comment(TypedDict, total=False):
    id: str
    article_id: str
    user_id: str
    parent_id: Optional[str]
    content: str
    is_edited: bool
    is_hidden: bool
    reply_count: int
    created_at: str
    updated_at: str
    user: CommentAuthor
    #: Nested one level deep; absent on reply objects themselves.
    replies: list["Comment"]


class CommentsResult(TypedDict, total=False):
    comments: list[Comment]
    totalCount: int
    hasMore: bool


class FollowStatus(TypedDict, total=False):
    isFollowing: bool
    followerCount: int
    followingCount: int
