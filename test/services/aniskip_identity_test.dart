import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plezy/services/aniskip_identity.dart';

import '../test_helpers/prefs.dart';

void main() {
  group('stripSeasonSuffix', () {
    test('strips CJK season, English season and S-number suffixes', () {
      expect(stripSeasonSuffix('葬送的芙莉莲 第2季'), '葬送的芙莉莲');
      expect(stripSeasonSuffix('Foo Season 2'), 'Foo');
      expect(stripSeasonSuffix('Foo s3'), 'Foo');
      expect(stripSeasonSuffix('Foo 2nd Season'), 'Foo');
      expect(stripSeasonSuffix('Foo'), 'Foo');
    });
  });

  group('normalizeTitle', () {
    test('folds case and drops spacing and punctuation', () {
      expect(normalizeTitle('Sousou no Frieren:'), normalizeTitle('sousou no frieren'));
      expect(normalizeTitle('葬送のフリーレン'), '葬送のフリーレン');
      expect(normalizeTitle('Re:Zero'), normalizeTitle('re zero'));
      expect(normalizeTitle(''), isEmpty);
    });
  });

  group('matchJikanResult', () {
    final response = {
      'data': [
        {
          'mal_id': 52991,
          'title': 'Sousou no Frieren',
          'titles': [
            {'type': 'Default', 'title': 'Sousou no Frieren'},
            {'type': 'Japanese', 'title': '葬送のフリーレン'},
            {'type': 'Synonym', 'title': 'Frieren: Beyond Journey\'s End'},
          ],
        },
        {'mal_id': 999, 'title': 'Unrelated', 'titles': []},
      ],
    };

    test('accepts exact matches on any title form', () {
      expect(matchJikanResult(response, 'Sousou no Frieren'), 52991);
      expect(matchJikanResult(response, '葬送のフリーレン'), 52991);
      expect(matchJikanResult(response, 'Frieren: Beyond Journey\'s End'), 52991);
      expect(matchJikanResult(response, 'sousou no frieren!'), 52991);
    });

    test('rejects non-exact candidates — a wrong id beats no id never', () {
      expect(matchJikanResult(response, 'Frieren'), isNull);
      expect(matchJikanResult(response, ''), isNull);
      expect(matchJikanResult(null, 'x'), isNull);
      expect(matchJikanResult({'data': []}, 'x'), isNull);
      expect(matchJikanResult({'data': 'junk'}, 'x'), isNull);
    });
  });

  group('AniSkipBindings codec', () {
    test('round-trips and tolerates garbage', () {
      final bindings = AniSkipBindings(malIds: {'s1:show': 42}, missAtMs: {'s1:other': 7});
      expect(AniSkipBindings.decode(bindings.encode()).malIds['s1:show'], 42);
      expect(AniSkipBindings.decode(null).malIds, isEmpty);
      expect(AniSkipBindings.decode('not json').missAtMs, isEmpty);
      expect(AniSkipBindings.decode('{"bindings": {"a": 1.5}}').malIds['a'], 1);
    });
  });

  group('AniSkipIdentityResolver', () {
    test('binds on exact match, then remembers without another request', () async {
      resetSharedPreferencesForTest();
      var searches = 0;
      final resolver = AniSkipIdentityResolver(
        httpClient: MockClient((request) async {
          searches++;
          expect(request.url.path, '/v4/anime');
          expect(request.url.queryParameters['q'], 'Sousou no Frieren');
          return http.Response('{"data": [{"mal_id": 52991, "title": "Sousou no Frieren", "titles": []}]}', 200);
        }),
      );

      expect(await resolver.resolveMalId(seriesKey: 'srv:show', title: 'Sousou no Frieren Season 2'), 52991);
      expect(await resolver.resolveMalId(seriesKey: 'srv:show', title: 'Sousou no Frieren Season 2'), 52991);
      expect(searches, 1);
    });

    test('negative results are cached and retried only after the window', () async {
      resetSharedPreferencesForTest();
      var now = DateTime.fromMillisecondsSinceEpoch(1000000000000);
      var searches = 0;
      final resolver = AniSkipIdentityResolver(
        httpClient: MockClient((request) async {
          searches++;
          return http.Response('{"data": []}', 200);
        }),
        now: () => now,
      );

      expect(await resolver.resolveMalId(seriesKey: 'srv:show', title: '查无此番'), isNull);
      expect(await resolver.resolveMalId(seriesKey: 'srv:show', title: '查无此番'), isNull);
      expect(searches, 1);

      now = now.add(AniSkipIdentityResolver.retryAfter * 2);
      expect(await resolver.resolveMalId(seriesKey: 'srv:show', title: '查无此番'), isNull);
      expect(searches, 2);
    });

    test('network failures do not poison the negative cache forever', () async {
      resetSharedPreferencesForTest();
      var now = DateTime.fromMillisecondsSinceEpoch(1000000000000);
      var fail = true;
      final resolver = AniSkipIdentityResolver(
        httpClient: MockClient((request) async {
          if (fail) throw http.ClientException('boom');
          return http.Response('{"data": [{"mal_id": 1, "title": "X", "titles": []}]}', 200);
        }),
        now: () => now,
      );

      expect(await resolver.resolveMalId(seriesKey: 'srv:x', title: 'X'), isNull);
      fail = false;
      now = now.add(AniSkipIdentityResolver.retryAfter * 2);
      expect(await resolver.resolveMalId(seriesKey: 'srv:x', title: 'X'), 1);
    });
  });
}
