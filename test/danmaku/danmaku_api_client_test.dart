import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plezy/danmaku/danmaku_api_client.dart';
import 'package:plezy/danmaku/danmaku_source.dart';

void main() {
  group('endpoint composition', () {
    for (final base in [
      'https://gateway.example/prefix/token',
      'https://gateway.example/prefix/token/',
      'https://gateway.example/prefix/token/api/v2/',
    ]) {
      test(base, () {
        expect(
          DanmakuEndpoint(base).route('search/anime', {'keyword': 'a b'}).toString(),
          'https://gateway.example/prefix/token/api/v2/search/anime?keyword=a+b',
        );
      });
    }
    test('preserves encoded token', () {
      expect(DanmakuEndpoint('https://gateway.example/a%2Fb').route('search/anime').pathSegments, [
        'a/b',
        'api',
        'v2',
        'search',
        'anime',
      ]);
    });
    for (final base in [
      '',
      'ftp://gateway.example',
      'https://gateway.example?token=secret',
      'https://gateway.example/#x',
      'https://user:secret@gateway.example',
    ]) {
      test('rejects ambiguous endpoint $base', () => expect(() => DanmakuEndpoint(base), throwsFormatException));
    }
    test('exact official origin', () {
      expect(DanmakuEndpoint('https://api.dandanplay.net').isOfficial, isTrue);
      for (final base in [
        'https://api.dandanplay.net.evil.example',
        'http://api.dandanplay.net',
        'https://api.dandanplay.net:444',
      ]) {
        expect(DanmakuEndpoint(base).isOfficial, isFalse);
      }
    });
  });

  test('v2 search, details, comments and optional count', () async {
    final requests = <http.Request>[];
    final client = DanmakuApiClient(
      baseUrl: 'https://gateway.example/private',
      sourceId: 'one',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.headers.keys.any((key) => key.toLowerCase().startsWith('x-app')), isFalse);
        expect(request.headers.containsKey('x-signature'), isFalse);
        if (request.url.path.endsWith('search/anime')) {
          return http.Response(
            jsonEncode({
              'animes': [
                {'animeId': 4, 'animeTitle': 'Title'},
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('bangumi/4')) {
          return http.Response(
            jsonEncode({
              'bangumi': {
                'episodes': [
                  {'episodeId': 41, 'episodeNumber': '1', 'episodeTitle': 'First'},
                  {'episodeId': 42, 'episodeNumber': 'SP1', 'episodeTitle': 'Special'},
                ],
              },
            }),
            200,
          );
        }
        return http.Response('{"comments":[]}', 200);
      }),
    );
    final works = await client.searchAnime('Title 第1季');
    final hits = await client.bangumi(works.single);
    expect(hits.first.sourceId, 'one');
    expect(hits.first.episodeNumber, 1);
    expect(hits.last.episodeNumber, isNull);
    expect(hits.first.commentCount, isNull);
    await client.fetchCommentsRaw('41', withRelated: false, chConvert: 2);
    expect(requests.last.url.queryParameters, {'withRelated': 'false', 'chConvert': '2'});
    expect(requests.first.url.queryParameters['keyword'], 'Title 第1季');
  });

  for (final status in [404, 405, 501]) {
    test('legacy fallback only on unsupported $status', () async {
      final paths = <String>[];
      final client = DanmakuApiClient(
        baseUrl: 'https://gateway.example',
        sourceId: 'one',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('search/anime')) return http.Response('', status);
          return http.Response(
            '{"animes":[{"animeId":1,"animeTitle":"Title","episodes":[{"episodeId":2,"episodeTitle":"第1话"}]}]}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final works = await client.searchAnime('Title');
      expect((await client.bangumi(works.single)).single.episodeNumber, 1);
      expect(paths, ['/api/v2/search/anime', '/api/v2/search/episodes']);
    });
  }
  for (final status in [401, 403, 500]) {
    test('no fallback on $status', () async {
      var calls = 0;
      final client = DanmakuApiClient(
        baseUrl: 'https://gateway.example',
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('secret', status);
        }),
      );
      await expectLater(
        client.searchAnime('Title'),
        throwsA(isA<DanmakuApiException>().having((e) => e.statusCode, 'status', status)),
      );
      expect(calls, 1);
    });
  }
  for (final body in [
    'not-json',
    '[]',
    '{"animes":{}}',
    '{"animes":[4]}',
    '{"errorCode":4,"errorMessage":"private/path/secret"}',
  ]) {
    test('safe malformed response $body', () async {
      final client = DanmakuApiClient(
        baseUrl: 'https://gateway.example',
        httpClient: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        client.searchAnime('Title'),
        throwsA(isA<DanmakuApiException>().having((e) => e.toString().contains('secret'), 'redaction', isFalse)),
      );
    });
  }
  test('timeout is safe and never triggers legacy', () async {
    var calls = 0;
    final client = DanmakuApiClient(
      baseUrl: 'https://gateway.example',
      timeout: const Duration(milliseconds: 1),
      httpClient: MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{"animes":[]}', 200);
      }),
    );
    await expectLater(
      client.searchAnime('Title'),
      throwsA(isA<DanmakuApiException>().having((e) => e.message, 'code', 'timeout')),
    );
    expect(calls, 1);
  });
  test('official without credentials does not send request', () async {
    var calls = 0;
    final client = DanmakuApiClient(
      baseUrl: 'https://api.dandanplay.net',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      client.searchAnime('Title'),
      throwsA(isA<DanmakuApiException>().having((e) => e.message, 'code', 'credentials_required')),
    );
    expect(calls, 0);
  });
  test('official signing and cross-origin redirect strips headers', () async {
    final requests = <http.Request>[];
    final client = DanmakuApiClient(
      baseUrl: 'https://api.dandanplay.net',
      credentials: const DanmakuCredentials(appId: 'your_app_id', appSecret: 'your_app_secret'),
      clock: () => DateTime.fromMillisecondsSinceEpoch(1735660800000, isUtc: true),
      httpClient: MockClient((request) async {
        requests.add(request);
        return requests.length == 1
            ? http.Response('', 302, headers: {'location': 'https://cdn.example/comments'})
            : http.Response('{"comments":[]}', 200);
      }),
    );
    await client.fetchCommentsRaw('123450001');
    expect(requests.first.headers['X-Signature'], 'MNBT8iOsIplI/GSkJEAH3V1AlpTyH1aMPJ1nedenEsw=');
    expect(requests.first.headers.containsKey('X-AppSecret'), isFalse);
    expect(requests.last.headers.keys.any((key) => key.toLowerCase().startsWith('x-')), isFalse);
    expect(requests.every((request) => !request.followRedirects), isTrue);
  });
  test('source mismatch rejected before details network call', () async {
    final client = DanmakuApiClient(baseUrl: 'https://gateway.example', sourceId: 'one');
    await expectLater(
      client.bangumi(const DanmakuAnime(sourceId: 'two', animeId: '4', title: 'Title')),
      throwsA(isA<DanmakuApiException>()),
    );
    client.close();
  });

  test('bangumi legacy fallback binds exact work instead of a same-title work', () async {
    final paths = <String>[];
    final client = DanmakuApiClient(
      baseUrl: 'https://gateway.example/prefix%2Ftoken/api/v2/',
      sourceId: 'one',
      httpClient: MockClient((request) async {
        paths.add(request.url.toString());
        if (request.url.path.endsWith('bangumi/4')) return http.Response('', 405);
        return http.Response(
          '{"animes":[{"animeId":5,"animeTitle":"Title","episodes":[{"episodeId":51}]},'
          '{"animeId":4,"animeTitle":"Title","episodes":[{"episodeId":41,"episodeNumber":"1"}]}]}',
          200,
        );
      }),
    );
    final hits = await client.bangumi(const DanmakuAnime(sourceId: 'one', animeId: '4', title: 'Title'));
    expect(hits.single.episodeId, '41');
    expect(paths, [
      'https://gateway.example/prefix%2Ftoken/api/v2/bangumi/4',
      'https://gateway.example/prefix%2Ftoken/api/v2/search/episodes?anime=Title',
    ]);
  });

  test('legacy same-title multiple works requires manual choice', () async {
    final client = DanmakuApiClient(
      baseUrl: 'https://gateway.example',
      sourceId: 'one',
      httpClient: MockClient(
        (request) async => request.url.path.contains('/bangumi/')
            ? http.Response('', 404)
            : http.Response(
                '{"animes":[{"animeId":5,"animeTitle":"Title","episodes":[{"episodeId":51}]},'
                '{"animeId":6,"animeTitle":"Title","episodes":[{"episodeId":61}]}]}',
                200,
              ),
      ),
    );
    await expectLater(
      client.bangumi(const DanmakuAnime(sourceId: 'one', animeId: '4', title: 'Title')),
      throwsA(isA<DanmakuApiException>().having((e) => e.message, 'code', 'ambiguous_work')),
    );
  });

  for (final base in [
    'http://api.dandanplay.net',
    'https://api.dandanplay.net:444',
    'https://api.dandanplay.net.evil.example/token',
    'https://gateway.example/private/api/v2',
  ]) {
    test('non-official $base never receives signing headers even with credentials', () async {
      final client = DanmakuApiClient(
        baseUrl: base,
        credentials: const DanmakuCredentials(appId: 'fixture-id', appSecret: 'fixture-secret'),
        httpClient: MockClient((request) async {
          expect(request.headers.keys.any((key) => key.toLowerCase().startsWith('x-')), isFalse);
          expect(request.headers.values.any((value) => value.contains('fixture-')), isFalse);
          return http.Response('{"comments":[]}', 200);
        }),
      );
      await client.fetchCommentsRaw('1');
    });
  }

  test('same-origin redirect is re-signed with the redirected path excluding query', () async {
    const credentials = DanmakuCredentials(appId: 'fixture-id', appSecret: 'fixture-secret');
    final requests = <http.Request>[];
    final client = DanmakuApiClient(
      baseUrl: 'https://api.dandanplay.net',
      credentials: credentials,
      clock: () => DateTime.fromMillisecondsSinceEpoch(1735660800000, isUtc: true),
      httpClient: MockClient((request) async {
        requests.add(request);
        return requests.length == 1
            ? http.Response('', 302, headers: {'location': '/api/v2/comment/redirected?private=query'})
            : http.Response('{"comments":[]}', 200);
      }),
    );
    await client.fetchCommentsRaw('1');
    expect(requests[1].headers['X-Signature'], isNot(requests[0].headers['X-Signature']));
    expect(
      requests[1].headers['X-Signature'],
      DanmakuOfficialSigner.headers(
        credentials,
        Uri.parse('https://api.dandanplay.net/api/v2/comment/redirected'),
        1735660800,
      )['X-Signature'],
    );
  });

  test('HTTPS downgrade redirect never sends a second request', () async {
    var calls = 0;
    final client = DanmakuApiClient(
      baseUrl: 'https://api.dandanplay.net',
      credentials: const DanmakuCredentials(appId: 'fixture-id', appSecret: 'fixture-secret'),
      httpClient: MockClient((request) async {
        calls++;
        return http.Response('', 302, headers: {'location': 'http://api.dandanplay.net/private'});
      }),
    );
    await expectLater(
      client.fetchCommentsRaw('1'),
      throwsA(isA<DanmakuApiException>().having((e) => e.message, 'code', 'invalid_redirect')),
    );
    expect(calls, 1);
  });

  test('signature headers stay stripped through cross-origin return redirects', () async {
    final requests = <http.Request>[];
    final client = DanmakuApiClient(
      baseUrl: 'https://api.dandanplay.net',
      credentials: const DanmakuCredentials(appId: 'fixture-id', appSecret: 'fixture-secret'),
      httpClient: MockClient((request) async {
        requests.add(request);
        return switch (requests.length) {
          1 => http.Response('', 302, headers: {'location': 'https://cdn.example/data'}),
          2 => http.Response('', 302, headers: {'location': 'https://api.dandanplay.net/return'}),
          _ => http.Response('{"comments":[]}', 200),
        };
      }),
    );
    await client.fetchCommentsRaw('1');
    for (final request in requests.skip(1)) {
      expect(request.headers.keys.any((key) => key.toLowerCase().startsWith('x-')), isFalse);
    }
  });
}
