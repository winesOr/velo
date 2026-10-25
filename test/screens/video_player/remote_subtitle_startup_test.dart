import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/media/media_source_info.dart';
import 'package:plezy/media/server_capabilities.dart';
import 'package:plezy/models/transcode_quality_preset.dart';
import 'package:plezy/mpv/player/player_base.dart';
import 'package:plezy/mpv/models.dart';
import 'package:plezy/services/remote_subtitle_loader.dart';
import 'package:plezy/providers/account_preferences_controller.dart';
import 'package:plezy/providers/companion_remote_provider.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/providers/playback_state_provider.dart';
import 'package:plezy/providers/shader_provider.dart';
import 'package:plezy/screens/video_player/widgets/player_prompt_overlays.dart';
import 'package:plezy/screens/video_player_screen.dart';
import 'package:plezy/services/download_storage_service.dart';
import 'package:plezy/services/music/music_playback_service.dart';
import 'package:plezy/services/offline_watch_sync_service.dart';
import 'package:plezy/services/playback_coordinator.dart';
import 'package:plezy/services/playback_initialization_types.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/utils/video_player_navigation.dart';
import 'package:plezy/watch_together/providers/watch_together_provider.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/hdr_startup.dart';
import '../../test_helpers/io_fakes.dart';
import '../../test_helpers/media_items.dart';
import '../../test_helpers/mock_player_channels.dart';
import '../../test_helpers/multi_server_fixtures.dart';
import '../../test_helpers/playback_report_fakes.dart';
import '../../test_helpers/pump.dart';
import '../../test_helpers/stub_music_playback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform previous;
  late AppDatabase db;
  late _ControlledLoader loader;
  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    await initializeDateFormatting('en');
    root = await Directory.systemTemp.createTemp('subtitle-startup-test-');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProvider(root);
    await installHdrStartupHarness();
    DownloadStorageService.resetForTesting();
    await DownloadStorageService.instance.initialize(SettingsService.instance);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loader = _ControlledLoader();
    VideoPlayerScreenState.debugRemoteSubtitleLoaderFactory = () => loader;
  });
  tearDown(() async {
    VideoPlayerScreenState.debugRemoteSubtitleLoaderFactory = null;
    loader.cancel();
    await db.close();
    DownloadStorageService.resetForTesting();
    SettingsService.resetForTesting();
    PathProviderPlatform.instance = previous;
    if (await root.exists()) await root.delete(recursive: true);
  });

  testWidgets('first frame never waits for remote sidecars and replacement rejects a late attachment', (tester) async {
    final multi = testMultiServer(clients: [_StreamClient()]);
    final offlineWatch = OfflineWatchSyncService(database: db, serverManager: multi.manager);
    final preferences = AccountPreferencesController();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const window = MethodChannel('window_manager');
    const controls = MethodChannel('com.edde746.os_media_controls/methods');
    const events = MethodChannel('com.edde746.os_media_controls/events');
    messenger.setMockMethodCallHandler(window, (call) async => call.method.startsWith('is') ? false : null);
    messenger.setMockMethodCallHandler(controls, (call) async => null);
    messenger.setMockMethodCallHandler(events, (call) async => null);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      messenger.setMockMethodCallHandler(window, null);
      messenger.setMockMethodCallHandler(controls, null);
      messenger.setMockMethodCallHandler(events, null);
      tester.view.reset();
      offlineWatch.dispose();
      preferences.dispose();
    });
    final navigator = GlobalKey<NavigatorState>();
    final key = GlobalKey<VideoPlayerScreenState>();
    final commands = <List<String>>[];
    var opens = 0;
    ValueListenable<bool>? revealed() {
      final overlays = find.byType(VideoPlayerBufferingOverlay).evaluate();
      return overlays.isEmpty ? null : (overlays.single.widget as VideoPlayerBufferingOverlay).hasFirstFrame;
    }

    await withMockPlayerChannels(
      methodChannelName: 'com.plezy/mpv_player',
      eventChannelName: 'com.plezy/mpv_player/events',
      methodHandler: (call) async {
        if (call.method == 'initialize') return true;
        if (call.method != 'command') return null;
        final args = ((call.arguments as Map)['args'] as List).cast<String>();
        commands.add(args);
        if (args.first == 'loadfile') {
          opens++;
          expect(args.join(' '), isNot(contains('sub0.srt')));
          expect(args.join(' '), isNot(contains('sub1.srt')));
          final player = key.currentState!.player! as PlayerBase;
          player.handlePlayerEvent('start-file', {'sourceId': opens});
          player.handlePlayerEvent('file-loaded', {'sourceId': opens});
        }
        return null;
      },
      testBody: () async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => PlaybackStateProvider()),
              ChangeNotifierProvider<MultiServerProvider>.value(value: multi.provider),
              ChangeNotifierProvider<OfflineWatchSyncService>.value(value: offlineWatch),
              ChangeNotifierProvider<AccountPreferencesController>.value(value: preferences),
              ChangeNotifierProvider(create: (_) => CompanionRemoteProvider()),
              ChangeNotifierProvider(create: (_) => WatchTogetherProvider()),
              ChangeNotifierProvider(create: (_) => ShaderProvider()),
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
              metadata: testMediaItem(id: 'subtitle-start', serverId: 'srv-1', backend: MediaBackend.jellyfin),
              selectedQualityPreset: TranscodeQualityPreset.original,
            ),
          ).push(navigator.currentState!),
        );
        await pumpUntil(tester, () => opens == 1);
        expect(loader.pending, hasLength(2));
        (key.currentState!.player! as PlayerBase).handlePlayerEvent('playback-restart', {
          'sourceId': 1,
          'positionSeconds': 0.0,
        });
        await pumpUntil(tester, () => revealed()?.value == true);
        expect(loader.pending.values.every((future) => !future.isCompleted), isTrue);
        expect(commands.where((c) => c.first == 'sub-add'), isEmpty);

        // A failed negotiation leaves the old source playing. Its pending
        // download must survive the failed attempt's generation change.
        var reloadDone = false;
        final reload = key.currentState!
            .debugSwitchPlaybackSourceForTesting(newPreset: TranscodeQualityPreset.p1080_8mbps)
            .whenComplete(() => reloadDone = true);
        await pumpUntil(tester, () => reloadDone);
        await reload;
        expect(opens, 1);
        loader.pending.values.first.complete('file:///downloaded-primary.srt');
        await pumpUntil(tester, () => commands.any((c) => c.first == 'sub-add'));
        expect(commands.firstWhere((c) => c.first == 'sub-add')[1], 'file:///downloaded-primary.srt');
        // A source replacement invalidates the token even if an old task still
        // has the same Player instance and its own already-settled first frame.
        await tester.runAsync(() => key.currentState!.player!.open(Media('https://example.invalid/replacement')));
        loader.pending.values.last.complete('file:///late-secondary.srt');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(commands.where((c) => c.first == 'sub-add'), hasLength(1));
        var stopped = false;
        final shutdown = PlaybackCoordinator.instance.shutdownVideo().whenComplete(() => stopped = true);
        await pumpUntil(tester, () => stopped);
        await shutdown;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}

