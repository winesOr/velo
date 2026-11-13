import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plezy/media/ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/connection/connection.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/connection/connection_registry.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_library.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/media/server_capabilities.dart';
import 'package:plezy/navigation/fusion_navigation.dart';
import 'package:plezy/navigation/main_screen_scope.dart';
import 'package:plezy/navigation/home_theme.dart';
import 'package:plezy/navigation/navigation_tabs.dart';
import 'package:plezy/profiles/active_profile_provider.dart';
import 'package:plezy/profiles/plex_home_service.dart';
import 'package:plezy/profiles/profile.dart';
import 'package:plezy/profiles/profile_connection.dart';
import 'package:plezy/profiles/profile_connection_registry.dart';
import 'package:plezy/profiles/profile_registry.dart';
import 'package:plezy/providers/companion_remote_provider.dart';
import 'package:plezy/providers/discover_provider.dart';
import 'package:plezy/providers/hidden_libraries_provider.dart';
import 'package:plezy/providers/libraries_provider.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/screens/discover_screen.dart';
import 'package:plezy/screens/media_detail_screen.dart';
import 'package:plezy/widgets/hero_text_blocks.dart';
import 'package:plezy/services/image_cache_service.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/services/storage_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/utils/ambient_palette_extractor.dart';
import 'package:plezy/watch_together/watch_together.dart';
import 'package:plezy/widgets/side_navigation_rail.dart';
import 'package:plezy/widgets/fusion_home_hero.dart';
import 'package:plezy/widgets/cycling_media_backdrop.dart';
import 'package:plezy/widgets/media_card.dart';
import 'package:plezy/widgets/tv_browse_rail.dart';
import 'package:plezy/widgets/tv_spotlight_background.dart';
import 'package:provider/provider.dart';

