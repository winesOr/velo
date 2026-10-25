import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plezy/services/aniskip_client.dart';

/// Wire-contract pin for api.aniskip.com v2 `skip-times` (verified live
/// 2026-10-24). Failures must stay silent: AniSkip only enriches markers.
void main() {
  group('request composition', () {
    test('hits /v2/skip-times with repeatable types and the episode length', () async {
      Uri? seen;
      final client = AniSkipClient(
        httpClient: MockClient((request) async {
          seen = request.url;
          return http.Response('{"found": false}', 200);
        }),
      );
      await client.fetchSkipTimes(malId: 52991, episodeNumber: 1, episodeLengthSeconds: 1420.4);
      expect(seen!.path, '/v2/skip-times/52991/1');
      expect(seen!.queryParametersAll['types[]'], containsAll(['op', 'ed', 'recap']));
      expect(seen!.queryParameters['episodeLength'], '1420');
      expect(seen!.queryParametersAll['types[]'], isNot(contains('types')));
    });
  });

  group('response parsing', () {
    test('maps op/ed/recap and mixed variants onto marker types', () {
      final markers = AniSkipClient.parseSkipTimes({
        'found': true,
        'results': [
          {
            'interval': {'startTime': 34.54, 'endTime': 124.54},
            'skipType': 'op',
          },
          {
            'interval': {'startTime': 1330.583, 'endTime': 1421.21},
            'skipType': 'ed',
          },
          {
            'interval': {'startTime': 0, 'endTime': 18.2},
            'skipType': 'recap',
          },
          {
            'interval': {'startTime': 10, 'endTime': 100},
            'skipType': 'mixed-op',
          },
          {
            'interval': {'startTime': 10, 'endTime': 100},
            'skipType': 'mixed-ed',
          },
        ],
      });
      expect(markers.map((m) => m.type).toList(), ['intro', 'credits', 'recap', 'intro', 'credits']);
      expect(markers.first.startTimeOffset, 34540);
      expect(markers.first.endTimeOffset, 124540);
      expect(markers.first.source, 'aniskip');
    });

    test('found=false, junk intervals and non-map bodies yield nothing', () {
      expect(AniSkipClient.parseSkipTimes({'found': false, 'results': []}), isEmpty);
      expect(AniSkipClient.parseSkipTimes('x'), isEmpty);
      expect(
        AniSkipClient.parseSkipTimes({
          'found': true,
          'results': [
            'junk',
            {
              'interval': {'startTime': 5, 'endTime': 5},
              'skipType': 'op',
            },
            {
              'interval': {'startTime': -1, 'endTime': 10},
              'skipType': 'op',
            },
            {
              'interval': {'startTime': 0, 'endTime': 10},
              'skipType': 'unknown',
            },
          ],
        }),
        isEmpty,
      );
    });
  });

  group('failure modes stay silent', () {
    test('non-200 and timeouts return empty without throwing', () async {
      final failing = AniSkipClient(httpClient: MockClient((request) async => http.Response('nope', 500)));
      expect(await failing.fetchSkipTimes(malId: 1, episodeNumber: 1, episodeLengthSeconds: 1400), isEmpty);

      final hanging = AniSkipClient(
        httpClient: MockClient((request) async {
          await Completer<void>().future;
          return http.Response('', 200);
        }),
        timeout: const Duration(milliseconds: 20),
      );
      expect(await hanging.fetchSkipTimes(malId: 1, episodeNumber: 1, episodeLengthSeconds: 1400), isEmpty);
    });

    test('successful responses are cached per (malId, episode)', () async {
      var calls = 0;
      final client = AniSkipClient(
        httpClient: MockClient((request) async {
          calls++;
          return http.Response('{"found": true, "results": []}', 200);
        }),
      );
      await client.fetchSkipTimes(malId: 7, episodeNumber: 2, episodeLengthSeconds: 1400);
      await client.fetchSkipTimes(malId: 7, episodeNumber: 2, episodeLengthSeconds: 1400);
      await client.fetchSkipTimes(malId: 7, episodeNumber: 3, episodeLengthSeconds: 1400);
      expect(calls, 2);
    });
  });
}
