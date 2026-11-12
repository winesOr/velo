import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/media/server_capabilities.dart';
import 'package:plezy/models/transcode_quality_preset.dart';
import 'package:plezy/mpv/mpv.dart';
import 'package:plezy/providers/account_preferences_controller.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/providers/playback_state_provider.dart';
import 'package:plezy/screens/video_player_screen.dart';
import 'package:plezy/services/download_storage_service.dart';
import 'package:plezy/services/episode_navigation_service.dart';
import 'package:plezy/services/music/music_playback_service.dart';
import 'package:plezy/services/offline_watch_sync_service.dart';
import 'package:plezy/services/playback_coordinator.dart';
import 'package:plezy/services/playback_initialization_types.dart';
import 'package:plezy/services/playback_launch_observer.dart';
import 'package:plezy/services/pip_service.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/utils/video_player_navigation.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/io_fakes.dart';
import '../../test_helpers/media_items.dart';
import '../../test_helpers/mock_player_channels.dart';
import '../../test_helpers/multi_server_fixtures.dart';
import '../../test_helpers/playback_report_fakes.dart';
import '../../test_helpers/prefs.dart';
import '../../test_helpers/stub_music_playback_service.dart';
import '../../test_helpers/watch_together_fakes.dart';

// The screen's route-global wakelock queue must stay on one FakeAsync clock.
// Keep every lifecycle transition in this one test, in its own test isolate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpRoot;
  late PathProviderPlatform previousPathProvider;
  late AppDatabase db;

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    DownloadStorageService.resetForTesting();
    await SettingsService.getInstance();
    tmpRoot = await Directory.systemTemp.createTemp('playback_wakelock_lifecycle_test_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProvider(tmpRoot);
    await DownloadStorageService.instance.initialize(SettingsService.instance);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    DownloadStorageService.resetForTesting();
    SettingsService.resetForTesting();
    PathProviderPlatform.instance = previousPathProvider;
    if (await tmpRoot.exists()) await tmpRoot.delete(recursive: true);
  });

  testWidgets('EOF resets restore active playback but never wake paused media or a closed route', (tester) async {
    final observer = PlaybackLaunchObserver(isCurrent: () => true);
    final fakePlayer = _ObservedPlayer();
    final toggles = <bool>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(_wakelockToggleChannel, (message) async {
      final args = _wakelockCodec.decodeMessage(message) as List<Object?>;
      toggles.add((args.single! as List<Object?>).single! as bool);
      return _wakelockCodec.encodeMessage(<Object?>[]);
    });
    addTearDown(() => messenger.setMockMessageHandler(_wakelockToggleChannel, null));
    await SettingsService.instance.write(SettingsService.autoPlayNextEpisode, false);

    await withMockPlayerChannels(
      methodChannelName: 'com.plezy/mpv_player',
      eventChannelName: 'com.plezy/mpv_player/events',
      testBody: () async {
        final screen = await _pushObservedScreen(tester, db: db, fakePlayer: fakePlayer, observer: observer);
        screen.key.currentState!.debugCommitAdjacentEpisodesForTesting(
          AdjacentEpisodes(
            next: testMediaItem(id: 'next', serverId: 'srv-1', backend: MediaBackend.jellyfin),
            nextStatus: QueueNavigationStatus.found,
            previousStatus: QueueNavigationStatus.boundary,
          ),
        );
        fakePlayer.emitPlaying(false);
        await tester.pump();
        fakePlayer.emitPlaying(true);
        await tester.pump();
        expect(toggles, isNotEmpty);
        expect(toggles.last, isTrue);

        fakePlayer.setPosition(fakePlayer.state.duration);
        fakePlayer.emitCompleted(true);
        await tester.pump();
        expect(toggles.last, isFalse);
        final releasedCallCount = toggles.length;

        // A spurious reset at EOF must not light a parked completion prompt.
        fakePlayer.emitCompleted(false);
        await tester.pump();
        expect(toggles.length, releasedCallCount);

        // mpv clears EOF on a seek without emitting another playing event.
        fakePlayer.setPosition(const Duration(minutes: 2));
        fakePlayer.emitCompleted(false);
        await tester.pump();
        expect(toggles.last, isTrue);
        expect(toggles.length, releasedCallCount + 1);

        fakePlayer.emitPlaying(false);
        await tester.pump();
        expect(toggles.last, isFalse);
        final pausedCallCount = toggles.length;
        fakePlayer.setPosition(fakePlayer.state.duration);
        fakePlayer.emitCompleted(true);
        await tester.pump();
        fakePlayer.setPosition(const Duration(minutes: 2));
        fakePlayer.emitCompleted(false);
        await tester.pump();
        expect(toggles.last, isFalse);
        expect(toggles.length, pausedCallCount, reason: 'a paused seek must not reacquire the lock');

        // Exo reports isPlaying=false during buffering. Only the independent
        // native intent tells that apart from pressing Pause while buffering.
        fakePlayer.emitBuffering(true);
        fakePlayer.emitActivity(PlayerPlaybackPhase.buffering, true);
        await tester.pump();
        expect(fakePlayer.state.playing, isFalse);
        expect(toggles.last, isTrue);
        fakePlayer.emitActivity(PlayerPlaybackPhase.buffering, false);
        await tester.pump();
        expect(toggles.last, isFalse, reason: 'pausing buffering must release without another playing event');
        fakePlayer.emitActivity(PlayerPlaybackPhase.buffering, true);
        await tester.pump();
        expect(toggles.last, isTrue);

        screen.key.currentState!.debugAttachPipStateListenerForTesting();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(toggles.last, isFalse);
        final backgroundCallCount = toggles.length;
        fakePlayer.emitPlaying(true);
        fakePlayer.emitActivity(PlayerPlaybackPhase.ready, true);
        fakePlayer.emitCompleted(false);
        await tester.pump();
        expect(toggles.length, backgroundCallCount, reason: 'late playback events cannot wake an ordinary background');

        PipService().isPipActive.value = true;
        await tester.pump();
        expect(toggles.last, isTrue, reason: 'a visible PiP window can retain playback intent');
        PipService().isPipActive.value = false;
        await tester.pump();
        expect(toggles.last, isFalse, reason: 'leaving PiP while backgrounded releases immediately');

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(toggles.last, isTrue);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
        await tester.pump();
        expect(toggles.last, isFalse);
        fakePlayer.emitActivity(PlayerPlaybackPhase.buffering, true);
        await tester.pump();
        expect(toggles.last, isFalse);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(toggles.last, isTrue, reason: 'returning while buffering restores the requested lock');

        fakePlayer.emitError(const PlayerError('terminal playback failure'));
        await tester.pump();
        expect(toggles.last, isFalse);
        final failureCallCount = toggles.length;
        fakePlayer.emitPlaying(true);
        fakePlayer.emitActivity(PlayerPlaybackPhase.ready, true);
        fakePlayer.emitCompleted(false);
        await tester.pump();
        expect(toggles.length, failureCallCount, reason: 'late native callbacks cannot wake the failure surface');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(toggles.last, isFalse);
        final teardownCallCount = toggles.length;
        await tester.pump(const Duration(seconds: 6));
        expect(toggles.length, teardownCallCount, reason: 'teardown must cancel every pending refresh');
      },
    );
  });
}

