import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/focus/locked_hub_controller.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/theme/home_typography.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/hub_section.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';

final _episode = testMediaItem(
  id: 'resume-episode',
  kind: MediaKind.episode,
  title: '正片 第2期下',
  grandparentTitle: '现在就出发',
  parentIndex: 4,
  index: 7,
  durationMs: const Duration(hours: 1, minutes: 6, seconds: 43).inMilliseconds,
  viewOffsetMs: const Duration(minutes: 37, seconds: 18).inMilliseconds,
);

Future<void> _pumpHub(
  WidgetTester tester, {
  required List<MediaItem> items,
  bool continueWatching = true,
  bool showWatchProgress = true,
  VoidCallback? onTap,
  bool tv = false,
  bool dark = true,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tv ? const Size(1280, 270) : Size(390, textScale > 1 ? 330 : 270);
  TvDetectionService.debugSetAppleTVOverride(tv);
  await tester.pumpWidget(
    MaterialApp(
      theme: HomeTypography.apply(
        monoTheme(dark: dark).copyWith(
          textTheme: monoTheme(dark: dark).textTheme.apply(fontFamily: 'ProgressFixture'),
        ),
        tv: tv,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('continue-shelf-preview'),
          child: ColoredBox(
            color: dark ? const Color(0xFF16191D) : const Color(0xFFF2F2F7),
            child: ListView(
              children: [
                HubSection(
                  hub: MediaHub(id: 'resume', title: t.discover.continueWatching, type: 'mixed', items: items),
                  focusMemory: HubFocusMemory(),
                  icon: Symbols.play_arrow_rounded,
                  isInContinueWatching: continueWatching,
                  showWatchProgress: showWatchProgress,
                  episodePosterModeOverride: EpisodePosterMode.episodeThumbnail,
                  cardWidthOverride: tv ? 281 : 224,
                  onItemTap: onTap == null ? null : (_) => onTap(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await LocaleSettings.setLocale(AppLocale.zh);
    await (FontLoader('ProgressFixture')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    await (FontLoader(
      'packages/material_symbols_icons/MaterialSymbolsRounded',
    )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
  });
  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
  });
  tearDown(() => TvDetectionService.debugSetAppleTVOverride(null));

  for (final fixture in [
    (name: 'phone', tv: false, dark: true, scale: 1.0),
    (name: 'phone_light', tv: false, dark: false, scale: 1.0),
    (name: 'phone_large', tv: false, dark: true, scale: 1.6),
    (name: 'tv', tv: true, dark: true, scale: 1.0),
  ]) {
    testWidgets('Continue Watching retains progress in the ${fixture.name} layout', (tester) async {
      addTearDown(tester.view.reset);
      LocaleSettings.setLocaleSync(AppLocale.zh);
      await _pumpHub(
        tester,
        tv: fixture.tv,
        showWatchProgress: true,
        dark: fixture.dark,
        textScale: fixture.scale,
        items: [
          _episode,
          _episode.copyWith(id: 'up-next', index: 8, viewOffsetMs: 0),
        ],
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('continue-shelf-preview')),
        matchesGoldenFile('goldens/continue_watching_${fixture.name}.png'),
      );
    });
  }
}
