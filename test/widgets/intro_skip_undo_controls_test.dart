import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/media/media_source_info.dart';
import 'package:plezy/mpv/mpv.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/providers/playback_state_provider.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/services/video_volume_controller.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/watch_together/providers/watch_together_provider.dart';
import 'package:plezy/widgets/video_controls/player_chrome_controller.dart';
import 'package:plezy/widgets/video_controls/video_controls.dart';
import 'package:plezy/widgets/video_controls/desktop_video_controls.dart';
import 'package:plezy/widgets/video_controls/widgets/player_toast_indicator.dart';
import 'package:provider/provider.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/multi_server_fixtures.dart';
import '../test_helpers/player_streams.dart';
import '../test_helpers/prefs.dart';
import '../test_helpers/theme.dart';
import '../test_helpers/watch_together_fakes.dart';

final _intro = MediaMarker(id: 1, type: 'intro', startTimeOffset: 10000, endTimeOffset: 80000);

class _MarkerClient implements MediaServerClient {
  @override
  ServerId get serverId => ServerId('undo-server');
  @override
  MediaBackend get backend => MediaBackend.plex;
  @override
  String get serverName => 'Undo fixture';
  @override
  void close() {}
  @override
  Future<PlaybackExtras> fetchPlaybackExtras(
    String itemId, {
    String? introPattern,
    String? creditsPattern,
    bool forceChapterFallback = false,
    bool forceRefresh = false,
  }) async => PlaybackExtras(chapters: [], markers: [_intro]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MarkerPlayer extends FakeSyncPlayer {
  _MarkerPlayer() : super(position: const Duration(seconds: 13), hasRenderedFrame: true);
  final _positions = StreamController<Duration>.broadcast();
  @override
  PlayerStreams get streams => emptyPlayerStreams(position: _positions.stream);
  Future<void> emitPosition(Duration value) async {
    await super.seek(value);
    commandLog.clear();
    _positions.add(value);
  }

  @override
  Future<void> seek(Duration position) async {
    await super.seek(position);
    _positions.add(position);
  }

  @override
  Future<void> dispose({bool preserveDisplayMode = false}) async {
    await _positions.close();
    await super.dispose(preserveDisplayMode: preserveDisplayMode);
  }
}

class _Harness {
  _Harness(this.player, this.volume, this.chrome, this.toast, this.playback, this.together, this.db, this.servers);
  final _MarkerPlayer player;
  final VideoVolumeController volume;
  final PlayerChromeController chrome;
  final PlayerToastController toast;
  final PlaybackStateProvider playback;
  final WatchTogetherProvider together;
  final AppDatabase db;
  final MultiServerProvider servers;
  String itemId = 'episode-1';
  bool canControl = true;
  final completed = <Duration>[];
  Widget build() => MultiProvider(
    providers: [
      Provider<AppDatabase>.value(value: db),
      ChangeNotifierProvider<MultiServerProvider>.value(value: servers),
      ChangeNotifierProvider<PlaybackStateProvider>.value(value: playback),
      ChangeNotifierProvider<WatchTogetherProvider>.value(value: together),
    ],
    child: InputModeTracker(
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS, extensions: const [testMonoTokens]),
        home: Scaffold(
          body: PlexVideoControls(
            player: player,
            volumeController: volume,
            metadata: testMediaItem(id: itemId, serverId: 'undo-server'),
            toastController: toast,
            canNavigateMediaItems: false,
            chromeController: chrome,
            canControl: canControl,
            onSeekCompleted: completed.add,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    await initializeDateFormatting('en');
  });

  Future<_Harness> mount(WidgetTester tester, {bool tv = false}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TvDetectionService.debugSetAppleTVOverride(tv);
    addTearDown(() => TvDetectionService.debugSetAppleTVOverride(null));
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    final settings = await SettingsService.getInstance();
    await settings.write(SettingsService.skipIntroMode, SkipMarkerMode.auto);
    await settings.write(SettingsService.autoSkipDelay, 1);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final servers = testMultiServer(clients: [_MarkerClient()]).provider;
    final player = _MarkerPlayer();
    final volume = VideoVolumeController(player: player, settings: settings, initialVolume: 100);
    final harness = _Harness(
      player,
      volume,
      PlayerChromeController(),
      PlayerToastController(),
      PlaybackStateProvider(),
      WatchTogetherProvider(),
      db,
      servers,
    );
    addTearDown(() async {
      volume.dispose();
      harness.chrome.dispose();
      harness.toast.dispose();
      harness.playback.dispose();
      harness.together.dispose();
      await player.dispose();
      await db.close();
    });
    await tester.pumpWidget(harness.build());
    await tester.pump();
    await tester.pump();
    expect(find.textContaining(t.videoControls.skipIntro), findsOneWidget);
    return harness;
  }

  Future<void> autoSkip(WidgetTester tester, _Harness harness) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(harness.player.commandLog, contains('seek:80000'));
    expect(find.text(t.videoControls.undoIntroSkip), findsOneWidget);
  }

  testWidgets('editing custom skip seconds updates the current timeline and preserves server markers', (tester) async {
    final harness = await mount(tester);
    final settings = SettingsService.instance;
    await settings.write(SettingsService.skipIntroMode, SkipMarkerMode.button);
    await settings.write(SettingsService.customSkipIntroSeconds, 30);
    await settings.write(SettingsService.customSkipEndSeconds, 60);
    await tester.pump();
    var ranges = tester.widget<DesktopVideoControls>(find.byType(DesktopVideoControls)).skipRanges;
    expect(ranges, hasLength(2));
    expect(ranges.first.start, const Duration(seconds: 10));
    expect(ranges.first.end, const Duration(seconds: 80), reason: 'the precise server intro still wins');
    expect(ranges.last.end - ranges.last.start, const Duration(seconds: 60));
    await settings.write(SettingsService.customSkipEndSeconds, 0);
    await tester.pump();
    ranges = tester.widget<DesktopVideoControls>(find.byType(DesktopVideoControls)).skipRanges;
    expect(ranges, hasLength(1), reason: 'zero immediately removes the old custom end range');
    expect(harness.player.commandLog.where((entry) => entry.startsWith('seek:')), isEmpty);
    harness.chrome.cancelAutoHide();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('automatic skip offers undo and restores exact position without automatic re-skip', (tester) async {
    final harness = await mount(tester);
    await autoSkip(tester, harness);
    await tester.tap(find.text(t.videoControls.undoIntroSkip));
    await tester.pump();
    await tester.pump();
    expect(harness.player.commandLog.where((entry) => entry.startsWith('seek:')), ['seek:80000', 'seek:13000']);
    await tester.pump(const Duration(seconds: 2));
    expect(harness.player.state.position, const Duration(seconds: 13));
    await harness.player.emitPosition(const Duration(seconds: 14));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(harness.player.commandLog, isEmpty, reason: 'the viewer chose to watch this intro interval');
    harness.chrome.cancelAutoHide();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('undo disappears after five seconds and cannot seek after controls disposal', (tester) async {
    final harness = await mount(tester);
    await autoSkip(tester, harness);
    await tester.pump(const Duration(milliseconds: 4999));
    expect(find.text(t.videoControls.undoIntroSkip), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text(t.videoControls.undoIntroSkip), findsNothing);
    harness.chrome.cancelAutoHide();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(harness.player.commandLog.where((entry) => entry.startsWith('seek:')), ['seek:80000']);
  });

  testWidgets('late automatic seek completion cannot offer undo or notify a new episode', (tester) async {
    final harness = await mount(tester);
    final seekAck = Completer<void>();
    harness.player.nextCommandFuture = seekAck.future;
    await tester.pump(const Duration(seconds: 1));
    harness.itemId = 'episode-2';
    await tester.pumpWidget(harness.build());
    seekAck.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text(t.videoControls.undoIntroSkip), findsNothing);
    expect(harness.completed, isEmpty, reason: 'old timeline completion must not update the replacement item');
    harness.chrome.cancelAutoHide();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('TV select on the displayed undo action restores rather than toggles playback', (tester) async {
    final harness = await mount(tester, tv: true);
    await autoSkip(tester, harness);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();
    expect(harness.player.commandLog, contains('seek:13000'));
    expect(harness.player.commandLog, isNot(contains('play')));
    expect(harness.player.commandLog, isNot(contains('pause')));
    harness.chrome.cancelAutoHide();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('desktop skip shortcut uses the displayed undo action', (tester) async {
    final harness = await mount(tester);
    await autoSkip(tester, harness);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(harness.player.commandLog, contains('seek:13000'));
    harness.chrome.cancelAutoHide();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a replacement item clears an available undo and its suppression', (tester) async {
    final harness = await mount(tester);
    await autoSkip(tester, harness);
    await tester.tap(find.text(t.videoControls.undoIntroSkip));
    await tester.pump();
    await tester.pump();
    harness.itemId = 'episode-2';
    await tester.pumpWidget(harness.build());
    await tester.pump();
    await tester.pump();
    expect(find.text(t.videoControls.undoIntroSkip), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(harness.player.commandLog.where((entry) => entry.startsWith('seek:')), [
      'seek:80000',
      'seek:13000',
      'seek:80000',
    ]);
    expect(find.text(t.videoControls.undoIntroSkip), findsOneWidget);
    harness.chrome.cancelAutoHide();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('late undo completion cannot notify the replacement item', (tester) async {
    final harness = await mount(tester);
    await autoSkip(tester, harness);
    harness.completed.clear();
    final seekAck = Completer<void>();
    harness.player.nextCommandFuture = seekAck.future;
    await tester.tap(find.text(t.videoControls.undoIntroSkip));
    await tester.pump();
    harness.itemId = 'episode-2';
    await tester.pumpWidget(harness.build());
    seekAck.complete();
    await tester.pump();
    await tester.pump();
    expect(harness.completed, isEmpty);
    expect(find.text(t.videoControls.undoIntroSkip), findsNothing);
    harness.chrome.cancelAutoHide();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed undo does not suppress the interval and does not throw from the button callback', (tester) async {
    final harness = await mount(tester);
    await autoSkip(tester, harness);
    harness.player.nextCommandError = StateError('native seek rejected');
    await tester.tap(find.text(t.videoControls.undoIntroSkip));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await harness.player.emitPosition(const Duration(seconds: 14));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(harness.player.commandLog, contains('seek:80000'), reason: 'failed undo did not choose to watch the intro');
    harness.chrome.cancelAutoHide();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
