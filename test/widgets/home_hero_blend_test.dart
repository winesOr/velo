import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/navigation/home_theme.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/fusion_home_hero.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';

void main() {
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    TvDetectionService.debugSetAppleTVOverride(false);
  });
  tearDown(() => TvDetectionService.debugSetAppleTVOverride(null));

  for (final appearance in [
    (name: 'light', dark: false, oled: false),
    (name: 'dark', dark: true, oled: false),
    (name: 'black', dark: true, oled: true),
  ]) {
    testWidgets('${appearance.name} info-only hero blends into artwork without a white veil', (tester) async {
      const artworkColor = Color(0xff462535);
      final controller = HomeThemeController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: monoTheme(dark: appearance.dark, oled: appearance.oled),
          home: HomeThemeScope(
            controller: controller,
            fallbackColor: artworkColor,
            child: SizedBox(
              height: 600,
              child: FusionHomeHero(
                item: testMediaItem(title: 'Title', summary: 'A story.'),
                onOpen: () {},
                backdrop: const ColoredBox(color: artworkColor),
              ),
            ),
          ),
        ),
      );
      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.gradient)
          .whereType<LinearGradient>();
      final blend = gradients.singleWhere((gradient) => gradient.stops?.length == 11);
      expect(blend.colors.last, artworkColor);
      expect(blend.colors.first.a, 0);
      expect(blend.colors.every((color) => color.withValues(alpha: 1) == artworkColor), isTrue);
      expect(find.text('Title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
