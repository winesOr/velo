import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
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
import 'package:plezy/providers/account_preferences_controller.dart';
import 'package:plezy/providers/companion_remote_provider.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/providers/playback_state_provider.dart';
import 'package:plezy/providers/shader_provider.dart';
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

import 'package:plezy/widgets/overlay_sheet.dart';
import 'package:plezy/widgets/video_controls/video_controls.dart';
import 'package:plezy/widgets/video_controls/sheets/dlna_cast_sheet.dart';
import '../../test_helpers/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform previous;
  late AppDatabase db;

  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    await initializeDateFormatting('en');
    root = await Directory.systemTemp.createTemp('cast-player-sheet-test-');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProvider(root);
    await installHdrStartupHarness();
    DownloadStorageService.resetForTesting();
    await DownloadStorageService.instance.initialize(SettingsService.instance);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    DownloadStorageService.resetForTesting();
    SettingsService.resetForTesting();
    PathProviderPlatform.instance = previous;
    if (await root.exists()) await root.delete(recursive: true);
  });

  testWidgets('player owns transparent system bars in portrait and landscape and casting still opens', (tester) async {
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: 28, bottom: 24);
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

    await withMockPlayerChannels(
      methodChannelName: 'com.plezy/mpv_player',
      eventChannelName: 'com.plezy/mpv_player/events',
      methodHandler: (call) async {
        if (call.method == 'initialize') return true;
        if (call.method != 'command') return null;
        final args = ((call.arguments as Map)['args'] as List).cast<String>();
        if (args.first == 'loadfile') {
          final player = key.currentState!.player! as PlayerBase;
          player.handlePlayerEvent('start-file', {'sourceId': 1});
          player.handlePlayerEvent('file-loaded', {'sourceId': 1});
          player.handlePlayerEvent('playback-restart', {'sourceId': 1, 'positionSeconds': 0.0});
        }
        return null;
      },
      testBody: () async {
        try {
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
                theme: ThemeData(platform: TargetPlatform.android, extensions: const [testMonoTokens]),
                navigatorKey: navigator,
                home: const AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.white54,
                    statusBarIconBrightness: Brightness.dark,
                    systemStatusBarContrastEnforced: true,
                    systemNavigationBarColor: Colors.white54,
                    systemNavigationBarIconBrightness: Brightness.dark,
                    systemNavigationBarContrastEnforced: true,
                  ),
                  child: Scaffold(body: Text('Browse')),
                ),
              ),
            ),
          );
          unawaited(
            VideoPlayerRoute(
              builder: (_) => VideoPlayerScreen(
                key: key,
                metadata: testMediaItem(id: 'cast-panel', serverId: 'srv-1', backend: MediaBackend.jellyfin),
                selectedQualityPreset: TranscodeQualityPreset.original,
              ),
            ).push(navigator.currentState!),
          );
          await pumpUntil(tester, () => find.byType(PlexVideoControls).evaluate().isNotEmpty);
          await tester.pump(const Duration(milliseconds: 300));
          void expectPlaybackBars() {
            final style = SystemChrome.latestStyle!;
            expect(style.statusBarColor, Colors.transparent);
            expect(style.statusBarIconBrightness, Brightness.light);
            expect(style.systemStatusBarContrastEnforced, isFalse);
            expect(style.systemNavigationBarColor, Colors.transparent);
            expect(style.systemNavigationBarIconBrightness, Brightness.light);
            expect(style.systemNavigationBarContrastEnforced, isFalse);
          }

          expectPlaybackBars();
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.padding = FakeViewPadding(left: 28);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expectPlaybackBars();
          final host = OverlaySheetController.of(tester.element(find.byType(PlexVideoControls)));
          expect(host.isOpen, isFalse);

          await tester.tap(find.byTooltip(t.videoControls.castButton));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          expect(host.isOpen, isTrue);
          expect(find.byType(DlnaCastSheet), findsOneWidget);
          // The desktop test host still opens the actual panel and displays
          // its platform restriction; discovery is exercised separately.
          expect(find.text(t.videoControls.castUnavailable), findsOneWidget);

          await tester.tap(find.byTooltip(t.common.close));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(host.isOpen, isFalse);
          expect(find.byType(DlnaCastSheet), findsNothing);
          expect(find.byType(VideoPlayerScreen), findsOneWidget);
        } finally {
          var stopped = false;
          final shutdown = PlaybackCoordinator.instance.shutdownVideo().whenComplete(() => stopped = true);
          await pumpUntil(tester, () => stopped);
          await shutdown;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
    );
  });
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
    return PlaybackInitializationResult(
      availableVersions: const [],
      videoUrl: 'https://example.invalid/${options.metadata.id}',
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
