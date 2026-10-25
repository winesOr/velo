import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/danmaku/danmaku_session.dart';
import 'package:plezy/danmaku/danmaku_settings_repository.dart';
import 'package:plezy/focus/focusable_slider.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/screens/settings/danmaku_settings_entry.dart';
import 'package:plezy/screens/settings/settings_category_pane.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/focusable_list_tile.dart';
import 'package:plezy/widgets/overlay_sheet.dart';
import 'package:plezy/widgets/video_controls/sheets/danmaku_settings_sheet.dart';
import 'package:plezy/widgets/video_controls/sheets/danmaku_sources_sheet.dart';

class _Store {
  String? value;
  DanmakuSettingsRepository get repository => DanmakuSettingsRepository(
    read: () async => value,
    write: (next) async => value = next,
    protect: (v) async => v,
    reveal: (v) async => v,
  );
}

Future<void> _loadFonts() async {
  await (FontLoader('FusionFixture')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
  await (FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
}

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(390, 844)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await _loadFonts();
  await tester.pumpWidget(
    InputModeTracker(
      child: MaterialApp(
        theme: monoTheme(
          dark: true,
        ).copyWith(textTheme: monoTheme(dark: true).textTheme.apply(fontFamily: 'FusionFixture')),
        home: Scaffold(body: OverlaySheetHost(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets('settings entry and playback panel share immediate values and restart restoration', (tester) async {
    final store = _Store();
    final session = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(session.dispose);
    await session.updateStyle(enabled: false, fontSize: 22, opacity: .7);
    await _pump(tester, DanmakuSettingsEntry(session: session));
    expect(find.text('22 px · Opacity 70%'), findsOneWidget);
    await tester.tap(find.text(t.danmaku.title).last);
    await tester.pumpAndSettle();
    expect(find.byType(DanmakuSettingsSheet), findsOneWidget);
    final slider = tester.widget<FocusableSlider>(find.byKey(const ValueKey('danmaku-font-size')));
    slider.onChanged!(26);
    await tester.pumpAndSettle();
    expect(session.fontSize, 26);
    final controller = OverlaySheetController.of(tester.element(find.byType(DanmakuSettingsSheet)));
    controller.close();
    await tester.pumpAndSettle();
    expect(find.text('26 px · Opacity 70%'), findsOneWidget);
    final restored = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.fontSize, 26);
    expect(restored.opacity, .7);
    await _pump(tester, DanmakuSettingsSheet(session: restored));
    expect(tester.widget<FocusableSlider>(find.byKey(const ValueKey('danmaku-font-size'))).value, 26);
  });

  testWidgets('TV categories hand focus right to real controls and left back to selected category', (tester) async {
    TvDetectionService.debugSetAppleTVOverride(true);
    addTearDown(() => TvDetectionService.debugSetAppleTVOverride(null));
    final store = _Store();
    final session = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(session.dispose);
    await session.updateStyle(enabled: false, fontSize: 22, heatmapEnabled: true);
    final boundary = GlobalKey();
    await _pump(
      tester,
      RepaintBoundary(
        key: boundary,
        child: SettingsCategoryPane(
          categories: [
            SettingsCategory(
              id: 'connections',
              title: t.connections.sectionTitle,
              icon: Symbols.dns_rounded,
              builder: (_) => const Text('Connections'),
            ),
            SettingsCategory(
              id: 'danmaku',
              title: t.danmaku.title,
              icon: Symbols.subtitles_rounded,
              builder: (_) => DanmakuSettingsSheet(session: session, settingsPage: true),
            ),
          ],
        ),
      ),
      size: const Size(960, 540),
    );
    final category = tester.widget<FocusableListTile>(
      find.byWidgetPredicate((w) => w is FocusableListTile && w.focusNode?.debugLabel == 'settings_category_danmaku'),
    );
    category.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    expect(find.byType(DanmakuSettingsSheet), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(category.focusNode!.hasFocus, isFalse);
    expect(
      FocusManager.instance.primaryFocus?.ancestors.any((n) => n.debugLabel == 'settings_category_details'),
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(category.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(boundary), matchesGoldenFile('goldens/fusion_settings_tv.png'));
  });

  testWidgets('compact entry opens grouped settings and system back returns from sources to the settings page', (
    tester,
  ) async {
    final session = DanmakuSession.forTesting(repository: _Store().repository);
    addTearDown(session.dispose);
    await session.updateStyle(enabled: false);
    await _pump(tester, DanmakuSettingsEntry(session: session, compact: true));
    await tester.tap(find.text(t.danmaku.title).last);
    await tester.pumpAndSettle();
    expect(find.byType(DanmakuSettingsPage), findsOneWidget);
    expect(find.text(t.settings.noDanmakuSources), findsNothing);
    await expectLater(find.byType(DanmakuSettingsPage), matchesGoldenFile('goldens/danmaku_settings_phone.png'));
    await tester.tap(find.byKey(const ValueKey('danmaku-manage-sources')));
    await tester.pumpAndSettle();
    expect(find.byType(DanmakuSourcesSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DanmakuSourcesSheet), findsNothing);
    expect(find.byType(DanmakuSettingsPage), findsOneWidget);
    final toggle = tester.widget<FocusableSwitchListTile>(find.byKey(const ValueKey('danmaku-heatmap')));
    toggle.onChanged!(!session.heatmapEnabled);
    await tester.pumpAndSettle();
    expect(session.heatmapEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