import '../test_helpers/prefs.dart';
import '../test_helpers/tablet_screenshots.dart';
import '../test_helpers/io_fakes.dart';
import '../test_helpers/media_items.dart';
import '../test_helpers/multi_server_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory artworkDirectory;
  late PathProviderPlatform previousPathProvider;

  setUpAll(() async {
    artworkDirectory = Directory.systemTemp.createTempSync('home-visual-audit-');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProvider(artworkDirectory);
    for (final asset in ['dune', 'interstellar', 'spirited', 'blade', 'interstellar-backdrop']) {
      final url = 'https://home-visual.fixture/$asset.jpg';
      await PlexImageCacheManager.instance.putFile(
        url,
        await File('test/fixtures/artwork/$asset.png').readAsBytes(),
        key: 'plex_optimized_${sha1.convert(utf8.encode(url))}',
        fileExtension: 'png',
      );
    }
    await initializeDateFormatting('en');
    await LocaleSettings.setLocale(AppLocale.zh);
    await (FontLoader('Go Noto Current')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    // Stand in for the platform serif face in the deterministic test renderer.
    await (FontLoader('Georgia')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    if (Platform.environment['VELO_R1_SCREENSHOTS']?.isNotEmpty == true) {
      // Supply real glyphs for RichText's unqualified default font in visual runs.
      await (FontLoader('Ahem')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    }
    await (FontLoader(
      'packages/material_symbols_icons/MaterialSymbolsRounded',
    )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
  });

  tearDownAll(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await artworkDirectory.delete(recursive: true);
  });

  setUp(() {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    TvDetectionService.debugSetAppleTVOverride(true);
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  tearDown(() {
    TvDetectionService.debugSetAppleTVOverride(null);
  });

  for (final size in [const Size(820, 1180), const Size(1180, 820), const Size(600, 960)]) {
    testWidgets('tablet home uses the fusion artwork and readable shelves at $size', (tester) async {
      var toolbarOpens = 0;
      var navigationOpens = 0;
      final controller = HomeThemeController();
      addTearDown(controller.dispose);
      final boundary = GlobalKey();
      final movie = testMediaItem(
        id: 'tablet-film',
        title: '沙丘：第二部',
        originalTitle: 'DUNE PART TWO',
        year: 2024,
        rating: 8.3,
        serverId: 'server_1',
        thumbPath: 'https://home-visual.fixture/dune.jpg',
        artPath: 'https://home-visual.fixture/interstellar-backdrop.jpg',
        durationMs: 6000000,
        viewOffsetMs: 1800000,
      );
      await _pumpDiscoverShell(
        tester,
        isTv: false,
        size: size,
        fixtureFont: true,
        onOpenNavigation: () => toolbarOpens++,
        clients: [
          _FakeMediaServerClient(
            continueWatching: [movie],
            hubs: [
              MediaHub(id: 'recent', title: 'Recently added', type: 'movie', items: [movie], more: true),
            ],
          ),
        ],
        wrap: (child) => HomeThemeScope(
          controller: controller,
          child: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              extendBody: true,
              body: child,
              bottomNavigationBar: FusionNavigation(
                tabs: NavigationTab.getVisibleTabs(isOffline: false),
                selectedTab: NavigationTabId.discover,
                onSelected: (_) {},
                onSecondary: () => navigationOpens++,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
        if (controller.color != AmbientPaletteExtractor.defaultFallback &&
            find.byType(RawImage).evaluate().any((e) => (e.widget as RawImage).image != null)) {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(FusionHomeHero), findsWidgets);
      expect(tester.getSize(find.byType(FusionHomeHero).first).height, lessThan(size.height * .75));
      final homeOptions = find.descendant(of: find.byType(DiscoverScreen), matching: find.byTooltip(t.common.options));
      final navigationOptions = find.descendant(
        of: find.byType(FusionNavigation),
        matching: find.byTooltip(t.common.options),
      );
      expect(homeOptions, findsOneWidget);
      expect(navigationOptions, findsOneWidget);
      expect(
        tester.widget<IconButton>(find.ancestor(of: homeOptions, matching: find.byType(IconButton))).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<InkWell>(find.descendant(of: navigationOptions, matching: find.byType(InkWell))).onTap,
        isNotNull,
      );
      await tester.tap(homeOptions);
      await tester.tap(navigationOptions);
      await tester.pump(const Duration(milliseconds: 250));
      expect(toolbarOpens, 1);
      expect(navigationOpens, 1);
      expect(tester.takeException(), isNull);
      await captureTablet(tester, find.byKey(boundary), 'home-${size.width.toInt()}');
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final tv in [false]) {
    testWidgets('${tv ? 'TV' : 'phone'} Home keeps resume overlays and adds recommendation scores', (tester) async {
      final movie = testMediaItem(
        id: 'resume-progress',
        rating: 8.6,
        title: 'Resume Movie',
        serverId: 'server_1',
        durationMs: 4003000,
        viewOffsetMs: 2238000,
      );
      await _pumpDiscoverShell(
        tester,
        isTv: tv,
        size: tv ? const Size(1280, 720) : const Size(390, 844),
        clients: [
          _FakeMediaServerClient(
            continueWatching: [movie],
            hubs: [
              MediaHub(id: 'recommended', title: 'Recommended', type: 'movie', items: [movie]),
            ],
          ),
        ],
      );
      final cards = tester.widgetList<MediaCard>(find.byType(MediaCard, skipOffstage: false)).toList();
      expect(cards.where((card) => card.isInContinueWatching), isNotEmpty);
      expect(cards.where((card) => card.isInContinueWatching).every((card) => card.showWatchProgress), isTrue);
      expect(
        find.descendant(
          of: find.byWidgetPredicate((widget) => widget is MediaCard && widget.isInContinueWatching),
          matching: find.byKey(ValueKey('recommendation-score-${movie.globalKey}')),
        ),
        findsNothing,
        reason: 'Continue Watching keeps its original artwork overlays',
      );
      if (tv) {
        final rail = tester.widget<TvBrowseRail>(find.byType(TvBrowseRail));
        expect(rail.showRatingBadges, isTrue);
        expect(find.byKey(ValueKey('recommendation-score-${movie.globalKey}')), findsOneWidget);
        for (final hub in rail.hubs) {
          expect(rail.showWatchProgressForHub!(hub), hub.isContinueWatchingHub);
        }
      } else {
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 300));
        final recommendations = tester
            .widgetList<MediaCard>(find.byType(MediaCard, skipOffstage: false))
            .where((card) => !card.isInContinueWatching);
        expect(recommendations, isNotEmpty);
        expect(recommendations.every((card) => !card.showWatchProgress), isTrue);
        expect(find.byKey(ValueKey('recommendation-score-${movie.globalKey}')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(ValueKey('recommendation-score-${movie.globalKey}')),
            matching: find.text('8.6'),
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  _registerR1Tests();
}

/// Mounts [DiscoverScreen] in the smallest graph both layout branches need, so
/// one test can compare the TV and non-TV chrome without rebuilding it twice.
Future<void> _pumpDiscoverShell(
  WidgetTester tester, {
  required bool isTv,
  bool dark = true,
  bool oled = false,
  double textScale = 1,
  List<NavigatorObserver> navigatorObservers = const [],
  List<MediaServerClient>? clients,
  Size size = const Size(1280, 720),
  Widget Function(Widget)? wrap,
  bool fixtureFont = false,
  bool settle = true,
  math.Random? heroRandom,
  bool prepareHomeBeforeMount = false,
  VoidCallback? onOpenNavigation,
}) async {
  TvDetectionService.debugSetAppleTVOverride(isTv);
  await SettingsService.getInstance();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  final manager = MultiServerManager();
  for (final client in clients ?? [_FakeMediaServerClient(hubs: const [])]) {
    manager.debugRegisterClientForTesting(client);
  }
  final multiServerProvider = testMultiServerProvider(manager);
  final hiddenLibrariesProvider = HiddenLibrariesProvider();
  final librariesProvider = LibrariesProvider();
  final watchTogetherProvider = WatchTogetherProvider();
  final companionRemoteProvider = CompanionRemoteProvider();

  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final storage = await StorageService.getInstance();
  final connectionRegistry = _FakeConnectionRegistry(db);
  final profileConnectionRegistry = _FakeProfileConnectionRegistry(db);
  final plexHome = PlexHomeService(
    connections: connectionRegistry,
    profileConnections: profileConnectionRegistry,
    storage: storage,
    plexHomeUserFetcher: (_) async => const [],
  );
  final activeProfileProvider = ActiveProfileProvider(
    registry: _FakeProfileRegistry(db),
    plexHome: plexHome,
    connections: connectionRegistry,
    profileConnections: profileConnectionRegistry,
    storage: storage,
  );
  final discoverProvider = DiscoverProvider(
    multiServerProvider,
    hiddenLibrariesProvider,
    librariesProvider,
    profileId: null,
    isProfileBinding: () => activeProfileProvider.isBinding,
  );

  addTearDown(() async {
    discoverProvider.dispose();
    activeProfileProvider.dispose();
    companionRemoteProvider.dispose();
    watchTogetherProvider.dispose();
    librariesProvider.dispose();
    hiddenLibrariesProvider.dispose();
    multiServerProvider.dispose();
    await plexHome.dispose();
    await db.close();
  });

  if (prepareHomeBeforeMount) await discoverProvider.ensureLoaded();
  final screen = DiscoverScreen(heroRandom: heroRandom ?? _KeepHeroOrder());
  await tester.pumpWidget(
    TranslationProvider(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<MultiServerProvider>.value(value: multiServerProvider),
          ChangeNotifierProvider<HiddenLibrariesProvider>.value(value: hiddenLibrariesProvider),
          ChangeNotifierProvider<LibrariesProvider>.value(value: librariesProvider),
          ChangeNotifierProvider<WatchTogetherProvider>.value(value: watchTogetherProvider),
          ChangeNotifierProvider<CompanionRemoteProvider>.value(value: companionRemoteProvider),
          ChangeNotifierProvider<ActiveProfileProvider>.value(value: activeProfileProvider),
          ChangeNotifierProvider<DiscoverProvider>.value(value: discoverProvider),
        ],
        child: InputModeTracker(
          child: MaterialApp(
            navigatorObservers: navigatorObservers,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            theme: fixtureFont
                ? monoTheme(dark: dark, oled: oled).copyWith(
                    textTheme: monoTheme(dark: dark, oled: oled).textTheme.apply(fontFamily: 'Go Noto Current'),
                  )
                : monoTheme(dark: dark, oled: oled),
            home: MainScreenFocusScope(
              focusSidebar: () {},
              openNavigation: onOpenNavigation,
              sideNavigationWidth: SideNavigationRailState.expandedWidth,
              reservedSideNavigationWidth: SideNavigationRailState.tvCollapsedWidth,
              foregroundLeft: 0,
              foregroundWidth: 1280,
              viewportWidth: 1280,
              child: wrap?.call(screen) ?? screen,
            ),
          ),
        ),
      ),
    ),
  );

  // Bounded pumps only: the hero runs periodic auto-scroll timers, so
  // pumpAndSettle would never settle.
  if (settle) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _registerR1Tests() {
  for (final kind in [MediaKind.movie, MediaKind.show, MediaKind.season, MediaKind.episode]) {
    testWidgets('R1 phone hero $kind has no action buttons and opens details', (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final item = _r1Item('first', kind: kind);
        final routes = _R1Routes();
        final client = _R1Client([item]);
        await _pumpDiscoverShell(
          tester,
          isTv: false,
          size: const Size(390, 844),
          clients: [client],
          navigatorObservers: [routes],
          prepareHomeBeforeMount: true,
        );
        final hero = find.byType(FusionHomeHero).first;
        expect(hero, findsOneWidget);
        _r1ExpectNoButtons(hero);
        expect(tester.widget<HeroSummary>(find.descendant(of: hero, matching: find.byType(HeroSummary))).maxLines, 2);
        await tester.tapAt(tester.getRect(hero).center);
        _r1ExpectDetailRoute(tester, routes, item.id);
        expect(client.playbackCalls, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    });
  }

  for (final appearance in [
    (name: 'light', dark: false, oled: false),
    (name: 'dark', dark: true, oled: false),
    (name: 'black', dark: true, oled: true),
  ]) {
    for (final width in [900.0, 1280.0, 1920.0]) {
      testWidgets('R1 ${appearance.name} desktop $width hero has original title three-line summary and details route', (
        tester,
      ) async {
        final previousPlatform = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          final item = _r1Item('first');
          final routes = _R1Routes();
          final client = _R1Client([item]);
          final boundary = GlobalKey();
          await _pumpDiscoverShell(
            tester,
            isTv: false,
            dark: appearance.dark,
            oled: appearance.oled,
            size: Size(width, width == 1920 ? 1080 : 720),
            clients: [client],
            navigatorObservers: [routes],
            fixtureFont: true,
            prepareHomeBeforeMount: true,
            wrap: (child) => RepaintBoundary(key: boundary, child: child),
          );
          expect(find.byType(FusionHomeHero), findsNothing);
          final hero = _r1HeroSemantics();
          expect(hero, findsOneWidget);
          _r1ExpectNoButtons(hero);
          final summaryFinder = find.descendant(of: hero, matching: find.byType(HeroSummary));
          final summary = tester.widget<HeroSummary>(summaryFinder);
          expect(summary.maxLines, 3);
          expect(summary.textAlign, TextAlign.left);
          expect(find.descendant(of: hero, matching: find.text('ORIGINAL FIRST')), findsOneWidget);
          final heroRect = tester.getRect(hero);
          final summaryRect = tester.getRect(summaryFinder);
          final originalRect = tester.getRect(find.descendant(of: hero, matching: find.byType(HeroOriginalTitle)));
          expect(originalRect.top, greaterThan(heroRect.top));
          expect(summaryRect.bottom, lessThan(heroRect.bottom - 10));
          final cursor = tester.widget<MouseRegion>(
            find.descendant(of: hero, matching: find.byType(MouseRegion)).first,
          );
          expect(cursor.cursor, SystemMouseCursors.click);
          await _r1Capture(tester, boundary, '${appearance.name}-desktop-${width.toInt()}');
          await tester.tapAt(heroRect.center);
          _r1ExpectDetailRoute(tester, routes, item.id);
          expect(client.playbackCalls, 0);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          debugDefaultTargetPlatformOverride = previousPlatform;
        }
      });
    }

    testWidgets('R1 ${appearance.name} TV spotlight preserves rail focus and confirmation', (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final items = [_r1Item('first'), _r1Item('second')];
        final routes = _R1Routes();
        final boundary = GlobalKey();
        await _pumpDiscoverShell(
          tester,
          isTv: true,
          dark: appearance.dark,
          oled: appearance.oled,
          clients: [_R1Client(items)],
          navigatorObservers: [routes],
          prepareHomeBeforeMount: true,
          fixtureFont: true,
          wrap: (child) => RepaintBoundary(key: boundary, child: child),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(FusionHomeHero), findsNothing);
        expect(find.byType(PageView), findsNothing);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv_browse_rail');
        final spotlight = find.byType(TvSpotlightBackground);
        expect(spotlight, findsOneWidget);
        _r1ExpectNoButtons(spotlight);
        expect(tester.widget<TvSpotlightBackground>(spotlight).item?.id, 'first');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.widget<TvSpotlightBackground>(spotlight).item?.id, 'second');
        await _r1Capture(tester, boundary, '${appearance.name}-tv');
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        _r1ExpectDetailRoute(tester, routes, 'second');
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    });
  }

  testWidgets('R1 desktop keyboard and page indicators keep navigation into details', (tester) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final routes = _R1Routes();
      await _pumpDiscoverShell(
        tester,
        isTv: false,
        clients: [
          _R1Client([_r1Item('first'), _r1Item('second')]),
        ],
        navigatorObservers: [routes],
        prepareHomeBeforeMount: true,
      );
      final secondDot = find.byKey(const ValueKey('home-hero-dot-1'));
      expect(secondDot, findsOneWidget);
      await tester.tap(secondDot);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.widget<Semantics>(secondDot).properties.selected, isTrue);
      expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, closeTo(1, .001));
      final focus = tester.widget<Focus>(
        find.byWidgetPredicate((widget) => widget is Focus && widget.focusNode?.debugLabel == 'hero_section'),
      );
      focus.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.widget<Semantics>(find.byKey(const ValueKey('home-hero-dot-0'))).properties.selected, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.widget<Semantics>(secondDot).properties.selected, isTrue);
      expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, closeTo(1, .001));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      _r1ExpectDetailRoute(tester, routes, 'second');
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}

MediaItem _r1Item(String id, {MediaKind kind = MediaKind.movie}) => testMediaItem(
  id: id,
  kind: kind,
  title: 'Title $id',
  originalTitle: 'Original $id',
  summary:
      'An explorer follows a mysterious signal across distant worlds, discovering new friendships and an unexpected way home. The journey takes them far beyond everything they once knew.',
  year: 2024,
  durationMs: 6360000,
  genres: ['Adventure', 'Drama'],
  contentRating: 'PG-13',
  serverId: 'server_1',
  artPath: 'https://home-visual.fixture/interstellar-backdrop.jpg',
  thumbPath: 'https://home-visual.fixture/interstellar.jpg',
);

Finder _r1HeroSemantics() => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.hint == t.accessibility.tapToOpenDetails,
);

void _r1ExpectNoButtons(Finder parent) {
  expect(
    find.descendant(
      of: parent,
      matching: find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton || widget is IconButton || widget is InkWell,
      ),
    ),
    findsNothing,
  );
}

void _r1ExpectDetailRoute(WidgetTester tester, _R1Routes routes, String id) {
  expect(routes.pushed, hasLength(2));
  final route = routes.pushed.last;
  final context = tester.element(find.byType(DiscoverScreen));
  final Widget page;
  if (route is MaterialPageRoute<dynamic>) {
    page = route.builder(context);
  } else if (route is PageRouteBuilder<dynamic>) {
    page = route.pageBuilder(context, const AlwaysStoppedAnimation(1), const AlwaysStoppedAnimation(0));
  } else {
    fail('Expected a media detail page route, got ${route.runtimeType}');
  }
  expect(page, isA<MediaDetailScreen>());
  expect((page as MediaDetailScreen).metadata.id, id);
}

Future<void> _r1Capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['VELO_R1_SCREENSHOTS'];
  if (directory == null || directory.isEmpty) return;
  final artwork = find.byType(TvSpotlightBackground).evaluate().isNotEmpty
      ? find.byType(TvSpotlightBackground)
      : _r1HeroSemantics();
  final background = find.descendant(of: artwork, matching: find.byType(CyclingMediaBackdrop)).first;
  bool backgroundDecoded() => tester
      .widgetList<RawImage>(find.descendant(of: background, matching: find.byType(RawImage)))
      .any((image) => image.image != null);
  // Cached fixture IO and image decoding need a real event loop. Keep a bounded
  // wait and fail visual capture rather than saving a placeholder as evidence.
  for (var attempt = 0; attempt < 5; attempt++) {
    if (backgroundDecoded()) break;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    if (backgroundDecoded()) break;
    final images = tester.widgetList<Image>(find.descendant(of: background, matching: find.byType(Image))).toList();
    if (images.isNotEmpty) {
      await tester.runAsync(() async {
        await precacheImage(images.first.image, tester.element(background)).timeout(const Duration(seconds: 5));
      });
      await tester.pump();
      if (backgroundDecoded()) break;
    }
  }
  expect(
    backgroundDecoded(),
    isTrue,
    reason: 'Visual evidence requires decoded hero artwork, not the placeholder surface',
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

class _R1Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);
}

class _R1Client extends _FakeMediaServerClient {
  _R1Client(List<MediaItem> items)
    : super(
        hubs: [MediaHub(id: 'r1', title: 'Recommended', type: 'movie', items: items)],
      );

  int playbackCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString().toLowerCase();
    if (name.contains('playback') || name.contains('streamurl')) playbackCalls++;
    return super.noSuchMethod(invocation);
  }
}

class _KeepHeroOrder implements math.Random {
  @override
  int nextInt(int max) => max - 1;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

class _FakeMediaServerClient implements MediaServerClient {
  final List<MediaHub> hubs;
  List<MediaItem> continueWatching;

  _FakeMediaServerClient({required this.hubs, this.continueWatching = const []});

  @override
  ServerId get serverId => ServerId('server_1');

  @override
  String? get serverName => 'Server';

  @override
  MediaBackend get backend => MediaBackend.plex;

  int hubCalls = 0;
  int onDeckCalls = 0;

  @override
  ServerCapabilities get capabilities => ServerCapabilities.plex;

  @override
  String externalImageUrl(String url, {int? width, int? height, bool cover = true}) => url;

  @override
  Future<List<MediaItem>> fetchContinueWatching({int? count = 20, Set<String> excludedLibraryIds = const {}}) async {
    onDeckCalls++;
    return continueWatching;
  }

  @override
  Future<List<MediaLibrary>> fetchLibraries() async => const [];

  @override
  Future<List<MediaHub>> fetchGlobalHubs({
    int limit = defaultHubPreviewLimit,
    bool includePlaybackHubs = true,
    HubFetchDiagnostics? diagnostics,
  }) async {
    hubCalls++;
    return hubs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRegistry extends ProfileRegistry {
  _FakeProfileRegistry(super.db);

  @override
  Stream<List<Profile>> watchProfiles() => Stream.value(const []);

  @override
  Future<List<Profile>> list() async => const [];
}

class _FakeConnectionRegistry extends ConnectionRegistry {
  _FakeConnectionRegistry(super.db);

  @override
  Stream<List<Connection>> watchConnections() => Stream.value(const []);

  @override
  Future<List<Connection>> list() async => const [];
}

class _FakeProfileConnectionRegistry extends ProfileConnectionRegistry {
  _FakeProfileConnectionRegistry(super.db);

  @override
  Stream<List<ProfileConnection>> watchAll() => Stream.value(const []);
}
