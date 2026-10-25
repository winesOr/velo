import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/navigation/fusion_navigation.dart';
import 'package:plezy/navigation/home_theme.dart';
import 'package:plezy/navigation/navigation_tabs.dart';
import 'package:plezy/widgets/fusion_home_hero.dart';
import 'package:plezy/widgets/hero_metadata_badges.dart';
import 'package:plezy/media/media_version.dart';
import 'package:plezy/theme/mono_presentation.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/theme/velo_brand.dart';

import '../test_helpers/media_items.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Go Noto Current')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    await (FontLoader(
      'packages/material_symbols_icons/MaterialSymbolsRounded',
    )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
  });
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  test('overflow keeps extra destinations and excludes primary navigation and search', () {
    final tabs = secondaryNavigationTabs(
      NavigationTab.getVisibleTabs(isOffline: false, hasLiveTv: true, hasExplore: true),
    );
    expect(tabs.map((tab) => tab.id), [NavigationTabId.liveTv, NavigationTabId.explore, NavigationTabId.downloads]);
    expect(secondaryNavigationTabs(NavigationTab.getVisibleTabs(isOffline: true)).map((tab) => tab.id), [
      NavigationTabId.downloads,
    ]);
  });

  testWidgets('home navigation respects light appearance over artwork', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: monoTheme(dark: false),
        home: Scaffold(
          bottomNavigationBar: FusionNavigation(
            tabs: NavigationTab.getVisibleTabs(isOffline: false),
            selectedTab: NavigationTabId.discover,
            onSelected: (_) {},
            onSecondary: () {},
          ),
        ),
      ),
    );
    final label = tester.widget<Text>(find.text(t.common.home));
    expect(label.style!.color, VeloBrand.foreground(Brightness.light));
    final surface = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect((surface.decoration! as BoxDecoration).color!.computeLuminance(), greaterThan(.7));
  });

  for (final dark in [false, true]) {
    testWidgets('${dark ? 'dark' : 'light'} navigation matches the compact unshadowed surface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: monoTheme(dark: dark),
          home: Scaffold(
            bottomNavigationBar: FusionNavigation(
              tabs: NavigationTab.getVisibleTabs(isOffline: false),
              selectedTab: NavigationTabId.libraries,
              onSelected: (_) {},
              onSecondary: () {},
            ),
          ),
        ),
      );
      final surface = find.byType(AnimatedContainer);
      expect(tester.getSize(surface).height, MonoPresentation.navigationHeight);
      expect(tester.getSize(surface).width, MonoPresentation.navigationMaxWidth);
      final decoration = tester.widget<AnimatedContainer>(surface).decoration! as BoxDecoration;
      expect(decoration.color, MonoPresentation.navigationSurface(dark ? Brightness.dark : Brightness.light));
      expect(decoration.boxShadow, isNull);
      final labels = tester.widgetList<Text>(
        find.descendant(of: find.byType(FusionNavigation), matching: find.byType(Text)),
      );
      expect(labels.every((label) => label.style!.fontSize == 10), isTrue);
      final boxes = tester.widgetList<Container>(
        find.descendant(of: find.byType(FusionNavigation), matching: find.byType(Container)),
      );
      for (final box in boxes) {
        if (box.decoration case final BoxDecoration decoration) expect(decoration.boxShadow, isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('four primary destinations do not remove legacy online destinations', () {
    final visible = NavigationTab.getVisibleTabs(isOffline: false, hasLiveTv: true, hasExplore: true);
    expect(primaryNavigationTabs(visible).map((tab) => tab.id), primaryNavigationIds);
    for (final id in [
      NavigationTabId.downloads,
      NavigationTabId.liveTv,
      NavigationTabId.search,
      NavigationTabId.explore,
    ]) {
      expect(visible.map((tab) => tab.id), contains(id));
      expect(
        NavigationTab.resolveDefaultTab(isOffline: false, hasLiveTv: true, hasExplore: true, preferredStartup: id),
        id,
      );
    }
    expect(NavigationTab.getVisibleTabs(isOffline: true).map((tab) => tab.id), [
      NavigationTabId.downloads,
      NavigationTabId.settings,
    ]);
    expect(NavigationTabId.values.byName('downloads'), NavigationTabId.downloads);
    expect(NavigationTabId.values.byName('settings'), NavigationTabId.settings);
  });

  testWidgets('TV search and options support keyboard activation and down-to-content', (tester) async {
    final nodes = {for (final id in NavigationTabId.values) id: FocusNode()};
    addTearDown(() {
      for (final node in nodes.values) {
        node.dispose();
      }
    });
    NavigationTabId? selected;
    var down = 0;
    var options = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: InputModeTracker(
          child: Material(
            child: FusionNavigation(
              tabs: NavigationTab.getVisibleTabs(isOffline: false),
              selectedTab: NavigationTabId.discover,
              isTv: true,
              focusNodes: nodes,
              onSelected: (id) => selected = id,
              onSecondary: () => options++,
              onNavigateDown: () => down++,
            ),
          ),
        ),
      ),
    );
    nodes[NavigationTabId.together]!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, NavigationTabId.together);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(down, 1);
    await tester.tap(find.byTooltip(t.common.options));
    expect(options, 1);
    expect(find.text(t.common.search), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final fixture in [
    (name: 'phone', size: const Size(390, 844), scale: 1.0, tv: false),
    (name: 'narrow', size: const Size(320, 640), scale: 2.0, tv: false),
    (name: 'tablet-portrait', size: const Size(820, 1180), scale: 1.0, tv: false),
    (name: 'tablet-landscape', size: const Size(1180, 820), scale: 1.0, tv: false),
    (name: 'tablet-large-text', size: const Size(820, 1180), scale: 2.0, tv: false),
    (name: 'tv', size: const Size(960, 540), scale: 1.0, tv: true),
    (name: 'desktop', size: const Size(1280, 800), scale: 1.0, tv: true),
  ]) {
    testWidgets('${fixture.name} missing-artwork hero, safe area and navigation remain playable', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = fixture.size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = HomeThemeController();
      addTearDown(controller.dispose);
      final boundary = GlobalKey();
      var plays = 0;
      NavigationTabId? selected;
      final item = testMediaItem(
        title: 'A server title without artwork',
        year: 2026,
        rating: 8.2,
        serverId: 'fixture-server',
      );
      final hero = FusionHomeHero(
        item: item,
        compact: fixture.tv,
        backdrop: const ColoredBox(color: Color(0xff16191d)),
        onPlay: () => plays++,
        playButton: TextButton(onPressed: () => plays++, child: Text(t.common.play)),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Go Noto Current')),
          home: MediaQuery(
            data: MediaQueryData(
              size: fixture.size,
              padding: const EdgeInsets.only(top: 24, bottom: 20),
              textScaler: TextScaler.linear(fixture.scale),
              disableAnimations: true,
            ),
            child: HomeThemeScope(
              controller: controller,
              child: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                  extendBody: !fixture.tv,
                  body: Column(
                    children: [
                      if (fixture.tv)
                        FusionNavigation(
                          tabs: NavigationTab.getVisibleTabs(isOffline: false),
                          selectedTab: NavigationTabId.discover,
                          isTv: true,
                          onSelected: (id) => selected = id,
                          onSecondary: () {},
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 120),
                          child: SizedBox(height: fixture.tv ? 370 : 580 + (fixture.scale - 1) * 64, child: hero),
                        ),
                      ),
                    ],
                  ),
                  bottomNavigationBar: fixture.tv
                      ? null
                      : FusionNavigation(
                          tabs: NavigationTab.getVisibleTabs(isOffline: false),
                          selectedTab: NavigationTabId.discover,
                          onSelected: (id) => selected = id,
                          onSecondary: () {},
                        ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(item.displayTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (!fixture.tv) {
        final surface = find.descendant(of: find.byType(FusionNavigation), matching: find.byType(AnimatedContainer));
        final bounds = tester.getRect(surface);
        expect(bounds.width, lessThanOrEqualTo(MonoPresentation.navigationMaxWidth));
        expect(bounds.center.dx, closeTo(fixture.size.width / 2, .01));
        expect(bounds.bottom, closeTo(fixture.size.height - 20, .01));
        final body = tester.getRect(find.byType(SingleChildScrollView));
        expect(body.left, 0);
        expect(body.width, fixture.size.width);
      }
      await tester.tap(find.text(t.watchTogether.title));
      expect(selected, NavigationTabId.together);
      await tester.ensureVisible(find.text(t.common.play));
      if (!fixture.tv) {
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -100));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(t.common.play));
      expect(plays, 1);
      expect(tester.takeException(), isNull);
      final animations = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(animations.where((widget) => widget.duration == Duration.zero), isNotEmpty);
      if (const bool.fromEnvironment('UPDATE_FUSION_SCREENSHOTS')) {
        await tester.pumpAndSettle();
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('docs/fixtures/fusion-shell-${fixture.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('hero badges show genres alongside rating, year and certification', (tester) async {
    final controller = HomeThemeController();
    addTearDown(controller.dispose);
    Future<void> pumpHero(List<String>? genres) => tester.pumpWidget(
      MaterialApp(
        home: HomeThemeScope(
          controller: controller,
          child: FusionHomeHero(
            item: testMediaItem(title: 'Hero', year: 2026, rating: 9.5, contentRating: 'PG-13', genres: genres),
            backdrop: const SizedBox(),
            onPlay: () {},
          ),
        ),
      ),
    );

    await pumpHero(['Drama', 'Family', 'Romance']);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.textContaining('Romance'), findsNothing);
    expect(find.text('PG-13'), findsOneWidget);

    await pumpHero(const []);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('PG-13'), findsOneWidget);
  });
  testWidgets('hero labels wrap at large text and show only known quality', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: HeroMetadataBadges(
              item: testMediaItem(
                year: 2026,
                contentRating: 'PG-13',
                genres: ['Science Fiction', 'Adventure'],
                mediaVersions: [MediaVersion(id: '4k', videoResolution: '4k')],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('4K'), findsOneWidget);
    expect(find.text('HDR'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(home: HeroMetadataBadges(item: testMediaItem(year: null))));
    expect(find.text('4K'), findsNothing);
    expect(find.text('HDR'), findsNothing);
  });
}
