import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/screens/settings/rating_settings_screen.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/widgets/focusable_list_tile.dart';

import '../../test_helpers/prefs.dart';

void main() {
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  test('rating preferences survive reload and participate in portable reset settings', () async {
    final service = SettingsService.instance;
    await service.write(SettingsService.showRatingBadges, false);
    await service.write(SettingsService.ratingSourceOrder, ['imdb', 'tmdb']);
    await service.write(SettingsService.disabledRatingSources, ['critic']);
    SettingsService.resetForTesting();
    final reloaded = await SettingsService.getInstance();
    expect(reloaded.read(SettingsService.showRatingBadges), isFalse);
    expect(reloaded.read(SettingsService.ratingSourceOrder), ['imdb', 'tmdb']);
    expect(reloaded.read(SettingsService.disabledRatingSources), ['critic']);
    for (final pref in <Pref<Object?>>[
      SettingsService.showRatingBadges,
      SettingsService.ratingSourceOrder,
      SettingsService.disabledRatingSources,
    ]) {
      expect(SettingsService.portablePrefs, contains(pref));
      await reloaded.reset(pref);
    }
    expect(reloaded.read(SettingsService.showRatingBadges), isTrue);
    expect(reloaded.read(SettingsService.disabledRatingSources), isEmpty);
    expect(reloaded.read(SettingsService.ratingSourceOrder).first, 'rottenTomatoesCritic');
  });

  testWidgets('source switch and move buttons update the persisted display order', (tester) async {
    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: const RatingSettingsScreen())));
    await tester.pumpAndSettle();
    final criticRow = find.byKey(const ValueKey('rating-source-rottenTomatoesCritic'));
    final switchTile = find.descendant(of: criticRow, matching: find.byType(FocusableSwitchListTile));
    await tester.tap(switchTile);
    await tester.pumpAndSettle();
    expect(SettingsService.instance.read(SettingsService.disabledRatingSources), ['rottenTomatoesCritic']);
    final down = find.descendant(
      of: find.byKey(const ValueKey('rating-rottenTomatoesCritic-down')),
      matching: find.byType(TextButton),
    );
    await tester.ensureVisible(down);
    await tester.tap(down);
    await tester.pumpAndSettle();
    expect(SettingsService.instance.read(SettingsService.ratingSourceOrder).take(2), [
      'rottenTomatoesAudience',
      'rottenTomatoesCritic',
    ]);
    expect(tester.takeException(), isNull);
  });
}
