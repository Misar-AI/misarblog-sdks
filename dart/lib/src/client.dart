import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'models.dart';

const _defaultBaseUrl = 'https://api.misar.io/blog/v1';
const _retryable = {429, 500, 502, 503, 504};

abstract class _Resource {
  final MisarBlogClient _client;
  const _Resource(this._client);
}

/// Pure-Dart client for the Misar.Blog developer API.
///
/// The gateway strips `/api`, so the base URL is `https://api.misar.io/blog/v1`
/// (never add `/api`). Authenticate with an `mbk_...` developer key or an
/// OAuth 2.1 access token via `Authorization: Bearer`.
///
/// ```dart
/// final blog = MisarBlogClient(apiKey: 'mbk_...');
/// final me = await blog.account.profile();
/// print(me.username);
/// blog.close();
/// ```
class MisarBlogClient {
  final String _apiKey;
  final String _baseUrl;
  final int _maxRetries;
  final http.Client _httpClient;

  late final AiResource ai;
  late final ArticlesResource articles;
  late final ImagesResource images;
  late final ReactionsResource reactions;
  late final SeriesResource series;
  late final AccountResource account;
  late final AnalyticsResource analytics;
  late final CommentsResource comments;
  late final FollowsResource follows;

  MisarBlogClient({
    required String apiKey,
    String baseUrl = _defaultBaseUrl,
    int maxRetries = 3,
    http.Client? httpClient,
  })  : assert(apiKey != '', 'apiKey is required'),
        _apiKey = apiKey,
        _baseUrl = baseUrl.replaceAll(RegExp(r'/$'), ''),
        _maxRetries = maxRetries < 1 ? 1 : maxRetries,
        _httpClient = httpClient ?? http.Client() {
    ai = AiResource(this);
    articles = ArticlesResource(this);
    images = ImagesResource(this);
    reactions = ReactionsResource(this);
    series = SeriesResource(this);
    account = AccountResource(this);
    analytics = AnalyticsResource(this);
    comments = CommentsResource(this);
    follows = FollowsResource(this);
  }

  /// Release the underlying HTTP client. Call when the client is no longer used.
  void close() => _httpClient.close();

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    Uri uri = Uri.parse('$_baseUrl$path');
    if (query != null) {
      final cleaned = <String, String>{};
      query.forEach((k, v) {
        if (v != null) cleaned[k] = v.toString();
      });
      if (cleaned.isNotEmpty) uri = uri.replace(queryParameters: cleaned);
    }
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final encoded = body != null ? jsonEncode(body) : null;

    var attempt = 0;
    while (true) {
      final isFinal = attempt == _maxRetries - 1;
      try {
        http.Response response;
        switch (method) {
          case 'GET':
            response = await _httpClient.get(uri, headers: headers);
            break;
          case 'POST':
            response =
                await _httpClient.post(uri, headers: headers, body: encoded);
            break;
          case 'PATCH':
            response =
                await _httpClient.patch(uri, headers: headers, body: encoded);
            break;
          case 'PUT':
            response =
                await _httpClient.put(uri, headers: headers, body: encoded);
            break;
          case 'DELETE':
            response =
                await _httpClient.delete(uri, headers: headers, body: encoded);
            break;
          default:
            throw MisarBlogError(0, 'Unsupported HTTP method: $method');
        }

        final status = response.statusCode;

        // A plan-limit 429 is not "slow down": retrying cannot help until the
        // allowance resets or the plan changes, so surface it immediately
        // instead of burning the retry budget.
        final planLimitBody = _planLimitBody(response.body);
        if (planLimitBody != null) {
          throw MisarBlogPlanLimitError.from(
              status, planLimitBody, response.headers);
        }

        // Retry transient statuses — but never on the final attempt, where the
        // real response is always parsed/raised (the send is never swallowed).
        if (_retryable.contains(status) && !isFinal) {
          await _backoff(attempt);
          attempt++;
          continue;
        }

        if (status >= 200 && status < 300) {
          if (response.body.isEmpty) return <String, dynamic>{};
          final decoded = jsonDecode(response.body);
          return decoded is Map<String, dynamic>
              ? decoded
              : <String, dynamic>{'data': decoded};
        }

        Map<String, dynamic>? errBody;
        try {
          final d = jsonDecode(response.body);
          if (d is Map<String, dynamic>) errBody = d;
        } catch (_) {}
        final message = (errBody?['error'] as String?) ??
            (errBody?['message'] as String?) ??
            response.reasonPhrase ??
            'HTTP $status';
        throw MisarBlogError(status, message, errBody);
      } on MisarBlogError {
        rethrow;
      } on SocketException catch (e) {
        if (isFinal) throw MisarBlogNetworkError(e.message);
        await _backoff(attempt);
        attempt++;
        continue;
      } on http.ClientException catch (e) {
        if (isFinal) throw MisarBlogNetworkError(e.message);
        await _backoff(attempt);
        attempt++;
        continue;
      }
    }
  }

  /// Returns the decoded body when it carries the API's plan-limit code,
  /// otherwise null.
  static Map<String, dynamic>? _planLimitBody(String raw) {
    if (raw.isEmpty) return null;
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic> && d['code'] == 'plan_limit_exceeded') {
        return d;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _backoff(int attempt) =>
      Future<void>.delayed(Duration(milliseconds: 300 * (1 << attempt)));
}

