import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/focusable_wrapper.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/play_queue.dart';
import 'package:plezy/mpv/mpv.dart';
import 'package:plezy/media/media_source_info.dart';
import 'package:plezy/providers/playback_state_provider.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/widgets/video_controls/sheets/queue_sheet.dart';
import 'package:plezy/widgets/video_controls/sheets/episodes_drawer.dart';
import 'package:plezy/widgets/video_controls/sheets/player_settings_controls.dart';
import 'package:plezy/widgets/video_controls/widgets/content_strip.dart';
import 'package:plezy/widgets/video_controls/widgets/media_selector_thumbnail.dart';
import 'package:provider/provider.dart';

import '../test_helpers/prefs.dart';
import '../test_helpers/media_items.dart';
import '../test_helpers/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
  });

  testWidgets('MediaSelectorThumbnail applies blur only to real thumbnails', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaSelectorThumbnail(
          width: 60,
          height: 34,
          thumbnail: ColoredBox(color: Colors.red),
          isCurrent: true,
          borderColor: Colors.white,
          blurThumbnail: true,
        ),
      ),
    );

    expect(find.byType(ImageFiltered), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaSelectorThumbnail(
          width: 60,
          height: 34,
          thumbnail: null,
          isCurrent: true,
          borderColor: Colors.white,
          blurThumbnail: true,
        ),
      ),
    );

    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('content strip queue blurs spoiler episode thumbnails', (tester) async {
    await SettingsService.instance.write(SettingsService.hideSpoilers, true);
    final playback = _playbackWithQueue();
    addTearDown(playback.dispose);

    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: ContentStrip(
          player: _FakePlayer(),
          chapters: const [],
          canControl: true,
          showQueueTab: true,
          onQueueItemSelected: (_) {},
        ),
      ),
    );
    await tester.pump();

    final thumbnails = tester.widgetList<MediaSelectorThumbnail>(find.byType(MediaSelectorThumbnail)).toList();

    expect(thumbnails.map((thumbnail) => thumbnail.blurThumbnail), [true, false, false]);
  });

  testWidgets('content strip falls back from chapters to a focusable queue', (tester) async {
    final playback = _playbackWithQueue();
    addTearDown(playback.dispose);
    final player = _FakePlayer();
    final stripKey = GlobalKey<ContentStripState>();
    final chapter = MediaChapter(id: 1, startTimeOffset: 10000, title: 'Old Chapter');
    MediaItem? selectedItem;

    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: ContentStrip(
          key: stripKey,
          player: player,
          chapters: [chapter],
          canControl: true,
          showQueueTab: true,
          onQueueItemSelected: (item) => selectedItem = item,
          useFocusNavigation: true,
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(find.text(t.videoControls.chapters), findsOneWidget);
    expect(find.text('Old Chapter'), findsOneWidget);
    expect(find.text('Spoiler Episode'), findsNothing);

    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: ContentStrip(
          key: stripKey,
          player: player,
          chapters: const [],
          canControl: true,
          showQueueTab: true,
          onQueueItemSelected: (item) => selectedItem = item,
          useFocusNavigation: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text(t.videoControls.queue), findsOneWidget);
    expect(find.text('Spoiler Episode'), findsOneWidget);
    expect(find.text('Old Chapter'), findsNothing);

    stripKey.currentState!.requestInitialFocus();
    await tester.pump();
    final firstQueueItem = tester.widget<FocusableWrapper>(
      find.ancestor(of: find.text('Spoiler Episode'), matching: find.byType(FocusableWrapper)),
    );
    expect(firstQueueItem.focusNode!.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selectedItem?.id, 'spoiler-episode');
  });

  testWidgets('content strip preserves queue selection until only chapters remain', (tester) async {
    final playback = _playbackWithQueue();
    addTearDown(playback.dispose);
    final player = _FakePlayer();
    final stripKey = GlobalKey<ContentStripState>();
    final initialChapter = MediaChapter(id: 1, startTimeOffset: 10000, title: 'Initial Chapter');
    final replacementChapter = MediaChapter(id: 2, startTimeOffset: 20000, title: 'Replacement Chapter');

    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: ContentStrip(
          key: stripKey,
          player: player,
          chapters: [initialChapter],
          canControl: true,
          showQueueTab: true,
          onQueueItemSelected: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(t.videoControls.queue));
    await tester.pump();
    expect(find.text('Spoiler Episode'), findsOneWidget);
    expect(find.text('Initial Chapter'), findsNothing);

    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: ContentStrip(
          key: stripKey,
          player: player,
          chapters: [replacementChapter],
          canControl: true,
          showQueueTab: true,
          onQueueItemSelected: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Spoiler Episode'), findsOneWidget);
    expect(find.text('Replacement Chapter'), findsNothing);

    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: ContentStrip(
          key: stripKey,
          player: player,
          chapters: [replacementChapter],
          canControl: true,
          showQueueTab: false,
          onQueueItemSelected: null,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Replacement Chapter'), findsOneWidget);
    expect(find.text('Spoiler Episode'), findsNothing);
    await tester.tap(find.text('Replacement Chapter'));
    await tester.pump();
    expect(player.seeks, [const Duration(seconds: 20)]);
  });

  testWidgets('denied chapter remains visible but touch and select do not seek', (tester) async {
    final playback = PlaybackStateProvider();
    addTearDown(playback.dispose);
    final player = _FakePlayer();
    final stripKey = GlobalKey<ContentStripState>();
    final chapter = MediaChapter(id: 1, startTimeOffset: 10000, title: 'Chapter One');

    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: ContentStrip(
          key: stripKey,
          player: player,
          chapters: [chapter],
          canControl: false,
          useFocusNavigation: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Chapter One'), findsOneWidget);
    await tester.tap(find.text('Chapter One'));
    stripKey.currentState!.requestInitialFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(player.seeks, isEmpty);
  });

  testWidgets('authorized chapter touch seeks exactly once', (tester) async {
    final playback = PlaybackStateProvider();
    addTearDown(playback.dispose);
    final player = _FakePlayer();
    final chapter = MediaChapter(id: 1, startTimeOffset: 10000, title: 'Chapter One');

    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: ContentStrip(player: player, chapters: [chapter], canControl: true),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Chapter One'));
    await tester.pump();
    expect(player.seeks, [const Duration(seconds: 10)]);
  });

  testWidgets('missing authorized queue callback keeps queue items non-interactive', (tester) async {
    final playback = _playbackWithQueue();
    addTearDown(playback.dispose);

    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: ContentStrip(
          player: _FakePlayer(),
          chapters: const [],
          canControl: true,
          showQueueTab: true,
          onQueueItemSelected: null,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Spoiler Episode'), findsNothing);
  });

  testWidgets('playlist drawer keeps duplicate queue identities and waits for selection', (tester) async {
    final current = testMediaItem(id: 'duplicate', title: 'Current movie');
    final next = testMediaItem(id: 'duplicate', title: 'Next copy');
    final playback = PlaybackStateProvider()
      ..setPlaybackFromLocalQueue(LocalPlayQueue(items: [current, next], currentIndex: 0), contextKey: 'playlist');
    addTearDown(playback.dispose);
    final result = Completer<bool>();
    final selected = <MediaItem>[];
    var shuffleCalls = 0;
    Completer<void>? shuffleGate;
    final authorized = ValueNotifier(true);
    addTearDown(authorized.dispose);
    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: ValueListenableBuilder<bool>(
          valueListenable: authorized,
          builder: (context, allowed, _) => EpisodesDrawer(
            current: current,
            offline: true,
            canNavigate: true,
            onSelect: (item) {
              selected.add(item);
              return result.future;
            },
            isAuthorized: () => allowed,
            onRepeat: (mode) async => playback.setRepeatMode(mode),
            onShuffle: (enabled, isCurrent) async {
              shuffleCalls++;
              if (shuffleGate != null) await shuffleGate.future;
              return playback.setShuffleEnabled(enabled, isCurrent: isCurrent);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.videoControls.playlistDrawer), findsOneWidget);
    await tester.tap(find.text(t.videoControls.repeatOff));
    await tester.pumpAndSettle();
    expect(playback.repeatMode, VideoQueueRepeatMode.all);
    await tester.tap(find.text(t.common.shuffle));
    await tester.pumpAndSettle();
    expect(shuffleCalls, 1);
    expect(playback.isShuffleActive, isTrue);
    shuffleGate = Completer<void>();
    await tester.tap(find.text(t.common.shuffle));
    await tester.pump();
    authorized.value = false;
    await tester.pump();
    shuffleGate.complete();
    await tester.pumpAndSettle();
    expect(shuffleCalls, 2);
    expect(playback.isShuffleActive, isTrue, reason: 'revoked authority cancels the pending change');
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, t.videoControls.repeatAll)).onPressed, isNull);
    authorized.value = true;
    await tester.pump();
    await tester.tap(find.text('Next copy'));
    await tester.pump();
    await tester.tap(find.text('Next copy'));
    expect(selected, [same(next)]);
    result.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Next copy'), findsOneWidget);
    final replacement = testMediaItem(id: 'replacement', title: 'Replacement queue');
    playback.setPlaybackFromLocalQueue(LocalPlayQueue(items: [replacement], currentIndex: 0), contextKey: 'new');
    await tester.pumpAndSettle();
    expect(find.text('Next copy'), findsNothing);
    expect(find.text('Replacement queue'), findsOneWidget);

    final episodes = List.generate(
      24,
      (index) => testMediaItem(
        id: 'episode-$index',
        kind: MediaKind.episode,
        title: 'Episode $index',
        parentId: 'season',
        grandparentId: 'show',
        index: index + 1,
      ),
    );
    final episodeQueue = PlaybackStateProvider()
      ..setPlaybackFromLocalQueue(LocalPlayQueue(items: episodes, currentIndex: 20), contextKey: 'show');
    addTearDown(episodeQueue.dispose);
    await tester.pumpWidget(
      _queueHarness(
        playback: episodeQueue,
        child: EpisodesDrawer(
          current: episodes[20],
          offline: true,
          canNavigate: true,
          onSelect: (_) async => false,
          isAuthorized: () => true,
          onRepeat: (mode) async => episodeQueue.setRepeatMode(mode),
          onShuffle: (enabled, isCurrent) => episodeQueue.setShuffleEnabled(enabled, isCurrent: isCurrent),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.videoControls.episodesButton), findsOneWidget);
    expect(find.text('Episode 21 · Episode 20'), findsOneWidget);
  });

  for (final hasMediaSelection in [true, false]) {
    testWidgets('chapter tab stays reachable with media selection $hasMediaSelection', (tester) async {
      final current = testMediaItem(id: 'chapter-movie', title: 'Chapter movie');
      final playback = PlaybackStateProvider();
      addTearDown(playback.dispose);
      await tester.pumpWidget(
        _queueHarness(
          playback: playback,
          child: EpisodesDrawer(
            current: current,
            offline: true,
            canNavigate: false,
            hasMediaSelection: hasMediaSelection,
            chapters: const Text('Chapter controls'),
            onSelect: (_) async => false,
            isAuthorized: () => false,
            onRepeat: (_) async => false,
            onShuffle: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlayerDrawerChoice), findsNWidgets(hasMediaSelection ? 2 : 1));
      if (hasMediaSelection) {
        expect(find.text('Chapter controls'), findsNothing);
        await tester.tap(find.widgetWithText(PlayerDrawerChoice, t.videoControls.chapters));
        await tester.pumpAndSettle();
      }
      expect(find.text('Chapter controls'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (hasMediaSelection) {
        await tester.tap(find.widgetWithText(PlayerDrawerChoice, t.videoControls.playlistDrawer));
        await tester.pumpAndSettle();
        expect(find.text('Chapter controls'), findsNothing);
        expect(find.text('Chapter movie'), findsOneWidget);
      }
    });
  }

  testWidgets('queue sheet blurs spoiler episode thumbnails', (tester) async {
    await SettingsService.instance.write(SettingsService.hideSpoilers, true);
    final playback = _playbackWithQueue();
    addTearDown(playback.dispose);

    await tester.pumpWidget(
      _queueHarness(
        playback: playback,
        child: QueueSheet(onItemSelected: (_) {}),
      ),
    );
    await tester.pump();

    final thumbnails = tester.widgetList<MediaSelectorThumbnail>(find.byType(MediaSelectorThumbnail)).toList();

    expect(thumbnails.map((thumbnail) => thumbnail.blurThumbnail), [true, false, false]);
  });
}

Widget _queueHarness({required PlaybackStateProvider playback, required Widget child}) {
  return ChangeNotifierProvider<PlaybackStateProvider>.value(
    value: playback,
    child: InputModeTracker(
      child: MaterialApp(
        theme: ThemeData(extensions: const [testMonoTokens]),
        home: Scaffold(body: SizedBox(width: 600, height: 400, child: child)),
      ),
    ),
  );
}

PlaybackStateProvider _playbackWithQueue() {
  final playback = PlaybackStateProvider();
  playback.setPlaybackFromLocalQueue(
    LocalPlayQueue(
      currentIndex: 0,
      items: [
        _episode('spoiler-episode', title: 'Spoiler Episode'),
        _episode('watched-episode', title: 'Watched Episode', viewCount: 1),
        testMediaItem(
          id: 'movie',
          backend: MediaBackend.plex,
          kind: MediaKind.movie,
          title: 'Movie',
          thumbPath: 'https://example.invalid/movie.jpg',
        ),
      ],
    ),
  );
  return playback;
}

MediaItem _episode(String id, {required String title, int? viewCount}) {
  return testMediaItem(
    id: id,
    backend: MediaBackend.plex,
    kind: MediaKind.episode,
    title: title,
    grandparentTitle: 'Show',
    parentIndex: 1,
    index: 1,
    viewCount: viewCount,
    thumbPath: 'https://example.invalid/$id.jpg',
  );
}

class _FakePlayer implements Player {
  final List<Duration> seeks = [];

  @override
  PlayerState get state => PlayerState(duration: const Duration(minutes: 30));

  @override
  PlayerStreams get streams => const PlayerStreams(
    playing: Stream<bool>.empty(),
    completed: Stream<bool>.empty(),
    buffering: Stream<bool>.empty(),
    position: Stream<Duration>.empty(),
    duration: Stream<Duration>.empty(),
    seekable: Stream<bool>.empty(),
    buffer: Stream<Duration>.empty(),
    volume: Stream<double>.empty(),
    rate: Stream<double>.empty(),
    tracks: Stream<Tracks>.empty(),
    track: Stream<TrackSelection>.empty(),
    log: Stream<PlayerLog>.empty(),
    error: Stream<PlayerError>.empty(),
    audioDevice: Stream<AudioDevice>.empty(),
    audioDevices: Stream<List<AudioDevice>>.empty(),
    bufferRanges: Stream<List<BufferRange>>.empty(),
    playbackRestart: Stream<void>.empty(),
    backendSwitched: Stream<void>.empty(),
  );

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
