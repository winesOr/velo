import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_rating.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/fusion_home_hero.dart';
import 'package:plezy/widgets/hero_text_blocks.dart';
import 'package:plezy/widgets/media_rating_badge.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';

void main() {
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    LocaleSettings.setLocaleSync(AppLocale.en);
    TvDetectionService.debugSetAppleTVOverride(false);
  });
  tearDown(() => TvDetectionService.debugSetAppleTVOverride(null));

  testWidgets('FusionHomeHero renders info only', (tester) async {
    final item =
        testMediaItem(
          title: 'Local title',
          originalTitle: 'Original title',
          summary: 'A story about a distant world.',
          year: 2024,
          durationMs: 6360000,
          genres: ['Drama', 'Adventure', 'Comedy'],
          contentRating: 'PG-13',
        ).copyWith(
          ratings: const [
            MediaRatingSource(source: 'imdb', value: 8.1),
            MediaRatingSource(source: 'tmdb', value: 7.2),
            MediaRatingSource(source: 'rottenTomatoesCritic', value: 9.3),
          ],
        );
    await _pumpHero(tester, item);

    for (final text in ['Local title', 'ORIGINAL TITLE', '2024', '1h 46min', 'Drama', 'Adventure', 'PG-13']) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text('A story about a distant world.', findRichText: true), findsOneWidget);
    expect(find.byType(InlineRatingBadges), findsNWidgets(2));
    expect(find.text('Comedy'), findsNothing);
    _expectNoActions();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap and semantics open details', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var opens = 0;
      await _pumpHero(tester, testMediaItem(title: 'Local title'), onOpen: () => opens++);
      await tester.tap(find.byType(FusionHomeHero));
      expect(opens, 1);
      expect(
        tester.getSemantics(find.byType(FusionHomeHero)).getSemanticsData().hint,
        t.accessibility.tapToOpenDetails,
      );
      expect(find.byType(HeroOriginalTitle), findsNothing);
      expect(find.byType(HeroSummary), findsNothing);
      _expectNoActions();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('episode hero hides the spoiler while keeping its identity', (tester) async {
    final item = testMediaItem(
      kind: MediaKind.episode,
      title: 'Episode title',
      grandparentTitle: 'Show title',
      parentIndex: 1,
      index: 2,
      summary: 'The secret ending.',
    );
    await _pumpHero(tester, item, hideSpoiler: true);
    expect(find.text('Show title'), findsOneWidget);
    expect(find.text('S1, E2: Episode title'), findsOneWidget);
    expect(find.textContaining('The secret ending.', findRichText: true), findsNothing);
    expect(tester.widget<HeroSummary>(find.byType(HeroSummary)).maxLines, 2);
  });
}

void _expectNoActions() {
  expect(
    find.byWidgetPredicate((widget) => widget is ButtonStyleButton || widget is IconButton || widget is InkWell),
    findsNothing,
  );
  expect(find.text(t.common.play), findsNothing);
  expect(find.text(t.mediaMenu.viewDetails), findsNothing);
  expect(find.text('4K'), findsNothing);
}

Future<void> _pumpHero(WidgetTester tester, MediaItem item, {VoidCallback? onOpen, bool hideSpoiler = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: monoTheme(dark: true),
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 600,
          child: FusionHomeHero(
            item: item,
            onOpen: onOpen ?? () {},
            hideSpoiler: hideSpoiler,
            backdrop: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    ),
  );
}
