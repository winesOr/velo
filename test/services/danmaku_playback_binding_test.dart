import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/danmaku/danmaku_comment.dart';
import 'package:plezy/danmaku/danmaku_session.dart';
import 'package:plezy/danmaku/danmaku_settings_repository.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/services/danmaku_playback_binding.dart';
import 'package:plezy/services/jellyfin_mappers.dart';

void main() {
  DanmakuSession makeSession() => DanmakuSession.forTesting(
    repository: DanmakuSettingsRepository(
      read: () async => null,
      write: (_) async {},
      protect: (value) async => value,
      reveal: (value) async => value,
    ),
  );

  final item = JellyfinMappers.mediaItem(
    {
      'Id': 'episode',
      'Type': 'Episode',
      'Name': 'Episode',
      'SeriesName': 'Series',
      'SeriesId': 'series',
      'ParentIndexNumber': 1,
      'IndexNumber': 2,
    },
    serverId: ServerId('server'),
    serverName: 'Server',
    absolutizer: null,
  )!;

  test('same item keeps local data; profile and item changes clear data', () async {
    final session = makeSession();
    await session.initialize();
    final binding = DanmakuPlaybackBinding(session: session);
    binding.bind(item, profileId: 'one');
    await Future<void>.delayed(Duration.zero);
    session.load(const [DanmakuComment(timeMs: 1000, text: 'local')], sourceLabel: 'local');
    binding.bind(item, profileId: 'one');
    expect(session.comments, hasLength(1));
    binding.bind(item, profileId: 'two');
    expect(session.comments, isEmpty);
    expect(session.mediaContext!.profileId, 'two');
    binding.dispose();
    expect(session.mediaContext, isNull);
  });

  test('retired route cannot clear successor or modify its duration', () async {
    final session = makeSession();
    await session.initialize();
    final first = DanmakuPlaybackBinding(session: session);
    final second = DanmakuPlaybackBinding(session: session);
    final durations = StreamController<Duration>.broadcast(sync: true);
    first.bind(item, profileId: 'one');
    first.listenToDuration(durations.stream);
    second.bind(item.copyWith(id: 'next'), profileId: 'one');
    await Future<void>.delayed(Duration.zero);
    session.load(const [DanmakuComment(timeMs: 1000, text: 'next')], sourceLabel: 'local');
    durations.add(const Duration(milliseconds: 100));
    expect(session.comments, hasLength(1));
    first.dispose();
    expect(session.mediaContext!.itemId, 'next');
    expect(session.comments, hasLength(1));
    second.dispose();
    await durations.close();
  });

  test('duration clips effective data and live transition clears comments', () async {
    final session = makeSession();
    await session.initialize();
    final binding = DanmakuPlaybackBinding(session: session);
    final durations = StreamController<Duration>.broadcast(sync: true);
    binding.bind(item, profileId: 'one');
    binding.listenToDuration(durations.stream);
    await Future<void>.delayed(Duration.zero);
    session.load(const [DanmakuComment(timeMs: 1000, text: 'one')], sourceLabel: 'local');
    durations.add(const Duration(milliseconds: 500));
    expect(session.comments, isEmpty);
    binding.bind(item, profileId: 'one', isLive: true);
    expect(session.mediaContext, isNull);
    binding.dispose();
    await durations.close();
  });
}