// ---------------------------------------------------------------------------
// Resources
// ---------------------------------------------------------------------------

/// AI helpers: completion + title generation.
class AiResource extends _Resource {
  const AiResource(super.client);

  /// `POST /ai/complete` — free-form completion.
  Future<AiText> complete({
    required String prompt,
    String? system,
    int? maxTokens,
  }) async =>
      AiText(await _client.request('POST', '/ai/complete', body: {
        'prompt': prompt,
        if (system != null) 'system': system,
        if (maxTokens != null) 'max_tokens': maxTokens,
      }));

  /// `POST /ai/titles` — SEO/AEO/GEO title suggestions.
  /// [action] is `"suggest"` or `"seo"`.
  Future<TitlesResult> titles({
    required String action,
    String? prompt,
    String? context,
  }) async =>
      TitlesResult(await _client.request('POST', '/ai/titles', body: {
        'action': action,
        if (prompt != null) 'prompt': prompt,
        if (context != null) 'context': context,
      }));
}

/// Articles, drafts, search and recommendations.
class ArticlesResource extends _Resource {
  const ArticlesResource(super.client);

  /// `GET /articles`
  Future<ArticleList> list({
    String? status,
    String? visibility,
    bool? webhookOnly,
    String? sort,
    int? limit,
  }) async =>
      ArticleList(await _client.request('GET', '/articles', query: {
        'status': status,
        'visibility': visibility,
        'webhook_only': webhookOnly,
        'sort': sort,
        'limit': limit,
      }));

  /// `GET /articles/{slug}`
  Future<Article> get(String slug) async => Article(
      await _client.request('GET', '/articles/${Uri.encodeComponent(slug)}'));

  /// `POST /articles` — publish (or schedule) a new article.
  Future<Article> publish({
    required String title,
    required String bodyMarkdown,
    List<String>? tags,
    String? coverImageUrl,
    String? scheduleAt,
    String? visibility,
  }) async =>
      Article(await _client.request('POST', '/articles', body: {
        'title': title,
        'body_markdown': bodyMarkdown,
        if (tags != null) 'tags': tags,
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
        if (scheduleAt != null) 'schedule_at': scheduleAt,
        if (visibility != null) 'visibility': visibility,
      }));

  /// `PATCH /articles/{slug}` — update an existing article.
  Future<Article> update(
    String slug, {
    String? title,
    String? bodyMarkdown,
    List<String>? tags,
    bool? publish,
  }) async =>
      Article(await _client.request(
        'PATCH',
        '/articles/${Uri.encodeComponent(slug)}',
        body: {
          if (title != null) 'title': title,
          if (bodyMarkdown != null) 'body_markdown': bodyMarkdown,
          if (tags != null) 'tags': tags,
          if (publish != null) 'publish': publish,
        },
      ));

  /// `POST /drafts` — create an unpublished draft.
  Future<Article> createDraft({
    required String title,
    required String bodyMarkdown,
    List<String>? tags,
  }) async =>
      Article(await _client.request('POST', '/drafts', body: {
        'title': title,
        'body_markdown': bodyMarkdown,
        if (tags != null) 'tags': tags,
      }));

  /// `GET /search` — full-text search across articles/profiles/tags.
  Future<Map<String, dynamic>> search({
    String? q,
    String? type,
    String? tag,
    String? author,
    String? sort,
    String? from,
    String? to,
    int? limit,
  }) =>
      _client.request('GET', '/search', query: {
        'q': q,
        'type': type,
        'tag': tag,
        'author': author,
        'sort': sort,
        'from': from,
        'to': to,
        'limit': limit,
      });

