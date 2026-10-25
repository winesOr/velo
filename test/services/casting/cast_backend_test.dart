import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:plezy/database/app_database.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/services/casting/cast_media_resolver.dart';
import 'package:plezy/services/jellyfin_api_cache.dart';
import 'package:plezy/services/plex_api_cache.dart';

import '../../test_helpers/backend_client_fixtures.dart';
import '../../test_helpers/media_items.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    PlexApiCache.initialize(db);
    JellyfinApiCache.initialize(db);
  });
  tearDown(() => db.close());

  for (final emby in [false, true]) {
    test(
      '${emby ? 'Emby' : 'Jellyfin'} casts an authenticated exact-version static URL without a phone session',
      () async {
        final requests = <http.Request>[];
        const sources = [
          {'Id': 'source-a', 'Container': 'mkv', 'MediaStreams': <Object>[]},
          {'Id': 'source-b', 'Container': 'mp4', 'MediaStreams': <Object>[]},
        ];
        final connection = emby
            ? testEmbyConnection(accessToken: 'private-token')
            : testJellyfinConnection(accessToken: 'private-token');
        final client = testJellyfinClient(
          connection: connection,
          handler: (request) async {
            requests.add(request);
            return http.Response(
              jsonEncode(
                request.url.path.endsWith('/PlaybackInfo')
                    ? {'MediaSources': sources}
                    : {'Id': 'film', 'Type': 'Movie', 'MediaSources': sources},
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          },
        );
        addTearDown(client.close);
        final media = await const CastMediaResolver().resolve(
          client: client,
          item: testMediaItem(id: 'film', backend: emby ? MediaBackend.emby : MediaBackend.jellyfin),
          position: const Duration(seconds: 35),
          mediaIndex: 0,
          mediaSourceId: 'source-b',
        );
        expect(media.url.path, endsWith('/Videos/film/stream.mp4'));
        expect(media.url.queryParameters[connection.dialect.tokenQueryParam], 'private-token');
        expect(media.url.queryParameters['Static'], 'true');
        expect(media.url.queryParameters['MediaSourceId'], 'source-b');
        expect(media.url.queryParameters.containsKey('PlaySessionId'), isFalse);
        expect(requests.any((r) => r.url.path.contains('/Sessions/') || r.url.path.contains('/transcode/')), isFalse);
      },
    );
  }

  test('Plex preserves the stable media version and embeds token in the original file URL', () async {
    final requests = <http.Request>[];
    final client = testPlexClient(
      serverId: ServerId('server-id'),
      token: 'private-token',
      handler: (request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'MediaContainer': {
              'Metadata': [
                {
                  'ratingKey': '42',
                  'type': 'movie',
                  'title': 'Film',
                  'Media': [
                    {
                      'id': 100,
                      'container': 'mkv',
                      'Part': [
                        {'id': 99, 'key': '/library/parts/99/file.mkv', 'duration': 100000},
                      ],
                    },
                    {
                      'id': 200,
                      'container': 'mp4',
                      'Part': [
                        {'id': 199, 'key': '/library/parts/199/file.mp4', 'duration': 100000},
                      ],
                    },
                  ],
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      },
    );
    addTearDown(client.close);
    final media = await const CastMediaResolver().resolve(
      client: client,
      item: testMediaItem(id: '42', serverId: 'server-id'),
      position: const Duration(seconds: 30),
      mediaIndex: 0,
      mediaSourceId: '200',
    );
    expect(media.url.path, '/library/parts/199/file.mp4');
    expect(media.url.queryParameters['X-Plex-Token'], 'private-token');
    expect(requests.any((r) => r.url.path.contains('/transcode/')), isFalse);
  });
}
