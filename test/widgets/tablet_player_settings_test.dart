import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/overlay_sheet.dart';
import 'package:plezy/widgets/video_controls/models/track_controls_state.dart';
import 'package:plezy/widgets/video_controls/sheets/player_settings_drawer.dart';

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

  testWidgets('player drawer edits the same persisted intro and end durations as global settings', (tester) async {
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
      await tester.ensureVisible(find.text(entry.title));
      await tester.tap(find.text(entry.title));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '${entry.seconds}');
      await tester.tap(find.text(t.common.save));
      await tester.pumpAndSettle();
      expect(SettingsService.instance.read(entry.pref), entry.seconds);
      expect(find.text(t.settings.secondsUnit(seconds: '${entry.seconds}')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(820, 1180), const Size(1180, 820)]) {
    testWidgets('tablet player settings keeps a wider stable panel at $size', (tester) async {
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
      expect(panel.height, 680);
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
