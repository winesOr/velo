import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/navigation/home_theme.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/theme/home_typography.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/fusion_home_hero.dart';
import 'package:plezy/widgets/hero_text_blocks.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Go Noto Current')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    await (FontLoader('Georgia')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    if (Platform.environment['VELO_R1_SCREENSHOTS']?.isNotEmpty == true) {
      // Explicit RichText spans use the renderer default instead of Theme fonts.
      await (FontLoader('Ahem')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    }
  });
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    LocaleSettings.setLocaleSync(AppLocale.en);
    TvDetectionService.debugSetAppleTVOverride(false);
  });
  tearDown(() {
    TvDetectionService.debugSetAppleTVOverride(null);
  });

  for (final appearance in [
    (name: 'light', dark: false, oled: false),
    (name: 'dark', dark: true, oled: false),
    (name: 'black', dark: true, oled: true),
  ]) {
    for (final fixture in [
      (name: 'phone', size: const Size(390, 844), scale: 1.0),
      (name: 'phone-landscape', size: const Size(844, 390), scale: 1.0),
      (name: 'phone-large-text', size: const Size(390, 844), scale: 2.0),
      (name: 'tablet', size: const Size(820, 1180), scale: 1.0),
      (name: 'tablet-landscape', size: const Size(1180, 820), scale: 1.0),
    ]) {
      testWidgets('${appearance.name} ${fixture.name} home fixture shows info only', (tester) async {
        final previousPlatform = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = fixture.size;
          addTearDown(() {
            tester.view.resetDevicePixelRatio();
            tester.view.resetPhysicalSize();
          });
          final boundary = GlobalKey();
          final controller = HomeThemeController();
          addTearDown(controller.dispose);
          final image = MemoryImage(File('test/fixtures/artwork/interstellar-backdrop.png').readAsBytesSync());
          var opens = 0;
          final baseTheme = monoTheme(dark: appearance.dark, oled: appearance.oled);
          final theme = HomeTypography.apply(
            baseTheme.copyWith(textTheme: baseTheme.textTheme.apply(fontFamily: 'Go Noto Current')),
            tv: false,
            tablet: fixture.size.shortestSide >= 600,
            artworkSurface: const Color(0xff222936),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Go Noto Current')),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fixture.scale)),
                child: child!,
              ),
              home: HomeThemeScope(
                controller: controller,
                fallbackColor: const Color(0xff222936),
                child: RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    body: SizedBox(
                      height: fixture.size.height < 450 ? fixture.size.height : fixture.size.height * .65,
                      child: FusionHomeHero(
                        item: testMediaItem(
                          title: 'Interstellar',
                          originalTitle: 'A journey beyond the stars',
                          summary:
                              'A team of explorers travels beyond this galaxy to discover whether mankind has a future among the stars. Their journey changes everything they know about space, time and home.',
                          year: 2014,
                          durationMs: 10140000,
                          genres: ['Science Fiction', 'Adventure'],
                          contentRating: 'PG-13',
                        ),
                        compact: fixture.size.height < 450,
                        onOpen: () => opens++,
                        backdrop: Image(image: image, key: const ValueKey('decoded-home-artwork'), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() => precacheImage(image, tester.element(find.byType(FusionHomeHero))));
          await tester.pump();
          expect(find.byKey(const ValueKey('decoded-home-artwork')), findsOneWidget);
          expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
          final summary = tester.widget<HeroSummary>(find.byType(HeroSummary));
          expect(summary.maxLines, 2);
          expect(summary.textAlign, fixture.name == 'tablet-landscape' ? TextAlign.left : TextAlign.center);
          expect(
            find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton || widget is IconButton || widget is InkWell,
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);

          if (fixture.scale == 2) {
            final scrollable = tester.state<ScrollableState>(
              find.descendant(of: find.byType(FusionHomeHero), matching: find.byType(Scrollable)),
            );
            scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
            await tester.pump();
            final titleRect = tester.getRect(find.text('Interstellar'));
            final viewport = tester.getRect(find.byType(SingleChildScrollView));
            expect(titleRect.top, greaterThanOrEqualTo(viewport.top - 1));
            expect(titleRect.bottom, lessThanOrEqualTo(viewport.bottom + 1));
          }

          await _capture(tester, boundary, '${appearance.name}-${fixture.name}');
          await tester.tapAt(tester.getRect(find.byType(FusionHomeHero)).topLeft + const Offset(10, 10));
          expect(opens, 1);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          debugDefaultTargetPlatformOverride = previousPlatform;
        }
      });
    }
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['VELO_R1_SCREENSHOTS'];
  if (directory == null || directory.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