Future<({GlobalKey<VideoPlayerScreenState> key, GlobalKey<NavigatorState> navigator})> _pushObservedScreen(
  WidgetTester tester, {
  required AppDatabase db,
  required _ObservedPlayer fakePlayer,
  required PlaybackLaunchObserver observer,
}) async {
  final client = _ObservedClient();
  final multi = testMultiServer(clients: [client]);
  final offlineWatch = OfflineWatchSyncService(database: db, serverManager: multi.manager);
  final accountPreferences = AccountPreferencesController();
  final initializationHold = Completer<void>();
  Future<void> holdInitialization() => initializationHold.future;
  PlaybackCoordinator.instance.registerMusicSession(stopAndDispose: holdInitialization);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    PlaybackCoordinator.instance.unregisterMusicSession(holdInitialization);
    initializationHold.complete();
    await tester.pump();
    offlineWatch.dispose();
    accountPreferences.dispose();
    await fakePlayer.dispose();
  });
  final navigator = GlobalKey<NavigatorState>();
  final key = GlobalKey<VideoPlayerScreenState>();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlaybackStateProvider()),
        ChangeNotifierProvider<MultiServerProvider>.value(value: multi.provider),
        ChangeNotifierProvider<OfflineWatchSyncService>.value(value: offlineWatch),
        ChangeNotifierProvider<AccountPreferencesController>.value(value: accountPreferences),
        ChangeNotifierProvider<MusicPlaybackService>(create: (_) => StubMusicPlaybackService()),
        Provider<AppDatabase>.value(value: db),
      ],
      child: MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Browse')),
      ),
    ),
  );
  unawaited(
    VideoPlayerRoute(
      builder: (_) => VideoPlayerScreen(
        key: key,
        metadata: testMediaItem(id: 'observed', serverId: 'srv-1', backend: MediaBackend.jellyfin),
        selectedQualityPreset: TranscodeQualityPreset.original,
        selectedAudioStreamId: 1,
        launchObserver: observer,
      ),
    ).push(navigator.currentState!),
  );
  await tester.pump();
  key.currentState!.player = fakePlayer;
  await key.currentState!.debugWirePlayerStreamsForTesting();
  fakePlayer.emitPlaybackRestart();
  await tester.pump();
  return (key: key, navigator: navigator);
}

