import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/player_core_selection.dart';

import '../test_helpers/prefs.dart';

void main() {
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  testWidgets('settings opens choices without changing core; dismissal preserves the preference', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: monoTheme(dark: true),
        home: const Scaffold(body: PlayerCoreSettingTile()),
      ),
    );
    await tester.tap(find.text(t.settings.playerBackend));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(t.settings.exoPlayer), findsOneWidget);
    expect(SettingsService.instance.read(SettingsService.useExoPlayer), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(SettingsService.instance.read(SettingsService.useExoPlayer), isFalse);

    await tester.tap(find.text(t.settings.playerBackend));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.exoPlayer));
    await tester.pumpAndSettle();
    expect(SettingsService.instance.read(SettingsService.useExoPlayer), isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-player picker returns the chosen backend and never writes a setting itself', (tester) async {
    bool? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: monoTheme(dark: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => selected = await showPlayerCorePicker(context, currentUsesExo: true),
              child: Text(t.settings.playerBackend),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(t.settings.playerBackend));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text(t.settings.mpv));
    await tester.pumpAndSettle();
    expect(selected, isFalse);
    expect(SettingsService.instance.read(SettingsService.useExoPlayer), isFalse);
    expect(tester.takeException(), isNull);
  });
}