  /// `GET /recommendations` — related articles for a given article.
  Future<Map<String, dynamic>> recommendations({
    required String articleId,
    int? limit,
  }) =>
      _client.request('GET', '/recommendations', query: {
        'article_id': articleId,
        'limit': limit,
      });
}

/// Image generation + upload.
class ImagesResource extends _Resource {
  const ImagesResource(super.client);

  /// `POST /images/generate` — AI cover-image generation.
  Future<ImageResult> generate({required String prompt, String? size}) async =>
      ImageResult(await _client.request('POST', '/images/generate', body: {
        'prompt': prompt,
        if (size != null) 'size': size,
      }));

  /// `POST /images/upload` — register/host an image. Accepts a raw payload.
  Future<ImageResult> upload([Map<String, dynamic>? data]) async =>
      ImageResult(await _client.request('POST', '/images/upload', body: data));
}

/// Article reactions.
class ReactionsResource extends _Resource {
  const ReactionsResource(super.client);

  /// `GET /reactions?article_id=`
  Future<ArticleReactions> get(String articleId) async => ArticleReactions(
      await _client
          .request('GET', '/reactions', query: {'article_id': articleId}));

  /// `POST /reactions`
  Future<ReactionResult> add({
    required String articleId,
    required String type,
  }) async =>
      ReactionResult(await _client.request('POST', '/reactions', body: {
        'article_id': articleId,
        'type': type,
      }));

  /// `DELETE /reactions?article_id=&type=`
  Future<ReactionResult> remove({
    required String articleId,
    required String type,
  }) async =>
      ReactionResult(await _client.request('DELETE', '/reactions',
          query: {'article_id': articleId, 'type': type}));
}

/// Series/collections.
class SeriesResource extends _Resource {
  const SeriesResource(super.client);

  /// `GET /series`
  Future<SeriesList> list() async =>
      SeriesList(await _client.request('GET', '/series'));

  /// `POST /series`
  Future<Series> create({required String title, String? description}) async =>
      Series(await _client.request('POST', '/series', body: {
        'title': title,
        if (description != null) 'description': description,
      }));

  /// `POST /series/{slug}/articles` — add an article to a series.
  Future<Map<String, dynamic>> addArticle(
    String slug, {
    required String articleSlug,
    int? position,
  }) =>
      _client.request(
        'POST',
        '/series/${Uri.encodeComponent(slug)}/articles',
        body: {
          'article_slug': articleSlug,
          if (position != null) 'position': position,
        },
      );
}

/// Account: profile, plan, trial, upsell funnel.
class AccountResource extends _Resource {
  const AccountResource(super.client);

  /// `GET /me`
  Future<Profile> profile() async =>
      Profile(await _client.request('GET', '/me'));

  /// `GET /plan`
  Future<Plan> plan() async => Plan(await _client.request('GET', '/plan'));

  /// `GET /trial`
  Future<TrialStatus> trialStatus() async =>
      TrialStatus(await _client.request('GET', '/trial'));

  /// `POST /trial` — start a trial for a gated feature.
  Future<Map<String, dynamic>> startTrial({String? feature, String? ref}) =>
      _client.request('POST', '/trial', body: {
        if (feature != null) 'feature': feature,
        if (ref != null) 'ref': ref,
      });

  /// `GET /upsell-funnel`
  Future<Map<String, dynamic>> upsellFunnel({int? days, String? feature}) =>
      _client.request('GET', '/upsell-funnel',
          query: {'days': days, 'feature': feature});
}

/// Account-wide analytics.
class AnalyticsResource extends _Resource {
  const AnalyticsResource(super.client);

  /// `GET /analytics`
  Future<Analytics> get({int? days}) async =>
      Analytics(await _client.request('GET', '/analytics', query: {'days': days}));
}

// ---------------------------------------------------------------------------

/// `GET /comments` — an article's comment thread.
class CommentsResource extends _Resource {
  CommentsResource(super.client);

  /// List an article's comments, newest first, replies nested one level deep.
  /// [limit] defaults to 20 (max 100) and [offset] to 0 server-side.
  Future<CommentsResult> list(
    String articleId, {
    int? limit,
    int? offset,
  }) async =>
      CommentsResult(await _client.request('GET', '/comments', query: {
        'article_id': articleId,
        'limit': limit,
        'offset': offset,
      }));
}

/// `GET /follows` — follower counts and the caller's follow state.
class FollowsResource extends _Resource {
  FollowsResource(super.client);

  Future<FollowStatus> status(String userId) async =>
      FollowStatus(await _client.request('GET', '/follows', query: {
        'user_id': userId,
      }));
}
