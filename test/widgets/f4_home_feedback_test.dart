import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/navigation/fusion_navigation.dart';
import 'package:plezy/navigation/navigation_tabs.dart';
import 'package:plezy/services/device_performance.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_presentation.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/fusion_home_hero.dart';
import 'package:plezy/widgets/press_feedback.dart';
import 'package:plezy/widgets/vidhub_ambient_backdrop.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';
import '../test_helpers/preview_fonts.dart';

void main() {
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    DevicePerformance.debugReset();
    LocaleSettings.setLocaleSync(AppLocale.en);
  });
  tearDown(DevicePerformance.debugReset);

  for (final mode in ['reduced', 'highContrast', 'disableAnimations']) {
    testWidgets('$mode removes navigation and ambient filters while retaining content', (tester) async {
      DevicePerformance.debugReset(autoReduced: mode == 'reduced');
      await tester.pumpWidget(
        MaterialApp(
          theme: monoTheme(dark: true),
          home: MediaQuery(
            data: MediaQueryData(highContrast: mode == 'highContrast', disableAnimations: mode == 'disableAnimations'),
            child: Scaffold(
              body: const VidHubAmbientBackdrop(
                accentColor: Colors.blue,
                backdropChild: ColoredBox(key: ValueKey('artwork'), color: Colors.blue),
                child: Text('Content'),
              ),
              bottomNavigationBar: FusionNavigation(
                tabs: NavigationTab.getVisibleTabs(isOffline: false),
                selectedTab: NavigationTabId.discover,
                onSelected: (_) {},
                onSecondary: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byKey(const ValueKey('artwork')), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      final surface = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('fusion-navigation-surface')));
      expect((surface.decoration! as BoxDecoration).color!.a, 1);
      expect(find.byTooltip(t.common.options), findsOneWidget);
    });
  }

  testWidgets('phone options remains a single 48px target and cancelled navigation does not activate', (tester) async {
    var selected = 0;
    var options = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: monoTheme(dark: true),
        home: Scaffold(
          bottomNavigationBar: FusionNavigation(
            tabs: NavigationTab.getVisibleTabs(isOffline: false),
            selectedTab: NavigationTabId.discover,
            onSelected: (_) => selected++,
            onSecondary: () => options++,
          ),
        ),
      ),
    );
    final more = find.byTooltip(t.common.options);
    expect(more, findsOneWidget);
    expect(tester.getSize(more).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(more).height, greaterThanOrEqualTo(48));
    final target = find.text(t.watchTogether.title);
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      tester.widgetList<PressFeedback>(find.byType(PressFeedback)).where((feedback) => feedback.pressed),
      isNotEmpty,
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(selected, 0);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(options, 1);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('TV confirmation ignores key repeats and emits no haptic', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var selections = 0;
    var haptics = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
      InputModeTracker(
        child: MaterialApp(
          theme: monoTheme(dark: true),
          home: Scaffold(
            body: FusionNavigation(
              tabs: NavigationTab.getVisibleTabs(isOffline: false),
              selectedTab: NavigationTabId.discover,
              isTv: true,
              focusNodes: {NavigationTabId.together: node},
              onSelected: (_) => selections++,
              onSecondary: () {},
            ),
          ),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selections, 1);
    expect(haptics, 0);
    expect(
      tester.widgetList<PressFeedback>(find.byType(PressFeedback)).where((feedback) => feedback.pressed),
      isNotEmpty,
    );
    await tester.pumpAndSettle();
  });

  for (final kind in [MediaKind.movie, MediaKind.episode, MediaKind.show, MediaKind.season]) {
    testWidgets('production hero action routes $kind to a playable item or details', (tester) async {
      var plays = 0;
      var details = 0;
      final item = testMediaItem(kind: kind, title: 'Hero');
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                width: 280,
                child: HomeHeroPrimaryButton(item: item, onPlay: () => plays++, onDetails: () => details++),
              ),
            ),
          ),
        ),
      );
      final playable = kind == MediaKind.movie || kind == MediaKind.episode;
      expect(find.text(playable ? t.common.play : t.mediaMenu.viewDetails), findsOneWidget);
      if (!playable) expect(find.text(t.common.play), findsNothing);
      await tester.tap(find.byType(HomeHeroPrimaryButton));
      await tester.pumpAndSettle();
      expect(plays, playable ? 1 : 0);
      expect(details, playable ? 0 : 1);
    });
  }

  for (final fixture in [
    (name: 'phone-dark', size: const Size(390, 844), scale: 1.0, dark: true, tv: false),
    (name: 'phone-light', size: const Size(390, 844), scale: 1.0, dark: false, tv: false),
    (name: 'narrow-large-text', size: const Size(320, 720), scale: 2.0, dark: true, tv: false),
    (name: 'landscape-phone', size: const Size(844, 390), scale: 1.0, dark: true, tv: false),
    (name: 'tablet', size: const Size(768, 1024), scale: 1.0, dark: false, tv: false),
    (name: 'tv', size: const Size(1280, 720), scale: 1.0, dark: true, tv: true),
  ]) {
    testWidgets('${fixture.name} home fixture uses decoded artwork and the production resume action', (tester) async {
      await tester.runAsync(loadPreviewFonts);
      ui.Image? artwork;
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          await File('test/fixtures/artwork/interstellar-backdrop.png').readAsBytes(),
        );
        try {
          artwork = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      });
      expect(artwork, isNotNull);
      expect(artwork!.width, greaterThan(1));
      expect(artwork!.height, greaterThan(1));
      final previousPlatform = debugDefaultTargetPlatformOverride;
      final previousLocale = LocaleSettings.currentLocale;
      final semantics = fixture.scale > 1 ? tester.ensureSemantics() : null;
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        TvDetectionService.debugSetAppleTVOverride(fixture.tv);
        // Deferred translations need the real event loop to finish loading.
        await tester.runAsync(() async {
          await LocaleSettings.setLocale(AppLocale.zh);
        });
        expect(LocaleSettings.currentLocale, AppLocale.zh);
        tester.view.physicalSize = fixture.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        Future<void> captureFixture(String name) async {
          if (!const bool.fromEnvironment('UPDATE_VELO_F4_SCREENSHOTS')) {
            return;
          }
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(
              pixelRatio: 1,
            );
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('/tmp/velo-f4-fixtures-20261111/$name.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        var plays = 0;
        var details = 0;
        final title = fixture.scale > 1 ? '星际穿越：跨越时空的探索之旅与导演加长版本' : '星际穿越';
        final item = testMediaItem(title: title, year: 2014, rating: 8.7, durationMs: 6000000, viewOffsetMs: 2100000);
        final resumeLabel = t.discover.minutesLeft(minutes: 65);
        expect(resumeLabel, matches(RegExp(r'[\u4e00-\u9fff]')));
        await tester.pumpWidget(
          MaterialApp(
            theme: previewFontTheme(monoTheme(dark: fixture.dark)),
            home: MediaQuery(
              data: MediaQueryData(
                size: fixture.size,
                textScaler: TextScaler.linear(fixture.scale),
                disableAnimations: true,
              ),
              child: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                  body: Builder(
                    builder: (context) {
                      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
                      final heroHeight =
                          (MonoPresentation.touchHeroHeight(context) * pixelRatio).ceilToDouble() / pixelRatio;
                      final hero = FusionHomeHero(
                        item: item,
                        compact: fixture.scale > 1 ? heroHeight < 450 : fixture.size.height < 450,
                        backdrop: RawImage(
                          key: const ValueKey('decoded-home-artwork'),
                          image: artwork,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -.6),
                        ),
                        onPlay: () => details++,
                        playButton: HomeHeroPrimaryButton(
                          item: item,
                          isTv: fixture.tv,
                          onPlay: () => plays++,
                          onDetails: () => details++,
                        ),
                        detailsButton: OutlinedButton(
                          onPressed: () => details++,
                          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                          child: Text(t.mediaMenu.viewDetails),
                        ),
                      );
                      // Match Discover's sliver and rounded production height;
                      // a full-body hero would give the large-text case extra room.
                      return fixture.scale > 1
                          ? CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: SizedBox(height: heroHeight, child: hero),
                                ),
                              ],
                            )
                          : hero;
                    },
                  ),
                  bottomNavigationBar: FusionNavigation(
                    tabs: NavigationTab.getVisibleTabs(isOffline: false),
                    selectedTab: NavigationTabId.discover,
                    isTv: fixture.tv,
                    onSelected: (_) {},
                    onSecondary: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(tester.widget<RawImage>(find.byKey(const ValueKey('decoded-home-artwork'))).image, same(artwork));
        expect(find.byKey(const ValueKey('home-hero-play-progress')), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.byTooltip(t.common.options), findsOneWidget);
        if (fixture.scale > 1) {
          expect(tester.getSize(find.byType(FusionHomeHero)).height, 532);
          final scroll = find.descendant(of: find.byType(FusionHomeHero), matching: find.byType(SingleChildScrollView));
          final scrollable = tester.state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)),
          );
          expect(scrollable.position.axisDirection, AxisDirection.up);
          expect(scrollable.position.maxScrollExtent, greaterThan(0));
          final viewport = tester.getRect(scroll);
          void expectInsideViewport(Rect rect) {
            expect(rect.top, greaterThanOrEqualTo(viewport.top - .5));
            expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + .5));
            expect(rect.left, greaterThanOrEqualTo(viewport.left - .5));
            expect(rect.right, lessThanOrEqualTo(viewport.right + .5));
          }

          void expectTitleStartVisible() {
            final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
            final painter = TextPainter(
              text: paragraph.text,
              textAlign: paragraph.textAlign,
              textDirection: paragraph.textDirection,
              textScaler: paragraph.textScaler,
              locale: paragraph.locale,
              maxLines: paragraph.maxLines,
              strutStyle: paragraph.strutStyle,
              textWidthBasis: paragraph.textWidthBasis,
              textHeightBehavior: paragraph.textHeightBehavior,
            )..layout(minWidth: paragraph.constraints.minWidth, maxWidth: paragraph.constraints.maxWidth);
            try {
              final origin = paragraph.localToGlobal(Offset.zero);
              final line = painter.computeLineMetrics().first;
              expect(origin.dy, closeTo(viewport.top, .5));
              // CJK selection boxes include font extents above the laid-out
              // line. Test the actual line metrics, not that selection area.
              expectInsideViewport(
                Rect.fromLTRB(
                  origin.dx + line.left,
                  origin.dy + line.baseline - line.ascent,
                  origin.dx + line.left + line.width,
                  origin.dy + line.baseline + line.descent,
                ),
              );
            } finally {
              painter.dispose();
            }
            expect(find.bySemanticsLabel(RegExp(RegExp.escape(title))), findsWidgets);
          }

          Future<void> dragToEnd({required bool titleStart}) async {
            final target = titleStart ? scrollable.position.maxScrollExtent : scrollable.position.minScrollExtent;
            for (var attempt = 0; attempt < 12 && (scrollable.position.pixels - target).abs() > .5; attempt++) {
              await tester.drag(scroll, Offset(0, viewport.height * (titleStart ? .75 : -.75)));
              await tester.pumpAndSettle();
            }
            expect(scrollable.position.pixels, closeTo(target, .5));
            expect(plays, 0, reason: 'Scrolling must not activate the production play action');
            expect(details, 0, reason: 'Scrolling must not activate the hero or details action');
            expect(tester.takeException(), isNull);
          }

          await dragToEnd(titleStart: true);
          await captureFixture('${fixture.name}-title-top');
          expectTitleStartVisible();
          await dragToEnd(titleStart: false);
          expectInsideViewport(tester.getRect(find.byType(HomeHeroPrimaryButton)));
          expectInsideViewport(tester.getRect(find.byType(OutlinedButton)));
          for (final label in [resumeLabel, t.mediaMenu.viewDetails]) {
            final node = tester.getSemantics(find.bySemanticsLabel(label));
            expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
          }
          await captureFixture('${fixture.name}-actions');
          await dragToEnd(titleStart: true);
          expectTitleStartVisible();
          await dragToEnd(titleStart: false);
        }
        await tester.ensureVisible(find.text(resumeLabel));
        await tester.tap(find.text(resumeLabel));
        await tester.pumpAndSettle();
        expect(plays, 1);
        expect(details, 0);
        await tester.ensureVisible(find.text(t.mediaMenu.viewDetails));
        await tester.tap(find.text(t.mediaMenu.viewDetails));
        await tester.pumpAndSettle();
        expect(details, 1);
        expect(tester.takeException(), isNull);
        await captureFixture(fixture.name);
      } finally {
        try {
          await tester.pumpWidget(const SizedBox());
        } finally {
          artwork?.dispose();
          semantics?.dispose();
          LocaleSettings.setLocaleSync(previousLocale);
          debugDefaultTargetPlatformOverride = previousPlatform;
          TvDetectionService.debugSetAppleTVOverride(null);
        }
      }
    });
  }
}
