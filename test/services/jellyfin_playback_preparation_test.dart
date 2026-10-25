import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:plezy/database/app_database.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/models/transcode_quality_preset.dart';
import 'package:plezy/services/jellyfin_api_cache.dart';
import 'package:plezy/services/playback_initialization_types.dart';
import 'package:plezy/services/plex_api_cache.dart';

import '../test_helpers/backend_client_fixtures.dart';
import '../test_helpers/media_items.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    PlexApiCache.initialize(db);
    JellyfinApiCache.initialize(db);
  });
  tearDown(() => db.close());

  const sources = [
    {'Id': 'a', 'Container': 'mkv', 'MediaStreams': <Object>[]},
    {'Id': 'b', 'Container': 'mp4', 'MediaStreams': <Object>[]},
  ];
  final item = testMediaItem(id: 'film', kind: MediaKind.movie);
  PlaybackInitializationOptions options({String? source, int? audio, TranscodeQualityPreset? quality}) =>
      PlaybackInitializationOptions(
        metadata: item,
        selectedMediaIndex: 0,
        selectedMediaSourceId: source,
        selectedAudioStreamId: audio,
        qualityPreset: quality ?? TranscodeQualityPreset.original,
      );
  http.Response json(Object value, [int status = 200]) =>
      http.Response(jsonEncode(value), status, headers: {'content-type': 'application/json'});

  for (final emby in [false, true]) {
    test('${emby ? 'Emby' : 'Jellyfin'} consumes prepared original negotiation only once', () async {
      var negotiations = 0;
      final client = testJellyfinClient(
        connection: emby ? testEmbyConnection() : testJellyfinConnection(),
        handler: (request) async {
          if (request.url.path.endsWith('/PlaybackInfo')) {
            negotiations++;
            if (negotiations == 1) {
              expect(jsonDecode(request.body)['AutoOpenLiveStream'], isFalse);
            }
            return json({'MediaSources': sources});
          }
          return json({'Id': 'film', 'Type': 'Movie', 'MediaSources': sources});
        },
      );
      addTearDown(client.close);
      await client.preparePlaybackInitialization(options());
      final result = await client.getPlaybackInitialization(options());
      expect(result.videoUrl, contains('/Videos/film/stream'));
      expect(negotiations, 1);
      await client.getPlaybackInitialization(options());
      expect(negotiations, 2);
    });
  }

  test('play can share in-flight preparation without a duplicate POST', () async {
    final requested = Completer<void>();
    final response = Completer<http.Response>();
    var posts = 0;
    final client = testJellyfinClient(
      handler: (request) async {
        if (request.url.path.endsWith('/PlaybackInfo')) {
          posts++;
          requested.complete();
          return response.future;
        }
        return json({'Id': 'film', 'Type': 'Movie', 'MediaSources': sources});
      },
    );
    addTearDown(client.close);
    final warm = client.preparePlaybackInitialization(options());
    await requested.future;
    final play = client.getPlaybackInitialization(options());
    response.complete(json({'MediaSources': sources}));
    await warm;
    await play;
    expect(posts, 1);
  });

  test('source and audio changes miss; capped quality is not speculated', () async {
    var posts = 0;
    final client = testJellyfinClient(
      handler: (request) async {
        if (request.url.path.endsWith('/PlaybackInfo')) {
          posts++;
          return json({'MediaSources': sources});
        }
        return json({'Id': 'film', 'Type': 'Movie', 'MediaSources': sources});
      },
    );
    addTearDown(client.close);
    await client.preparePlaybackInitialization(options(source: 'a'));
    await client.getPlaybackInitialization(options(source: 'b'));
    expect(posts, 2);
    await client.getPlaybackInitialization(options(source: 'a', audio: 2));
    expect(posts, 3);
    await client.preparePlaybackInitialization(options(quality: TranscodeQualityPreset.p1080_8mbps));
    expect(posts, 3);
  });

  test('failed speculative authorization is not cached or silently accepted', () async {
    var posts = 0;
    final client = testJellyfinClient(
      handler: (request) async {
        if (request.url.path.endsWith('/PlaybackInfo')) {
          posts++;
          return json({}, 401);
        }
        return json({'Id': 'film', 'Type': 'Movie', 'MediaSources': sources});
      },
    );
    addTearDown(client.close);
    await client.preparePlaybackInitialization(options());
    await expectLater(client.getPlaybackInitialization(options()), throwsA(isA<PlaybackException>()));
    expect(posts, 2);
  });

  test('Play retries through its own path when an in-flight negotiation rejects preparation', () async {
    final requested = Completer<void>();
    final response = Completer<http.Response>();
    var posts = 0;
    final client = testJellyfinClient(
      handler: (request) async {
        if (request.url.path.endsWith('/PlaybackInfo')) {
          posts++;
          if (posts == 1) {
            requested.complete();
            return response.future;
          }
          return json({'MediaSources': sources});
        }
        return json({'Id': 'film', 'Type': 'Movie', 'MediaSources': sources});
      },
    );
    addTearDown(client.close);
    final warm = client.preparePlaybackInitialization(options());
    await requested.future;
    final play = client.getPlaybackInitialization(options());
    response.complete(
      json({
        'MediaSources': [
          {...sources.first, 'RequiresOpening': true},
        ],
      }),
    );
    await warm;
    expect((await play).videoUrl, isNotNull);
    expect(posts, 2);
  });

  test('prepared results do not cross client, account or endpoint boundaries', () async {
    var firstPosts = 0;
    var secondPosts = 0;
    final first = testJellyfinClient(
      handler: (request) async {
        if (request.url.path.endsWith('/PlaybackInfo')) {
          firstPosts++;
          return json({'MediaSources': sources});
        }
        return json({'Id': 'film', 'Type': 'Movie', 'MediaSources': sources});
      },
    );
    final second = testJellyfinClient(
      connection: testJellyfinConnection(
        userId: 'other-user',
        accessToken: 'other-token',
        baseUrl: 'https://other.example',
      ),
      handler: (request) async {
        if (request.url.path.endsWith('/PlaybackInfo')) {
          secondPosts++;
          return json({'MediaSources': sources});
        }
        return json({'Id': 'film', 'Type': 'Movie', 'MediaSources': sources});
      },
    );
    addTearDown(first.close);
    addTearDown(second.close);
    await first.preparePlaybackInitialization(options());
    final result = await second.getPlaybackInitialization(options());
    expect(result.videoUrl, startsWith('https://other.example/'));
    expect(firstPosts, 1);
    expect(secondPosts, 1);
  });
}
