import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_version.dart';
import 'package:plezy/services/sleep_timer_service.dart';
import 'package:plezy/widgets/focusable_list_tile.dart';
import 'package:plezy/widgets/video_controls/sheets/version_quality_sheet.dart';
import 'package:plezy/widgets/video_controls/widgets/sleep_timer_content.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/overlay_sheet.dart';
import 'package:plezy/widgets/video_controls/models/track_controls_state.dart';
import 'package:plezy/widgets/video_controls/sheets/player_settings_drawer.dart';
import 'package:plezy/widgets/video_controls/sheets/player_settings_controls.dart';

import '../test_helpers/watch_together_fakes.dart';
import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';
import '../test_helpers/tablet_screenshots.dart';

void main() {
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    LocaleSettings.setLocaleSync(AppLocale.en);
    await loadTabletFonts();
  });

  testWidgets('player drawer hides fallback durations and preserves the saved settings', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _TabletPlayer();
    addTearDown(player.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: tabletFixtureTheme(monoTheme(dark: true)),
        home: Scaffold(
          body: OverlaySheetHost(
            child: Center(
              child: PlayerSettingsDrawer(
                player: player,
                state: const TrackControlsState(),
                metadata: testMediaItem(id: 'skip-durations'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final entry in [
      (title: t.settings.customSkipIntroSeconds, pref: SettingsService.customSkipIntroSeconds, seconds: 85),
      (title: t.settings.customSkipEndSeconds, pref: SettingsService.customSkipEndSeconds, seconds: 120),
    ]) {
      await SettingsService.instance.write(entry.pref, entry.seconds);
      await tester.pumpAndSettle();
      expect(find.text(entry.title), findsNothing);
      expect(SettingsService.instance.read(entry.pref), entry.seconds);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('video More keeps all four prototype entries and routes to existing controls', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _TabletPlayer();
    addTearDown(player.dispose);
    final zooms = <double>[];
    var cycles = 0;
    const versions = [MediaVersion(id: '1080', height: 1080), MediaVersion(id: '4k', height: 2160)];
    await tester.pumpWidget(
      MaterialApp(
        theme: tabletFixtureTheme(monoTheme(dark: true)),
        home: Scaffold(
          body: OverlaySheetHost(
            child: PlayerSettingsDrawer(
              player: player,
              coreLabel: 'mpv',
              state: TrackControlsState(
                availableVersions: versions,
                onSwitchVersion: (_) {},
                onVideoZoomChanged: zooms.add,
                onCycleBoxFitMode: () => cycles++,
              ),
              metadata: testMediaItem(id: 'more-entries'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entries = [
      t.settings.playerBackend,
      t.videoControls.versionQualityButton,
      t.videoSettings.zoom,
      t.videoSettings.sleepTimer,
    ];
    var previousBottom = tester.getBottomLeft(find.widgetWithText(PlayerDrawerHeading, t.videoControls.moreButton)).dy;
    for (final label in entries) {
      final row = find.widgetWithText(FocusableListTile, label);
      expect(row, findsOneWidget);
      expect(tester.getTopLeft(row).dy, greaterThanOrEqualTo(previousBottom));
      previousBottom = tester.getBottomLeft(row).dy;
    }
    expect(find.widgetWithText(PlayerDrawerChoice, t.fileInfo.flagDefault), findsOneWidget);
    expect(find.widgetWithText(PlayerDrawerChoice, t.videoControls.aspectStretch), findsOneWidget);
    expect(find.widgetWithText(PlayerDrawerChoice, t.videoControls.aspectCover), findsOneWidget);
    await tester.tap(find.widgetWithText(PlayerDrawerChoice, t.videoControls.aspectStretch));
    await tester.pumpAndSettle();
    expect(cycles, 2);
    await tester.tap(find.text(t.videoControls.versionQualityButton));
    await tester.pumpAndSettle();
    expect(find.byType(VersionQualityPicker), findsOneWidget);
    expect(find.text(versions[1].displayLabel), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.videoSettings.zoom));
    await tester.pumpAndSettle();
    await tester.tap(find.text('110%'));
    await tester.pumpAndSettle();
    expect(zooms, [1.1]);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.videoSettings.sleepTimer));
    await tester.pumpAndSettle();
    expect(find.byType(SleepTimerContent), findsOneWidget);
    expect(tester.takeException(), isNull);
    SleepTimerService().cancelTimer();
  });

  testWidgets('unavailable More capabilities stay visible and disabled', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _TabletPlayer();
    addTearDown(player.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: tabletFixtureTheme(monoTheme(dark: true)),
        home: Scaffold(
          body: OverlaySheetHost(
            child: PlayerSettingsDrawer(
              player: player,
              state: const TrackControlsState(),
              metadata: testMediaItem(id: 'more-disabled'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in [t.settings.playerBackend, t.videoControls.versionQualityButton, t.videoSettings.zoom]) {
      final row = tester.widget<FocusableListTile>(find.widgetWithText(FocusableListTile, label));
      expect(row.onTap, isNull);
    }
    expect(
      tester.widget<FocusableListTile>(find.widgetWithText(FocusableListTile, t.videoSettings.sleepTimer)).onTap,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(820, 1180)]) {
    for (final isLive in [false, true]) {
      testWidgets('touch ${isLive ? 'live' : 'VOD'} drawer shows applicable skip controls at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final player = _TabletPlayer();
        addTearDown(player.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: tabletFixtureTheme(monoTheme(dark: true)),
            home: Scaffold(
              body: OverlaySheetHost(
                child: Center(
                  child: PlayerSettingsDrawer(
                    player: player,
                    state: TrackControlsState(isLive: isLive),
                    metadata: testMediaItem(id: 'skip-applicability'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in [t.videoControls.autoSkipSection, t.videoControls.autoSkipToggle]) {
          expect(find.text(label), isLive ? findsNothing : findsOneWidget);
        }
        expect(find.text(t.settings.customSkipIntroSeconds), findsNothing);
        expect(find.text(t.settings.customSkipEndSeconds), findsNothing);
        expect(find.text(t.videoControls.playbackSettings), findsOneWidget);
        expect(find.widgetWithText(PlayerDrawerHeading, t.videoControls.moreButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [const Size(820, 1180), const Size(1180, 820)]) {
    testWidgets('tablet player settings keeps a stable panel at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final player = _TabletPlayer();
      addTearDown(player.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: tabletFixtureTheme(monoTheme(dark: true)),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('tablet-player-panel'),
              child: OverlaySheetHost(
                child: Center(
                  child: PlayerSettingsDrawer(
                    player: player,
                    state: const TrackControlsState(),
                    metadata: testMediaItem(id: 'tablet-player'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final panel = tester.getSize(find.byType(PlayerSettingsDrawer));
      expect(panel.width, 400);
      expect(panel.height, size.height);
      await tester.tap(find.text(t.videoControls.tabAudio));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PlayerSettingsDrawer)), panel);
      expect(tester.takeException(), isNull);
    });
  }
}

class _TabletPlayer extends FakeSyncPlayer {
  @override
  bool get supportsSecondarySubtitles => false;
  @override
  Future<String?> getProperty(String name) async => null;
}
