/// Typed models for the Misar.Blog dev-API.
///
/// Every model keeps the original decoded JSON in [raw] so fields added to the
/// API after this SDK was published remain accessible via `model.raw['field']`.

/// Article status values.
enum ArticleStatus { draft, published, scheduled, archived, flagged }

/// Article visibility values.
enum ArticleVisibility { public, subscribers, paid, private, webhookOnly }

/// An article (draft, scheduled, published, ...).
class Article {
  final Map<String, dynamic> raw;
  Article(this.raw);

  String? get id => raw['id'] as String?;
  String? get slug => raw['slug'] as String?;
  String? get title => raw['title'] as String?;
  String? get status => raw['status'] as String?;
  String? get url => raw['url'] as String?;
  String? get editorUrl => raw['editor_url'] as String?;
  String? get excerpt => raw['excerpt'] as String?;
  List<String> get tags =>
      (raw['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [];
  String? get visibility => raw['visibility'] as String?;
  String? get publishedAt => raw['published_at'] as String?;
  String? get createdAt => raw['created_at'] as String?;
}

/// Result of `GET /articles`.
class ArticleList {
  final Map<String, dynamic> raw;
  ArticleList(this.raw);

  List<Article> get articles =>
      (raw['articles'] as List?)
          ?.map((e) => Article(e as Map<String, dynamic>))
          .toList() ??
      const [];
  int? get total => raw['total'] as int?;
}

/// A series/collection of articles.
class Series {
  final Map<String, dynamic> raw;
  Series(this.raw);

  String? get id => raw['id'] as String?;
  String? get slug => raw['slug'] as String?;
  String? get title => raw['title'] as String?;
  String? get description => raw['description'] as String?;
  int? get articleCount => raw['article_count'] as int?;
  String? get createdAt => raw['created_at'] as String?;
}

/// Result of `GET /series`.
class SeriesList {
  final Map<String, dynamic> raw;
  SeriesList(this.raw);

  List<Series> get series =>
      (raw['series'] as List?)
          ?.map((e) => Series(e as Map<String, dynamic>))
          .toList() ??
      const [];
}

/// The authenticated developer's public profile (`GET /me`).
class Profile {
  final Map<String, dynamic> raw;
  Profile(this.raw);

  String? get id => raw['id'] as String?;
  String? get username => raw['username'] as String?;
  String? get displayName => raw['display_name'] as String?;
  String? get bio => raw['bio'] as String?;
  String? get avatarUrl => raw['avatar_url'] as String?;
  bool? get stripeConnected => raw['stripe_connected'] as bool?;
  String? get profileUrl => raw['profile_url'] as String?;
  String? get createdAt => raw['created_at'] as String?;
}

/// A single plan-usage counter row.
class PlanUsage {
  final Map<String, dynamic> raw;
  PlanUsage(this.raw);

  String? get feature => raw['feature'] as String?;
  String? get featureLabel => raw['feature_label'] as String?;
  int? get used => raw['used'] as int?;
  int? get limit => raw['limit'] as int?;
  int? get remaining => raw['remaining'] as int?;
  String? get period => raw['period'] as String?;
  String? get resetsAt => raw['resets_at'] as String?;
}

/// Plan + usage snapshot (`GET /plan`).
class Plan {
  final Map<String, dynamic> raw;
  Plan(this.raw);

  Map<String, dynamic>? get plan => raw['plan'] as Map<String, dynamic>?;
  String? get slug => plan?['slug'] as String?;
  String? get name => plan?['name'] as String?;
  List<PlanUsage> get usage =>
      (raw['usage'] as List?)
          ?.map((e) => PlanUsage(e as Map<String, dynamic>))
          .toList() ??
      const [];
  Map<String, dynamic>? get upgrade => raw['upgrade'] as Map<String, dynamic>?;
}

/// Account-wide analytics summary (`GET /analytics`).
class Analytics {
  final Map<String, dynamic> raw;
  Analytics(this.raw);

  int? get periodDays => raw['period_days'] as int?;
  int? get views => raw['views'] as int?;
  int? get revenueCents => raw['revenue_cents'] as int?;
  int? get revenueNetCents => raw['revenue_net_cents'] as int?;
  int? get activeSubscribers => raw['active_subscribers'] as int?;
}

/// Reaction counts for an article (`GET /reactions`).
class ArticleReactions {
  final Map<String, dynamic> raw;
  ArticleReactions(this.raw);

  String? get articleId => raw['article_id'] as String?;
  Map<String, dynamic> get counts =>
      (raw['counts'] as Map<String, dynamic>?) ?? const {};
  int? get total => raw['total'] as int?;
  List<String> get userReactions =>
      (raw['user_reactions'] as List?)?.map((e) => e.toString()).toList() ??
      const [];
}

/// Result of adding/removing a reaction.
class ReactionResult {
  final Map<String, dynamic> raw;
  ReactionResult(this.raw);

  bool? get success => raw['success'] as bool?;
  bool? get reacted => raw['reacted'] as bool?;
}

/// Trial eligibility/status (`GET /trial`).
class TrialStatus {
  final Map<String, dynamic> raw;
  TrialStatus(this.raw);

  bool? get eligible => raw['eligible'] as bool?;
  bool? get active => raw['active'] as bool?;
  String? get endsAt => raw['ends_at'] as String?;
  String? get planSlug => raw['plan_slug'] as String?;
  int? get days => raw['days'] as int?;
  bool? get requiresCard => raw['requires_card'] as bool?;
  String? get reason => raw['reason'] as String?;
}

/// A single generated title suggestion.
class TitleSuggestion {
  final Map<String, dynamic> raw;
  TitleSuggestion(this.raw);

  String? get title => raw['title'] as String?;
  String? get hint => raw['hint'] as String?;
}

/// Result of `POST /ai/titles`.
class TitlesResult {
  final Map<String, dynamic> raw;
  TitlesResult(this.raw);

  List<TitleSuggestion> get titles =>
      (raw['titles'] as List?)
          ?.map((e) => TitleSuggestion(e as Map<String, dynamic>))
          .toList() ??
      const [];
}

/// Result of `POST /ai/complete`.
class AiText {
  final Map<String, dynamic> raw;
  AiText(this.raw);

  String? get text => raw['text'] as String?;
}

/// Result of the image endpoints.
class ImageResult {
  final Map<String, dynamic> raw;
  ImageResult(this.raw);

  String? get url => raw['url'] as String?;
}

/// Author of a [Comment].
class CommentAuthor {
  final Map<String, dynamic> raw;
  CommentAuthor(this.raw);

  String? get id => raw['id'] as String?;
  String? get username => raw['username'] as String?;
  String? get displayName => raw['display_name'] as String?;
  String? get avatarUrl => raw['avatar_url'] as String?;
}

/// A single comment on an article.
class Comment {
  final Map<String, dynamic> raw;
  Comment(this.raw);

  String? get id => raw['id'] as String?;
  String? get articleId => raw['article_id'] as String?;
  String? get userId => raw['user_id'] as String?;
  String? get parentId => raw['parent_id'] as String?;
  String? get content => raw['content'] as String?;
  bool get isEdited => raw['is_edited'] == true;
  bool get isHidden => raw['is_hidden'] == true;
  int get replyCount => (raw['reply_count'] as num?)?.toInt() ?? 0;
  String? get createdAt => raw['created_at'] as String?;
  String? get updatedAt => raw['updated_at'] as String?;

  CommentAuthor? get user => raw['user'] is Map<String, dynamic>
      ? CommentAuthor(raw['user'] as Map<String, dynamic>)
      : null;

  /// Nested one level deep; empty on reply objects themselves.
  List<Comment> get replies =>
      (raw['replies'] as List?)
          ?.map((e) => Comment(e as Map<String, dynamic>))
          .toList() ??
      const [];
}

/// Result of `GET /comments`.
class CommentsResult {
  final Map<String, dynamic> raw;
  CommentsResult(this.raw);

  List<Comment> get comments =>
      (raw['comments'] as List?)
          ?.map((e) => Comment(e as Map<String, dynamic>))
          .toList() ??
      const [];

  int get totalCount => (raw['totalCount'] as num?)?.toInt() ?? 0;
  bool get hasMore => raw['hasMore'] == true;
}

/// Result of `GET /follows`.
class FollowStatus {
  final Map<String, dynamic> raw;
  FollowStatus(this.raw);

  bool get isFollowing => raw['isFollowing'] == true;
  int get followerCount => (raw['followerCount'] as num?)?.toInt() ?? 0;
  int get followingCount => (raw['followingCount'] as num?)?.toInt() ?? 0;
}
