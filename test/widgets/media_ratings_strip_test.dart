import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_rating.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/widgets/hero_metadata_badges.dart';
import 'package:plezy/widgets/media_rating_badge.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';

void main() {
  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
  });

  testWidgets('hero metadata keeps two preferred ratings before information labels', (tester) async {
    final item = testMediaItem(year: 2024, durationMs: 6360000).copyWith(
      ratings: const [
        MediaRatingSource(source: 'imdb', value: 8.1),
        MediaRatingSource(source: 'tmdb', value: 7.2),
        MediaRatingSource(source: 'rottenTomatoesCritic', value: 9.3),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HeroMetadataBadges(item: item)),
      ),
    );

    final badges = tester.widgetList<InlineRatingBadges>(find.byType(InlineRatingBadges)).toList();
    expect(badges, hasLength(2));
    expect(badges.map((badge) => badge.ratings.single.source), ['rottenTomatoesCritic', 'imdb']);
    expect(badges.map((badge) => badge.ratings.single.value), [9.3, 8.1]);
    final metadata = tester.widget<Wrap>(
      find.descendant(of: find.byType(HeroMetadataBadges), matching: find.byType(Wrap)).first,
    );
    expect(metadata.children.take(2), everyElement(isA<InlineRatingBadges>()));
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('1h 46min'), findsOneWidget);
  });
}
