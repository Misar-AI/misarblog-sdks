import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:misarblog_flutter/misarblog_flutter.dart';

MisarBlogClient _client(http.Client mock, {int maxRetries = 1}) =>
    MisarBlogClient(
      apiKey: 'mbk_test',
      baseUrl: 'https://api.misar.io/blog/v1',
      maxRetries: maxRetries,
      httpClient: mock,
    );

http.Response _json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// In-memory fake so `withSecureStorage` can be tested without platform channels.
class _FakeKeyStore extends SecureKeyStore {
  final String? _key;
  const _FakeKeyStore(this._key);
  @override
  Future<String?> loadApiKey() async => _key;
}

void main() {
  group('MisarBlogClient', () {
    test('sends the mbk_ bearer token to the correct base path', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return _json(200, {'id': 'u1', 'username': 'gulshan'});
      });
      final profile = await _client(mock).account.profile();
      expect(profile.username, equals('gulshan'));
      expect(captured.headers['Authorization'], equals('Bearer mbk_test'));
      expect(captured.url.toString(), 'https://api.misar.io/blog/v1/me');
    });

    test('articles.list returns typed ArticleList', () async {
      final mock = MockClient((_) async => _json(200, {
            'articles': [
              {'id': 'a1', 'slug': 'hello', 'title': 'Hello'}
            ],
            'total': 1,
          }));
      final result = await _client(mock).articles.list(limit: 10);
      expect(result.total, equals(1));
      expect(result.articles.first, isA<Article>());
      expect(result.articles.first.slug, equals('hello'));
    });

    test('articles.publish POSTs body and returns Article', () async {
      late String sent;
      final mock = MockClient((req) async {
        sent = req.body;
        return _json(200, {'id': 'a2', 'slug': 'new', 'status': 'published'});
      });
      final article = await _client(mock)
          .articles
          .publish(title: 'New', bodyMarkdown: '# Hi');
      expect(article.slug, equals('new'));
      final body = jsonDecode(sent) as Map<String, dynamic>;
      expect(body['title'], 'New');
      expect(body['body_markdown'], '# Hi');
    });

    test('ai.titles returns typed TitlesResult', () async {
      final mock = MockClient((_) async => _json(200, {
            'titles': [
              {'title': 'T1', 'hint': 'h'}
            ]
          }));
      final res =
          await _client(mock).ai.titles(action: 'seo', prompt: 'ai blogging');
      expect(res.titles.first.title, equals('T1'));
    });

    test('reactions.remove sends article_id and type as query params', () async {
      late Uri url;
      final mock = MockClient((req) async {
        url = req.url;
        return _json(200, {'success': true, 'reacted': false});
      });
      final res =
          await _client(mock).reactions.remove(articleId: 'a1', type: 'like');
      expect(res.reacted, isFalse);
      expect(url.queryParameters['article_id'], 'a1');
      expect(url.queryParameters['type'], 'like');
    });

    test('analytics.get returns typed Analytics', () async {
      final mock = MockClient(
          (_) async => _json(200, {'period_days': 30, 'views': 1000}));
      final res = await _client(mock).analytics.get(days: 30);
      expect(res.views, equals(1000));
    });

    test('throws MisarBlogException on 401', () async {
      final mock =
          MockClient((_) async => _json(401, {'error': 'Unauthorized'}));
      expect(
        () => _client(mock).account.profile(),
        throwsA(isA<MisarBlogException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('retries on 503 and still succeeds on the final attempt', () async {
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        if (calls < 3) return _json(503, {'error': 'down'});
        return _json(200, {'username': 'ok'});
      });
      final res = await _client(mock, maxRetries: 3).account.profile();
      expect(res.username, equals('ok'));
      expect(calls, equals(3));
    });

    test('withSecureStorage throws when no key stored', () async {
      await expectLater(
        MisarBlogClient.withSecureStorage(keyStore: const _FakeKeyStore(null)),
        throwsA(isA<StateError>()),
      );
    });

    test('withSecureStorage builds a client with the stored key', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return _json(200, {'username': 'stored'});
      });
      final client = await MisarBlogClient.withSecureStorage(
        keyStore: const _FakeKeyStore('mbk_stored'),
        httpClient: mock,
      );
      await client.account.profile();
      expect(captured.headers['Authorization'], equals('Bearer mbk_stored'));
    });
  });
}
