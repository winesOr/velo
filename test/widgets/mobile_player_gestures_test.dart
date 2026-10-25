import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/providers/playback_state_provider.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/services/video_volume_controller.dart';
import 'package:plezy/watch_together/providers/watch_together_provider.dart';
import 'package:plezy/widgets/video_controls/mobile_video_controls.dart';
import 'package:plezy/widgets/video_controls/player_chrome_controller.dart';
import 'package:plezy/widgets/video_controls/video_controls.dart';
import 'package:plezy/widgets/video_controls/widgets/player_toast_indicator.dart';
import 'package:plezy/widgets/video_controls/widgets/player_track_summary.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';
import '../test_helpers/theme.dart';
import '../test_helpers/watch_together_fakes.dart';
import '../test_helpers/tablet_screenshots.dart';
import 'package:plezy/widgets/overlay_sheet.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/video_controls/sheets/player_settings_drawer.dart';

PlayerChromeController? _chrome;

/// Unmount inside the test body so no auto-hide timer outlives it.
Future<void> _finish(WidgetTester tester) async {
  _chrome?.cancelAutoHide();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    await initializeDateFormatting('en');
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
  });

  Future<FakeSyncPlayer> pumpPlayer(
    WidgetTester tester, {
    Map<Pref<Object?>, Object?> prefs = const {},
    Size size = const Size(1600, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = await SettingsService.getInstance();
    for (final entry in prefs.entries) {
      await settings.write(entry.key, entry.value);
    }
    final player = _TabletControlsPlayer();
    final volume = VideoVolumeController(player: player, settings: settings, initialVolume: 100);
    final playbackState = PlaybackStateProvider();
    final watchTogether = WatchTogetherProvider();
    final chrome = PlayerChromeController();
    final toast = PlayerToastController();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    addTearDown(player.dispose);
    addTearDown(volume.dispose);
    addTearDown(playbackState.dispose);
    addTearDown(watchTogether.dispose);
    addTearDown(chrome.dispose);
    addTearDown(toast.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          ChangeNotifierProvider<PlaybackStateProvider>.value(value: playbackState),
          ChangeNotifierProvider<WatchTogetherProvider>.value(value: watchTogether),
        ],
        child: MaterialApp(
          theme: tabletFixtureTheme(monoTheme(dark: true)).copyWith(extensions: const [testMonoTokens]),
          home: RepaintBoundary(
            key: const ValueKey('tablet-player'),
            child: Scaffold(
              body: OverlaySheetHost(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: PlexVideoControls(
                    player: player,
                    volumeController: volume,
                    metadata: testMediaItem(id: 'gestures'),
                    toastController: toast,
                    canNavigateMediaItems: false,
                    chromeController: chrome,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    _chrome = chrome;
    return player;
  }

  for (final size in [const Size(820, 1180), const Size(1180, 820)]) {
    testWidgets('tablet more action opens the real glass drawer at $size', (tester) async {
      PlatformDetector.debugSetIsDesktopOSOverride(false);
      addTearDown(() => PlatformDetector.debugSetIsDesktopOSOverride(null));
      await loadTabletFonts(loadDefaultFont: true);
      await pumpPlayer(tester, size: size);
      await tester.tap(find.byTooltip(t.videoControls.moreButton));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PlayerSettingsDrawer)).width, 400);
      expect(tester.takeException(), isNull);
      await captureTablet(tester, find.byKey(const ValueKey('tablet-player')), 'player-settings-${size.width.toInt()}');
      await _finish(tester);
    });
  }

  testWidgets('horizontal swipe previews the target and seeks once on release', (tester) async {
    final player = await pumpPlayer(tester);
    final gesture = await tester.startGesture(const Offset(800, 400));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(360, 0));
    await tester.pump();

    // 400 of 1600 px across a 3-minute span is +45s from 10:00.
    expect(find.textContaining('10:45 / 1:00:00'), findsOneWidget);
    expect(player.commandLog.where((c) => c.startsWith('seek:')), isEmpty);

    await gesture.up();
    await tester.pump();
    expect(player.commandLog.where((c) => c.startsWith('seek:')), ['seek:645000']);
    expect(find.textContaining('10:45 / 1:00:00'), findsNothing);
    await _finish(tester);
  });

  testWidgets('swipe-to-seek stays idle when the setting is off', (tester) async {
    final player = await pumpPlayer(tester, prefs: {SettingsService.gestureHorizontalSeek: false});
    final gesture = await tester.startGesture(const Offset(800, 400));
    await gesture.moveBy(const Offset(400, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(player.commandLog.where((c) => c.startsWith('seek:')), isEmpty);
    await _finish(tester);
  });

  testWidgets('long press uses the saved speed and a sideways slide steps it for the hold', (tester) async {
    final player = await pumpPlayer(tester, prefs: {SettingsService.longPressSpeed: 2.5});
    final gesture = await tester.startGesture(const Offset(800, 400));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(player.commandLog.last, 'rate:2.5');
    expect(find.text(t.videoControls.holdSpeed(rate: '2.5x')), findsOneWidget);

    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(player.commandLog.last, 'rate:3.0');

    await gesture.up();
    await tester.pump();
    expect(player.commandLog.last, 'rate:1.0', reason: 'release restores the rate from before the hold');
    expect(SettingsService.instance.read(SettingsService.longPressSpeed), 2.5, reason: 'slide is not persisted');
    await _finish(tester);
  });

  testWidgets('V4 layout: no centre transport, top actions, side rail, short chips', (tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await SettingsService.getInstance();
    final player = FakeSyncPlayer();
    final watchTogether = WatchTogetherProvider();
    addTearDown(player.dispose);
    addTearDown(watchTogether.dispose);
    final taps = <String>[];
    Rect? speedRect;
    await tester.pumpWidget(
      ChangeNotifierProvider<WatchTogetherProvider>.value(
        value: watchTogether,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android, extensions: const [testMonoTokens]),
          home: Scaffold(
            body: MobileVideoControls(
              player: player,
              metadata: testMediaItem(id: 'mobile'),
              chapters: const [],
              chaptersLoaded: true,
              onSeek: (_) {},
              onSeekEnd: (_) {},
              onPlayPause: () => taps.add('play'),
              onNext: () => taps.add('next'),
              onSpeedTap: (rect) {
                speedRect = rect;
                taps.add('speed');
              },
              onSubtitlesTap: (_) => taps.add('subs'),
              onEpisodesTap: (_) => taps.add('eps'),
              onDanmakuTap: (_) => taps.add('dm'),
              onDanmakuToggle: () => taps.add('dmToggle'),
              onCast: () => taps.add('cast'),
              onToggleOrientation: () => taps.add('orient'),
              onMore: () => taps.add('more'),
              onScreenshot: () => taps.add('shot'),
              onTogglePip: () => taps.add('pip'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Symbols.replay_10_rounded), findsNothing, reason: 'double taps replace the centre buttons');
    expect(find.byIcon(Symbols.forward_10_rounded), findsNothing);
    expect(find.byIcon(Symbols.skip_previous_rounded), findsNothing);

    for (final label in [
      t.videoControls.danmakuToggle,
      t.videoControls.castButton,
      t.videoControls.orientationButton,
      t.videoControls.moreButton,
      t.videoControls.screenshotButton,
      t.videoControls.pipButton,
      t.videoControls.nextButton,
    ]) {
      await tester.tap(find.bySemanticsLabel(label).last);
    }
    expect(taps, ['dmToggle', 'cast', 'orient', 'more', 'shot', 'pip', 'next']);

    taps.clear();
    await tester.tap(find.widgetWithText(PlayerChip, '1x'));
    await tester.tap(find.widgetWithText(PlayerChip, t.videoControls.episodesButton));
    await tester.tap(find.widgetWithText(PlayerChip, t.danmaku.title));
    expect(taps, ['speed', 'eps', 'dm']);
    expect(speedRect, isNotNull);
    expect(speedRect!.bottom, greaterThan(700), reason: 'chips sit on the bottom row and report their rect');

    // Screenshot and PiP share the right rail, screenshot on top.
    final shot = tester.getCenter(find.bySemanticsLabel(t.videoControls.screenshotButton).last);
    final pip = tester.getCenter(find.bySemanticsLabel(t.videoControls.pipButton).last);
    expect(shot.dx, closeTo(pip.dx, 1));
    expect(shot.dy, lessThan(pip.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('double tap in the centre toggles playback; a lone tap toggles chrome', (tester) async {
    final player = await pumpPlayer(tester);
    final before = player.commandLog.length;
    await tester.tapAt(const Offset(800, 400));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(800, 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.commandLog.skip(before).where((c) => c == 'play' || c == 'pause'), hasLength(1));
    await _finish(tester);
  });
}

class _TabletControlsPlayer extends FakeSyncPlayer {
  _TabletControlsPlayer() : super(position: const Duration(minutes: 10), duration: const Duration(minutes: 60));
  @override
  bool get supportsSecondarySubtitles => false;
  @override
  Future<String?> getProperty(String name) async => null;
}
