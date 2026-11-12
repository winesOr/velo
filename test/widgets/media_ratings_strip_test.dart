import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_rating.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/widgets/hero_metadata_badges.dart';
import 'package:plezy/widgets/media_ratings_strip.dart';

import '../test_helpers/prefs.dart';

const _scores = [
  MediaRatingSource(source: 'rottenTomatoesCritic', value: 9.2),
  MediaRatingSource(source: 'rottenTomatoesAudience', value: 8.8),
  MediaRatingSource(source: 'imdb', value: 8.1),
  MediaRatingSource(source: 'tmdb', value: 7.9),
  MediaRatingSource(source: 'simkl', value: 8.2),
];

MediaItem _item(List<MediaRatingSource> ratings) => MediaItem.plex(
  id: 'movie',
  kind: MediaKind.movie,
  title: 'A very long title that never displaces a rating',
  ratings: ratings,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  Brightness brightness = Brightness.dark,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Center(child: SizedBox(width: 320, child: child)),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  for (final count in [0, 1, 2, 5]) {
    testWidgets('$count source detail has a stable maximum of four external scores', (tester) async {
      await _pump(tester, MediaRatingsStrip(item: _item(_scores.take(count).toList())));
      expect(find.text('92%'), count == 0 ? findsNothing : findsOneWidget);
      expect(find.text('8.2'), findsNothing);
      if (count == 0) expect(tester.getSize(find.byType(MediaRatingsStrip)).height, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filling additional sources does not change the reserved region height', (tester) async {
    await _pump(tester, MediaRatingsStrip(item: _item([_scores.first])));
    final height = tester.getSize(find.byType(MediaRatingsStrip)).height;
    await _pump(tester, MediaRatingsStrip(item: _item(_scores)));
    expect(tester.getSize(find.byType(MediaRatingsStrip)).height, height);
  });

  testWidgets('320px at 200% text stays readable in bright and dark themes', (tester) async {
    for (final brightness in Brightness.values) {
      await _pump(tester, MediaRatingsStrip(item: _item(_scores)), scale: 2, brightness: brightness);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('79%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('source preference changes rebuild an already visible detail region', (tester) async {
    await _pump(tester, MediaRatingsStrip(item: _item(_scores)));
    await SettingsService.instance.write(SettingsService.disabledRatingSources, ['rottenTomatoesCritic']);
    await tester.pump();
    expect(find.text('92%'), findsNothing);
    expect(find.text('8.2'), findsOneWidget);
    await SettingsService.instance.write(
      SettingsService.disabledRatingSources,
      _scores.map((score) => score.source).toList(),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(MediaRatingsStrip)).height, 0);
  });

  testWidgets('unknown source is labeled neutrally rather than exposing the key', (tester) async {
    await _pump(
      tester,
      MediaRatingsStrip(item: _item(const [MediaRatingSource(source: 'internal.future.rating', value: 7.2)])),
    );
    expect(find.text('Other ratings'), findsOneWidget);
    expect(find.textContaining('internal.future'), findsNothing);
  });

  testWidgets('homepage shows at most two enabled sources and reacts to ordering', (tester) async {
    await _pump(tester, HeroMetadataBadges(item: _item(_scores)));
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('8.1'), findsNothing);
    await SettingsService.instance.write(SettingsService.ratingSourceOrder, ['imdb', 'tmdb']);
    await tester.pump();
    expect(find.text('8.1'), findsOneWidget);
    expect(find.text('79%'), findsOneWidget);
    expect(find.text('92%'), findsNothing);
  });
}
