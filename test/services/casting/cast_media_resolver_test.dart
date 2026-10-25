import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_part.dart';
import 'package:plezy/media/media_part_timeline.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/services/casting/cast_handoff.dart';
import 'package:plezy/services/casting/cast_media_resolver.dart';
import 'package:plezy/services/casting/dlna_http.dart';
import 'package:plezy/services/casting/dlna_sender.dart';
import 'package:plezy/services/playback_initialization_types.dart';

import '../../test_helpers/media_items.dart';

class _Client implements MediaServerClient {
  _Client(this.target);
  final ExternalPlaybackTarget? target;
  int? index;
  String? source;
  Duration? offset;

  @override
  Future<ExternalPlaybackTarget?> resolveExternalPlayback(
    MediaItem item, {
    int mediaIndex = 0,
    String? mediaSourceId,
    Duration? position,
  }) async {
    index = mediaIndex;
    source = mediaSourceId;
    offset = position;
    return target;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final item = testMediaItem(title: 'Movie', durationMs: 600000);
  const position = Duration(minutes: 4);
  const url = 'https://server.test/prefix/Videos/film/stream.mkv?Static=true&api_key=secret';

  test('resolves independent server URL with auth, exact version and current position', () async {
    final client = _Client(const ExternalPlaybackTarget(url: url));
    final media = await const CastMediaResolver().resolve(
      client: client,
      item: item,
      position: position,
      mediaIndex: 2,
      mediaSourceId: 'stable-source',
    );
    expect(media.url.toString(), url);
    expect(media.position, position);
    expect(media.mimeType, 'video/x-matroska');
    expect(client.index, 2);
    expect(client.source, 'stable-source');
    expect(client.offset, position);
  });

  for (final url in [
    'file:///movie.mkv',
    'content://downloads/movie',
    'http://localhost/movie',
    'http://127.0.0.1/movie',
    'http://127.2.3.4/movie',
    'http://[::1]/movie',
    'http://0.0.0.0/movie',
    'http://server.test/movie.iso',
    'http://server.test/movie.m3u8',
    'http://server.test/video/:/transcode/universal/start.mp4',
    'http://user:password@server.test/movie.mkv',
  ]) {
    test('rejects non-independent source $url', () {
      expect(isIndependentCastUrl(Uri.parse(url)), isFalse);
    });
  }

  test('refuses a multi-file movie that cannot continue after the phone exits', () async {
    final timeline = MediaPartTimeline.fromParts(const [
      MediaPart(id: '1', durationMs: 10000),
      MediaPart(id: '2', durationMs: 10000),
    ]);
    expect(timeline, isNotNull);
    final client = _Client(ExternalPlaybackTarget(url: url, partTimeline: timeline));
    await expectLater(
      const CastMediaResolver().resolve(client: client, item: item, position: position),
      throwsA(isA<DlnaException>()),
    );
  });

  for (final wasPlaying in [false, true]) {
    test('known failure restores only previously playing phone ($wasPlaying)', () async {
      final commands = <String>[];
      await expectLater(
        const CastHandoff().run(
          wasPlaying: wasPlaying,
          pause: () async {
            commands.add('pause');
          },
          resume: () async {
            commands.add('resume');
          },
          resolve: () async => throw const DlnaException(DlnaFailure.unsupportedSource),
          send: (_) async => const DlnaHandoffResult(resumeAccepted: true),
        ),
        throwsA(isA<DlnaException>()),
      );
      expect(commands, wasPlaying ? ['pause', 'resume'] : ['pause']);
    });
  }

  test('successful handoff leaves phone paused and uncertain playback does not auto-resume', () async {
    for (final uncertain in [false, true]) {
      final commands = <String>[];
      final operation = const CastHandoff().run(
        wasPlaying: true,
        pause: () async {
          commands.add('pause');
        },
        resume: () async {
          commands.add('resume');
        },
        resolve: () async => DlnaMedia(url: Uri.parse(url), title: 'Movie', position: position),
        send: (_) async {
          if (uncertain) throw const DlnaException(DlnaFailure.unconfirmed, mayBePlaying: true);
          return const DlnaHandoffResult(resumeAccepted: true);
        },
      );
      if (uncertain) {
        await expectLater(operation, throwsA(isA<DlnaException>()));
      } else {
        await operation;
      }
      expect(commands, ['pause']);
    }
  });
}
