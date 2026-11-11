import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/connection/connection_registry.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/navigation/navigation_tabs.dart';
import 'package:plezy/profiles/active_profile_provider.dart';
import 'package:plezy/profiles/plex_home_service.dart';
import 'package:plezy/profiles/profile_connection_registry.dart';
import 'package:plezy/profiles/profile_registry.dart';
import 'package:plezy/screens/settings/general_settings_screen.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/prefs.dart';

void main() {
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    LocaleSettings.setLocaleSync(AppLocale.en);
    TvDetectionService.debugSetAppleTVOverride(null);
    await TvDetectionService.getInstance();
    TvDetectionService.setForceTVSync(false);
  });

  tearDown(() {
    TvDetectionService.debugSetAppleTVOverride(null);
    TvDetectionService.setForceTVSync(false);
  });

  Future<({AppDatabase database, PlexHomeService plexHome, ActiveProfileProvider activeProfile})> pumpGeneralScreen(
    WidgetTester tester, {
    Size size = const Size(1000, 1400),
    TargetPlatform? platform,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final connections = ConnectionRegistry(database);
    final profileConnections = ProfileConnectionRegistry(database);
    final profiles = ProfileRegistry(database);
    final plexHome = PlexHomeService(
      connections: connections,
      profileConnections: profileConnections,
      plexHomeUserFetcher: (_) async => const [],
    );
    // Never initialized: zero profiles, so hasMultipleProfiles stays false.
    final activeProfile = ActiveProfileProvider(
      registry: profiles,
      plexHome: plexHome,
      connections: connections,
      profileConnections: profileConnections,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ActiveProfileProvider>.value(
        value: activeProfile,
        child: MaterialApp(
          theme: monoTheme(dark: true).copyWith(platform: platform),
          home: const GeneralSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (database: database, plexHome: plexHome, activeProfile: activeProfile);
  }

  Future<void> disposeHarness(
    WidgetTester tester,
    ({AppDatabase database, PlexHomeService plexHome, ActiveProfileProvider activeProfile}) harness,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    harness.activeProfile.dispose();
    await harness.plexHome.dispose();
    await harness.database.close();
  }

  testWidgets('shows language and startup tiles, hides the profile prompt for a single profile', (tester) async {
    final harness = await pumpGeneralScreen(tester);

    expect(find.text(t.settings.language), findsOneWidget);
    expect(find.text(t.settings.startupSection), findsOneWidget);
    // Only meaningful with several profiles; a lone profile has nothing to pick.
    expect(find.text(t.settings.requireProfileSelectionOnOpen), findsNothing);
    // The test host is a desktop OS, so the window group applies.
    expect(find.text(t.settings.startInFullscreen), findsOneWidget);

    await disposeHarness(tester, harness);
  });

  testWidgets('native TV hides the ineffective force TV switch', (tester) async {
    TvDetectionService.debugSetAppleTVOverride(true);
    final harness = await pumpGeneralScreen(tester, size: const Size(1280, 720));
    expect(find.text(t.settings.forceTvMode), findsNothing);
    expect(find.text(t.settings.startupSection), findsOneWidget);
    await disposeHarness(tester, harness);
  });

  for (final size in [const Size(390, 844), const Size(820, 1180)]) {
    testWidgets('forced TV retains the exit switch on a touch device at $size', (tester) async {
      await SettingsService.instance.write(SettingsService.forceTvMode, true);
      TvDetectionService.setForceTVSync(true);
      final harness = await pumpGeneralScreen(tester, size: size, platform: TargetPlatform.android);
      expect(PlatformDetector.isTV(), isTrue);
      expect(PlatformDetector.isNativeTV(), isFalse);
      await tester.ensureVisible(find.text(t.settings.forceTvMode));
      await tester.tap(find.text(t.settings.forceTvMode));
      await tester.pumpAndSettle();
      expect(SettingsService.instance.read(SettingsService.forceTvMode), isFalse);
      expect(PlatformDetector.isTV(), isFalse);
      expect(find.text(t.settings.forceTvMode), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeHarness(tester, harness);
    });
  }

  testWidgets('changes the persisted startup section', (tester) async {
    final harness = await pumpGeneralScreen(tester);

    await tester.tap(find.text(t.settings.startupSection));
    await tester.pumpAndSettle();
    final librariesLabel = allNavigationTabs.firstWhere((tab) => tab.id == NavigationTabId.libraries).getLabel();
    await tester.tap(find.text(librariesLabel).last);
    await tester.pumpAndSettle();

    final settings = SettingsService.instance;
    expect(settings.read(SettingsService.startupSection), NavigationTabId.libraries);
    expect(settings.prefs.getString(SettingsService.startupSection.key), 'libraries');

    await disposeHarness(tester, harness);
  });

  for (final destination in [
    NavigationTabId.together,
    NavigationTabId.settings,
    NavigationTabId.downloads,
    NavigationTabId.explore,
  ]) {
    testWidgets('startup picker offers and persists ${destination.name}', (tester) async {
      final harness = await pumpGeneralScreen(tester);
      await tester.tap(find.text(t.settings.startupSection));
      await tester.pumpAndSettle();
      final label = allNavigationTabs.firstWhere((tab) => tab.id == destination).getLabel();
      await tester.ensureVisible(find.text(label).last);
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(SettingsService.instance.read(SettingsService.startupSection), destination);
      expect(SettingsService.instance.prefs.getString(SettingsService.startupSection.key), destination.name);
      await disposeHarness(tester, harness);
    });
  }
}
