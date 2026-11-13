import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_part.dart';
import 'package:plezy/media/media_stream.dart';
import 'package:plezy/media/media_version.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/utils/media_quality_labels.dart';
import 'package:plezy/widgets/hero_metadata_badges.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';

void main() {
  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
  });

  testWidgets('hero metadata orders year duration two genres and content rating', (tester) async {
    final item = testMediaItem(
      year: 2024,
      durationMs: 6360000,
      genres: [' Drama ', '', 'Adventure', 'Comedy'],
      contentRating: 'PG-13',
    );
    await tester.pumpWidget(_shell(HeroMetadataBadges(item: item)));

    final labels = tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).toList();
    expect(labels, ['2024', '1h 46min', 'Drama', 'Adventure', 'PG-13']);
    expect(find.text('Comedy'), findsNothing);
  });

  for (final duration in <int?>[null, 0, -1000]) {
    testWidgets('hero metadata omits missing or invalid duration $duration', (tester) async {
      await tester.pumpWidget(_shell(HeroMetadataBadges(item: testMediaItem(year: 2024, durationMs: duration))));
      expect(tester.widgetList<Text>(find.byType(Text)).map((text) => text.data), ['2024']);
    });
  }

  for (final dolbyVision in [false, true]) {
    testWidgets('hero labels never show quality or audio badges with Dolby Vision $dolbyVision', (tester) async {
      final item = testMediaItem(
        year: 2024,
        mediaVersions: [
          MediaVersion(
            id: '4k-version',
            videoResolution: '4k',
            parts: [
              MediaPart(
                id: 'part',
                streams: [
                  MediaStream(
                    id: 'video',
                    kind: MediaStreamKind.video,
                    hdr: true,
                    dolbyVision: dolbyVision,
                    dolbyVisionProfile: dolbyVision ? 5 : null,
                  ),
                  const MediaStream(id: 'audio', kind: MediaStreamKind.audio, codec: 'truehd', channels: 8),
                ],
              ),
            ],
          ),
        ],
      );
      final qualityLabels = buildMediaQualityLabels(item);
      expect(qualityLabels, hasLength(3));
      await tester.pumpWidget(_shell(HeroMetadataBadges(item: item)));

      for (final label in qualityLabels) {
        expect(find.text(label), findsNothing);
      }
      expect(tester.widgetList<Text>(find.byType(Text)).map((text) => text.data), ['2024']);
    });
  }
}

Widget _shell(Widget child) => MaterialApp(home: Scaffold(body: child));
