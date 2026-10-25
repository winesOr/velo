import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/navigation/fusion_navigation.dart';
import 'package:plezy/navigation/navigation_tabs.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/focusable_list_tile.dart';
import 'package:plezy/widgets/setting_tile.dart';
import 'package:plezy/widgets/settings_section.dart';
import 'package:plezy/widgets/video_controls/sheets/player_settings_controls.dart';

import '../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pulses = <Object?>[];

  setUp(() async {
    TvDetectionService.debugSetAppleTVOverride(false);
    LocaleSettings.setLocaleSync(AppLocale.en);
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    pulses.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') pulses.add(call.arguments);
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    TvDetectionService.debugSetAppleTVOverride(null);
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    InputModeTracker(
      child: MaterialApp(
        theme: monoTheme(dark: false),
        home: Scaffold(body: child),
      ),
    ),
  );

  testWidgets('opening settings is silent; changing a switch pulses once and reapplying its value is silent', (
    tester,
  ) async {
    var opened = 0;
    await pump(
      tester,
      SettingsGroup(
        children: [
          SettingNavigationTile(icon: Symbols.settings_rounded, title: 'Open preferences', onTap: () => opened++),
          const SettingSwitchTile(
            pref: SettingsService.showPerformanceOverlay,
            icon: Symbols.speed_rounded,
            title: 'Overlay',
          ),
        ],
      ),
    );
    await tester.tap(find.text('Open preferences'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(pulses, isEmpty);
    await tester.tap(find.text('Overlay'));
    await tester.pumpAndSettle();
    expect(SettingsService.instance.read(SettingsService.showPerformanceOverlay), isTrue);
    expect(pulses, ['HapticFeedbackType.lightImpact']);
    tester.widget<FocusableSwitchListTile>(find.byType(FocusableSwitchListTile)).onChanged!(true);
    await tester.pumpAndSettle();
    expect(pulses.length, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a persisted segmented preference emits one pulse instead of two', (tester) async {
    await pump(
      tester,
      const SettingSegmentedTile<double>(
        pref: SettingsService.longPressSpeed,
        icon: Symbols.speed_rounded,
        title: 'Speed',
        segments: [
          ButtonSegment(value: 2.0, label: Text('2x')),
          ButtonSegment(value: 3.0, label: Text('3x')),
        ],
      ),
    );
    await tester.tap(find.text('3x'));
    await tester.pumpAndSettle();
    expect(SettingsService.instance.read(SettingsService.longPressSpeed), 3);
    expect(pulses, ['HapticFeedbackType.lightImpact']);
    await tester.tap(find.text('3x'));
    await tester.pumpAndSettle();
    expect(pulses.length, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('bottom navigation pulses only when the destination changes', (tester) async {
    var selected = NavigationTabId.discover;
    await pump(
      tester,
      StatefulBuilder(
        builder: (_, update) => Align(
          alignment: Alignment.bottomCenter,
          child: FusionNavigation(
            tabs: NavigationTab.getVisibleTabs(isOffline: false),
            selectedTab: selected,
            onSelected: (tab) => update(() => selected = tab),
            onSecondary: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text(t.common.home));
    await tester.pumpAndSettle();
    expect(pulses, isEmpty);
    await tester.tap(find.text(t.libraries.title));
    await tester.pumpAndSettle();
    expect(selected, NavigationTabId.libraries);
    expect(pulses, ['HapticFeedbackType.lightImpact']);
    await tester.tap(find.text(t.libraries.title));
    await tester.pumpAndSettle();
    expect(pulses.length, 1);
    await tester.tap(find.text(t.common.home));
    await tester.pumpAndSettle();
    expect(pulses.length, 2);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('player panels and actions are silent; changing a setting pulses once', (tester) async {
    var selected = false;
    await pump(
      tester,
      StatefulBuilder(
        builder: (_, update) => Column(
          children: [
            PlayerDrawerChoice(label: 'Panel', selected: false, tab: true, onTap: () {}),
            PlayerDrawerChoice(label: 'Search', selected: false, feedbackOnChange: false, onTap: () {}),
            PlayerDrawerChoice(label: 'Choice', selected: selected, onTap: () => update(() => selected = true)),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Panel'));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(pulses, isEmpty);
    await tester.tap(find.text('Choice'));
    await tester.pumpAndSettle();
    expect(pulses, ['HapticFeedbackType.lightImpact']);
    await tester.tap(find.text('Choice'));
    await tester.pumpAndSettle();
    expect(pulses.length, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final tv in [true, false]) {
    testWidgets('${tv ? 'TV' : 'desktop'} setting changes do not vibrate', (tester) async {
      TvDetectionService.debugSetAppleTVOverride(tv);
      await pump(
        tester,
        const SettingSwitchTile(
          pref: SettingsService.showPerformanceOverlay,
          icon: Symbols.speed_rounded,
          title: 'Overlay',
        ),
      );
      await tester.tap(find.text('Overlay'));
      await tester.pumpAndSettle();
      expect(pulses, isEmpty);
      expect(SettingsService.instance.read(SettingsService.showPerformanceOverlay), isTrue);
    }, variant: TargetPlatformVariant.only(tv ? TargetPlatform.android : TargetPlatform.macOS));
  }
}