const _wakelockToggleChannel = 'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
const _wakelockCodec = _WakelockTestCodec();

class _WakelockTestCodec extends StandardMessageCodec {
  const _WakelockTestCodec();

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) =>
      type >= 128 ? readValue(buffer) : super.readValueOfType(type, buffer);
}

class _ObservedPlayer extends FakeSyncPlayer {
  _ObservedPlayer()
    : super(playing: true, position: const Duration(seconds: 121), duration: const Duration(minutes: 40));

  int openCalls = 0;
  final _completedController = StreamController<bool>.broadcast();
  final _errorController = StreamController<PlayerError>.broadcast();
  final _activityController = StreamController<PlayerPlaybackActivity?>.broadcast();
  PlayerPlaybackActivity? _activity;

  @override
  PlayerState get state => super.state.copyWith(playbackActivity: _activity, clearPlaybackActivity: _activity == null);

  void emitActivity(PlayerPlaybackPhase phase, bool requested) {
    _activity = PlayerPlaybackActivity(phase: phase, playWhenReady: requested);
    _activityController.add(_activity);
  }

  void emitCompleted(bool value) {
    setCompleted(value);
    _completedController.add(value);
  }

  /// The backend gave up on the file (mpv `end-file reason=error`).
  void emitError(PlayerError error) => _errorController.add(error);

  @override
  PlayerStreams get streams {
    final base = super.streams;
    return PlayerStreams(
      playing: base.playing,
      completed: _completedController.stream,
      buffering: base.buffering,
      playbackActivity: _activityController.stream,
      position: base.position,
      duration: base.duration,
      seekable: base.seekable,
      buffer: base.buffer,
      volume: base.volume,
      rate: base.rate,
      tracks: base.tracks,
      track: base.track,
      log: base.log,
      error: _errorController.stream,
      audioDevice: base.audioDevice,
      audioDevices: base.audioDevices,
      bufferRanges: base.bufferRanges,
      playbackRestart: base.playbackRestart,
      fileStarted: base.fileStarted,
      backendSwitched: base.backendSwitched,
    );
  }

  @override
  Future<void> stop() async {
    setPosition(Duration.zero);
    emitPlaying(false);
  }

  @override
  bool get needsDecoderRefreshAfterDisplaySwitch => false;

  @override
  Future<String?> getProperty(String name) async => null;

  @override
  Future<void> updateFrame() async {}

  @override
  Future<void> awaitDisplayModeSwitch({int extraDelayMs = 0}) async {}

  @override
  Future<bool> requestAudioFocus() async => true;

  @override
  Future<void> open(
    Media media, {
    bool play = true,
    bool isLive = false,
    List<SubtitleTrack>? externalSubtitles,
    Duration? timelineDuration,
    Duration timelineOffset = Duration.zero,
  }) async {
    openCalls++;
    setPosition(media.start ?? Duration.zero);
    emitCompleted(false);
    emitPlaying(play);
    emitFileStarted();
    emitPlaybackRestart();
  }

  @override
  Future<void> selectSubtitleTrack(SubtitleTrack track) async {}

  @override
  Future<void> dispose({bool preserveDisplayMode = false}) async {
    if (disposed) return;
    await super.dispose(preserveDisplayMode: preserveDisplayMode);
    await _completedController.close();
    await _errorController.close();
    await _activityController.close();
  }
}

class _ObservedClient with PlaybackReportRecorder implements MediaServerClient {
  @override
  ServerId get serverId => ServerId('srv-1');
  @override
  String get serverName => 'Server';
  @override
  MediaBackend get backend => MediaBackend.jellyfin;
  @override
  ServerCapabilities get capabilities => ServerCapabilities.jellyfin;
  @override
  double get watchedThreshold => 0.9;
  @override
  bool get marksWatchedOnPlaybackStopped => true;
  @override
  Map<String, String> get streamHeaders => const {};

  @override
  Future<MediaItem?> fetchItem(String itemId) async =>
      testMediaItem(id: itemId, serverId: 'srv-1', backend: MediaBackend.jellyfin);

  @override
  Future<PlaybackInitializationResult> getPlaybackInitialization(PlaybackInitializationOptions options) async =>
      PlaybackInitializationResult(
        availableVersions: const [],
        videoUrl: 'https://example.invalid/${options.metadata.id}',
      );

  @override
  Future<void> onPlaybackReport(PlaybackReportCall call) async {}

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