class _ControlledLoader extends RemoteSubtitleLoader {
  final pending = <String, Completer<String?>>{};
  @override
  Future<String?> load(SubtitleTrack track) => (pending[track.uri!] = Completer<String?>()).future;
  @override
  void cancel() {
    for (final request in pending.values) {
      if (!request.isCompleted) request.complete(null);
    }
    super.cancel();
  }
}

class _StreamClient with PlaybackReportRecorder implements MediaServerClient {
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
  Future<PlaybackInitializationResult> getPlaybackInitialization(PlaybackInitializationOptions options) async {
    if (!options.qualityPreset.isOriginal) throw const SocketException('test negotiation failed');
    return PlaybackInitializationResult(
      availableVersions: const [],
      videoUrl: 'https://example.invalid/${options.metadata.id}',
      subtitleSidecars: [
        for (var i = 0; i < 2; i++)
          PlaybackSubtitleSidecar(
            sourceStreamId: i + 3,
            preload: true,
            track: SubtitleTrack.uri('https://example.invalid/sub$i.srt', codec: 'srt'),
          ),
      ],
    );
  }

  @override
  Future<PlaybackExtras> fetchPlaybackExtras(
    String itemId, {
    String? introPattern,
    String? creditsPattern,
    bool forceChapterFallback = false,
    bool forceRefresh = false,
  }) async => PlaybackExtras(chapters: const [], markers: const []);

  @override
  Future<PlaybackExtras?> fetchPlaybackExtrasFromCacheOnly(
    String itemId, {
    String? introPattern,
    String? creditsPattern,
    bool forceChapterFallback = false,
  }) async => null;

  @override
  Future<void> onPlaybackReport(PlaybackReportCall call) async {}

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
