import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/media/ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/connection/connection.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/connection/connection_registry.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/focus/focusable_action_bar.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_library.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/media/server_capabilities.dart';
import 'package:plezy/navigation/fusion_navigation.dart';
import 'package:plezy/navigation/home_theme.dart';
import 'package:plezy/navigation/navigation_tabs.dart';
import 'package:plezy/mixins/refreshable.dart';
import 'package:plezy/mixins/tab_visibility_aware.dart';
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
import 'package:plezy/screens/discover_loading_skeleton.dart';
import 'package:plezy/screens/discover_screen.dart';
import 'package:plezy/screens/main_screen.dart';
import 'package:plezy/services/data_aggregation_service.dart';
import 'package:plezy/services/image_cache_service.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/services/storage_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/theme/home_typography.dart';
import 'package:plezy/utils/layout_constants.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/utils/ambient_palette_extractor.dart';
import 'package:plezy/watch_together/watch_together.dart';
import 'package:plezy/widgets/side_navigation_rail.dart';
import 'package:plezy/widgets/backend_badge.dart';
import 'package:plezy/widgets/fusion_home_hero.dart';
import 'package:plezy/widgets/hub_section.dart';
import 'package:plezy/widgets/media_card.dart';
import 'package:plezy/widgets/tv_browse_rail.dart';
import 'package:plezy/widgets/system_clock.dart';
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

  for (final dark in [true, false]) {
    testWidgets('home visual audit with poster artwork ${dark ? 'dark' : 'light'}', (tester) async {
      LocaleSettings.setLocaleSync(AppLocale.zh);
      tester.view.padding = FakeViewPadding(top: 28);
      addTearDown(tester.view.resetPadding);
      final controller = HomeThemeController();
      addTearDown(controller.dispose);
      const host = 'https://home-visual.fixture/';
      final movie = testMediaItem(
        id: 'home-dune',
        title: '沙丘：第二部',
        originalTitle: 'DUNE · PART TWO',
        year: 2024,
        rating: 8.3,
        genres: ['科幻', '冒险'],
        serverId: 'server_1',
        backend: MediaBackend.emby,
        thumbPath: '${host}dune.jpg',
        artPath: '${host}dune.jpg',
        durationMs: 10003000,
        viewOffsetMs: 2238000,
      );
      final episode = testMediaItem(
        id: 'home-episode',
        kind: MediaKind.episode,
        title: '正片 第2期下',
        grandparentTitle: '现在就出发',
        parentIndex: 4,
        index: 7,
        serverId: 'server_1',
        backend: MediaBackend.emby,
        thumbPath: '${host}interstellar-backdrop.jpg',
        durationMs: 4003000,
        viewOffsetMs: 2238000,
      );
      final posters = [
        movie,
        testMediaItem(
          id: 'spirited',
          title: '千与千寻',
          rating: 9.4,
          year: 2001,
          serverId: 'server_1',
          thumbPath: '${host}spirited.jpg',
        ),
        testMediaItem(
          id: 'interstellar',
          title: '星际穿越',
          rating: 9.4,
          year: 2014,
          serverId: 'server_1',
          thumbPath: '${host}interstellar.jpg',
        ),
        testMediaItem(id: 'blade', title: '银翼杀手 2049', year: 2017, serverId: 'server_1', thumbPath: '${host}blade.jpg'),
      ];
      final boundary = GlobalKey();
      await _pumpDiscoverShell(
        tester,
        isTv: false,
        dark: dark,
        size: const Size(390, 844),
        fixtureFont: true,
        clients: [
          _FakeMediaServerClient(
            name: 'Emby',
            protocol: MediaBackend.emby,
            hubs: [MediaHub(id: 'recent', title: '最近添加', type: 'movie', items: posters, more: true)],
            continueWatching: [movie, episode],
          ),
        ],
        wrap: (child) => HomeThemeScope(
          controller: controller,
          child: Builder(
            builder: (context) => RepaintBoundary(
              key: boundary,
              child: Scaffold(
                backgroundColor: HomeThemeScope.colorOf(context),
                extendBody: true,
                body: child,
                bottomNavigationBar: FusionNavigation(
                  tabs: NavigationTab.getVisibleTabs(isOffline: false),
                  selectedTab: NavigationTabId.discover,
                  onSelected: (_) {},
                  onSecondary: () {},
                ),
              ),
            ),
          ),
        ),
      );
      // The screenshot audits Dune's palette; select it explicitly now that
      // banners are sampled from the complete pool after the initial load.
      await tester.pump(const Duration(milliseconds: 200));
      final duneDot = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('home-hero-dot-') &&
            w.properties.label == movie.displayTitle,
      );
      await tester.tap(duneDot);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
        if (controller.color != AmbientPaletteExtractor.defaultFallback &&
            find.byType(RawImage).evaluate().any((e) => (e.widget as RawImage).image != null)) {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(RawImage).evaluate().any((e) => (e.widget as RawImage).image != null), isTrue);
      expect(controller.color, isNot(AmbientPaletteExtractor.defaultFallback));
      expect(find.text('DUNE · PART TWO'), findsOneWidget);
      final allLink = find.text(t.libraries.all).first;
      expect(tester.getRect(allLink).right, greaterThan(350));
      final homeTheme = Theme.of(tester.element(find.byType(FusionHomeHero).first));
      final heroBottom = tester.getRect(find.byType(FusionHomeHero).first).bottom * tester.view.devicePixelRatio;
      expect(
        heroBottom,
        closeTo(heroBottom.roundToDouble(), .000001),
        reason: 'no fractional-pixel seam below the hero',
      );
      expect(homeTheme.extension<HomeTypography>()!.caption.color, Colors.white);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('UPDATE_HOME_SCREENSHOTS')) {
        Future<void> capture(String suffix) async {
          final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              'docs/fixtures/home-audit-${dark ? 'dark' : 'light'}$suffix.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('');
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -450));
        await tester.pump(const Duration(milliseconds: 700));
        expect(
          find.byTooltip(t.common.options).hitTestable(),
          findsNothing,
          reason: 'the phone artwork toolbar scrolls away with its hero',
        );
        await capture('-scrolled');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 1));
    });
  }

  for (final fixture in [
    (name: 'phone-dark', dark: true, size: const Size(390, 844)),
    (name: 'phone-light', dark: false, size: const Size(390, 844)),
    (name: 'phone-narrow', dark: true, size: const Size(320, 844)),
    (name: 'tv', dark: true, size: const Size(1280, 720)),
  ]) {
    testWidgets('home first-load skeleton ${fixture.name} keeps the feed rhythm', (tester) async {
      LocaleSettings.setLocaleSync(AppLocale.zh);
      tester.view.padding = FakeViewPadding(top: fixture.name == 'tv' ? 0 : 28);
      addTearDown(tester.view.resetPadding);
      final boundary = GlobalKey();
      await _pumpDiscoverShell(
        tester,
        isTv: fixture.name == 'tv',
        dark: fixture.dark,
        size: fixture.size,
        clients: [_SplitLoadingFakeClient(continueWatching: const [], gateContinueWatching: true)],
        wrap: (child) => RepaintBoundary(key: boundary, child: child),
        settle: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(DiscoverLoadingSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      if (const bool.fromEnvironment('UPDATE_HOME_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('docs/fixtures/home-loading-${fixture.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a short hero carousel tracks swipes, dot taps and auto advance without trimming Continue Watching', (
    tester,
  ) async {
    final items = List.generate(12, (i) => testMediaItem(id: 'banner-$i', title: 'Banner $i', serverId: 'server_1'));
    await _pumpDiscoverShell(
      tester,
      isTv: false,
      size: const Size(390, 844),
      clients: [_FakeMediaServerClient(hubs: const [], continueWatching: items)],
    );
    await tester.pump(const Duration(milliseconds: 200));
    final pages = tester.widget<PageView>(find.byType(PageView));
    expect(pages.childrenDelegate.estimatedChildCount, 6);
    final provider = tester.element(find.byType(DiscoverScreen)).read<DiscoverProvider>();
    expect(provider.onDeck.length, 12, reason: 'only the banner is shortened');
    Finder dot(int index) => find.byKey(ValueKey('home-hero-dot-$index'));
    bool selected(int index) => tester.widget<Semantics>(dot(index)).properties.selected == true;
    expect(selected(0), isTrue);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(selected(1), isTrue);
    expect(selected(0), isFalse);
    await tester.tap(dot(5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(selected(5), isTrue);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 600));
    expect(selected(0), isTrue, reason: 'automatic wrap updates the same fixed dots');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('recommendation banners and page survive re-entry; only manual refresh rerolls', (tester) async {
    final items = List.generate(
      18,
      (i) => testMediaItem(id: 'recommendation-$i', title: 'Recommendation $i', serverId: 'server_1'),
    );
    final client = _FakeMediaServerClient(
      continueWatching: const [],
      hubs: [MediaHub(id: 'recent', title: 'Recent', items: items, type: 'movie')],
    );
    await _pumpDiscoverShell(tester, isTv: false, size: const Size(390, 844), clients: [client]);
    await tester.pump(const Duration(milliseconds: 200));
    List<String> labels() =>
        List.generate(6, (i) => tester.widget<Semantics>(find.byKey(ValueKey('home-hero-dot-$i'))).properties.label!);
    final first = labels();
    final provider = tester.element(find.byType(DiscoverScreen)).read<DiscoverProvider>();
    expect(provider.onDeck, isEmpty, reason: 'recommendations also supply banners when Continue Watching is empty');
    await provider.refreshContinueWatching();
    await tester.pump(const Duration(milliseconds: 100));
    expect(labels(), first);
    await tester.tap(find.byKey(const ValueKey('home-hero-dot-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final calls = (client.hubCalls, client.onDeckCalls);
    final state = tester.state(find.byType(DiscoverScreen)) as TabVisibilityAware;
    state.onTabHidden();
    state.onTabShown();
    await tester.pump(const Duration(milliseconds: 100));
    final second = labels();
    expect(second, first);
    expect(tester.widget<Semantics>(find.byKey(const ValueKey('home-hero-dot-1'))).properties.selected, isTrue);
    (tester.state(find.byType(DiscoverScreen)) as Refreshable).refresh();
    await tester.pump(const Duration(milliseconds: 100));
    expect(labels(), first);
    expect((client.hubCalls, client.onDeckCalls), calls, reason: 'returning or reselecting Home performs no requests');
    (tester.state(find.byType(DiscoverScreen)) as ManualRefreshable).manualRefresh();
    await tester.pump(const Duration(milliseconds: 100));
    expect(labels().toSet().intersection(second.toSet()), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final navigated in [false, true]) {
    testWidgets(
      'cold-start recommendations ${navigated ? 'preserve an active swipe' : 'supply the final random pool'}',
      (tester) async {
        final resume = List.generate(
          8,
          (i) => testMediaItem(id: 'resume-$i', title: 'Resume $i', serverId: 'server_1'),
        );
        final recommendations = List.generate(
          12,
          (i) => testMediaItem(id: 'fresh-$i', title: 'Fresh $i', serverId: 'server_1'),
        );
        final client = _SplitLoadingFakeClient(continueWatching: resume);
        await _pumpDiscoverShell(tester, isTv: false, size: const Size(390, 844), clients: [client], settle: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        List<String> labels() => List.generate(
          6,
          (i) => tester.widget<Semantics>(find.byKey(ValueKey('home-hero-dot-$i'))).properties.label!,
        );
        final initial = labels();
        if (navigated) {
          await tester.drag(find.byType(PageView), const Offset(-300, 0));
          await tester.pump(const Duration(milliseconds: 600));
        }
        client._hubGate.complete([MediaHub(id: 'recent', title: 'Recent', items: recommendations, type: 'movie')]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        if (navigated) {
          expect(labels(), initial);
          expect(tester.widget<Semantics>(find.byKey(const ValueKey('home-hero-dot-1'))).properties.selected, isTrue);
        } else {
          expect(labels().toSet().intersection(initial.toSet()), isEmpty);
          expect(labels().any((label) => label.startsWith('Fresh')), isTrue);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final tv in [false, true]) {
    testWidgets('prepared ${tv ? 'TV' : 'phone'} home mounts without another fetch or full loading screen', (
      tester,
    ) async {
      final item = testMediaItem(id: 'prepared', title: 'Ready home', serverId: 'server_1');
      final client = _FakeMediaServerClient(
        continueWatching: [item],
        hubs: [
          MediaHub(id: 'ready', title: 'Ready', items: [item], type: 'movie'),
        ],
      );
      await _pumpDiscoverShell(tester, isTv: tv, clients: [client], prepareHomeBeforeMount: true);
      await tester.pump();
      await tester.pump();
      expect(find.byType(DiscoverLoadingSkeleton), findsNothing);
      expect(client.hubCalls, 1);
      expect(client.onDeckCalls, 1);
      final state = tester.state(find.byType(DiscoverScreen)) as FullRefreshable;
      state.primeRefresh();
      await tester.pump();
      expect(client.hubCalls, 1);
      expect(client.onDeckCalls, 1);
      expect(FocusManager.instance.primaryFocus?.debugLabel, tv ? 'tv_browse_rail' : 'hero_section');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('home source selector uses actual protocol logos and filters the loaded hero', (tester) async {
    final settings = await SettingsService.getInstance();
    await settings.write(SettingsService.showHeroSection, true);
    final plex = _FakeMediaServerClient(
      hubs: const [],
      continueWatching: [testMediaItem(title: 'Plex fixture', serverId: 'server_1')],
    );
    final emby = _FakeMediaServerClient(
      id: 'emby-server',
      name: 'Emby living room',
      protocol: MediaBackend.emby,
      hubs: const [],
      continueWatching: [testMediaItem(title: 'Emby fixture', serverId: 'emby-server', backend: MediaBackend.emby)],
    );
    await _pumpDiscoverShell(tester, isTv: false, clients: [plex, emby], size: const Size(390, 844));
    await tester.tap(find.byTooltip(t.libraries.allSources));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Emby living room'), findsOneWidget);
    expect(
      tester.widgetList<BackendBadge>(find.byType(BackendBadge)).any((b) => b.backend == MediaBackend.emby),
      isTrue,
    );
    await tester.tap(find.text('Emby living room'));
    await tester.pump(const Duration(milliseconds: 300));
    final heroes = tester.widgetList<FusionHomeHero>(find.byType(FusionHomeHero));
    expect(heroes, isNotEmpty);
    expect(heroes.every((hero) => hero.item.serverId == 'emby-server'), isTrue);
    expect(find.text('Emby living room'), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_back_ios_rounded), findsNothing);
    expect(find.byIcon(Symbols.arrow_forward_ios_rounded), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('on-deck hero replaces the first-load skeleton before hubs finish', (tester) async {
    final item = testMediaItem(
      id: 'early-hero',
      backend: MediaBackend.plex,
      kind: MediaKind.movie,
      title: 'Early hero',
      serverId: 'server_1',
      serverName: 'Server',
    );
    final client = _SplitLoadingFakeClient(continueWatching: [item]);
    await _pumpDiscoverShell(tester, isTv: false, size: const Size(390, 844), clients: [client], settle: false);

    // The first provider pass sets both legs loading, but the on-deck future
    // resolves immediately while the hub future is still gated.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DiscoverLoadingSkeleton), findsNothing);
    expect(find.byType(FusionHomeHero), findsOneWidget);
    expect(find.byType(HubSection), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -600));
    await tester.pump();

    expect(find.byType(DiscoverHubLoadingSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('TV keeps Continue Watching visible while recommendation hubs finish', (tester) async {
    final item = testMediaItem(
      id: 'early-tv-hero',
      backend: MediaBackend.plex,
      kind: MediaKind.movie,
      title: 'Early TV hero',
      serverId: 'server_1',
      serverName: 'Server',
    );
    final client = _SplitLoadingFakeClient(continueWatching: [item]);
    await _pumpDiscoverShell(tester, isTv: true, size: const Size(1280, 720), clients: [client], settle: false);

    // The first provider pass sets both legs loading, but the on-deck future
    // resolves immediately while the hub future is still gated.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(DiscoverLoadingSkeleton), findsNothing);
    expect(find.byType(TvBrowseRail), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('TV tab focus returns to discover browse rail instead of reload action', (tester) async {
    final settings = await SettingsService.getInstance();
    await settings.write(SettingsService.libraryDensity, LibraryDensity.max);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final item = testMediaItem(
      id: 'movie_1',
      backend: MediaBackend.plex,
      kind: MediaKind.movie,
      title: 'Movie 1',
      serverId: 'server_1',
      serverName: 'Server',
    );
    final hub = MediaHub(id: 'hub_1', title: 'Recommended', type: 'movie', items: [item], size: 1);
    final client = _FakeMediaServerClient(hubs: [hub]);
    final manager = MultiServerManager()..debugRegisterClientForTesting(client);
    final multiServerProvider = testMultiServerProvider(manager);
    final hiddenLibrariesProvider = HiddenLibrariesProvider();
    final librariesProvider = LibrariesProvider();
    final watchTogetherProvider = WatchTogetherProvider();
    final companionRemoteProvider = CompanionRemoteProvider();

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final profileRegistry = _FakeProfileRegistry(db);
    final connectionRegistry = _FakeConnectionRegistry(db);
    final profileConnectionRegistry = _FakeProfileConnectionRegistry(db);
    final storage = await StorageService.getInstance();
    final plexHome = PlexHomeService(
      connections: connectionRegistry,
      profileConnections: profileConnectionRegistry,
      storage: storage,
      plexHomeUserFetcher: (_) async => const [],
    );
    final activeProfileProvider = ActiveProfileProvider(
      registry: profileRegistry,
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
    final discoverKey = GlobalKey<State<DiscoverScreen>>();
    const targetSidebarOffset = SideNavigationRailState.expandedWidth;
    const currentForegroundLeft = 120.0;
    const foregroundWidth = 1280 - SideNavigationRailState.tvCollapsedWidth;

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
          child: MaterialApp(
            theme: monoTheme(dark: true),
            home: MainScreenFocusScope(
              focusSidebar: () {},
              sideNavigationWidth: targetSidebarOffset,
              reservedSideNavigationWidth: SideNavigationRailState.tvCollapsedWidth,
              foregroundLeft: currentForegroundLeft,
              foregroundWidth: foregroundWidth,
              viewportWidth: 1280,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: foregroundWidth,
                  height: 720,
                  child: DiscoverScreen(key: discoverKey),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(TvBrowseRail), findsOneWidget);

    final scale = TvLayoutConstants.scaleForSize(const Size(1280, 720));
    final spotlightLeft = (24 * scale).clamp(18.0, 40.0).toDouble();
    final spotlightBackground = tester.widget<TvSpotlightBackground>(find.byType(TvSpotlightBackground));
    expect(spotlightBackground.contentLeft, closeTo(spotlightLeft + currentForegroundLeft, 0.001));

    final railHeight = TvBrowseRailLayout.estimateHeight(
      size: const Size(foregroundWidth, 720),
      hubs: [hub],
      density: LibraryDensity.max,
      episodePosterMode: settings.read(SettingsService.episodePosterMode),
      fullCardLayout: settings.read(SettingsService.tvFullCardLayout),
      tallPosterScale: TvBrowseRailLayout.compactTallPosterScale,
    );
    final minimumSpotlightBottom = railHeight + (8 * scale);
    final baseSpotlightBottom = (720 * 0.48).clamp(160.0, 820.0).toDouble();
    final desiredSpotlightBottom = minimumSpotlightBottom > baseSpotlightBottom
        ? minimumSpotlightBottom
        : baseSpotlightBottom;
    final maxSpotlightBottom = (720 - ((720 * 0.075).clamp(64.0 * scale, 120.0 * scale)) - (96 * scale))
        .clamp(0.0, double.infinity)
        .toDouble();
    final expectedSpotlightBottom = desiredSpotlightBottom > maxSpotlightBottom
        ? maxSpotlightBottom
        : desiredSpotlightBottom;
    expect(spotlightBackground.contentBottom, closeTo(expectedSpotlightBottom, 0.001));

    // The rail no longer receives the bleed via constructor (a per-flip param
    // would rebuild the whole rail); its bleed layer reads the scope's
    // sideNavigationWidth itself. Assert the rendered bleed position instead.
    final browseRail = tester.widget<TvBrowseRail>(find.byType(TvBrowseRail));
    expect(browseRail.backgroundBleedLeft, isNull);
    final railBleedPositions = tester
        .widgetList<Positioned>(find.descendant(of: find.byType(TvBrowseRail), matching: find.byType(Positioned)))
        .where((p) => p.left == -targetSidebarOffset);
    expect(railBleedPositions, isNotEmpty, reason: 'rail bleed layer positions at -sideNavigationWidth');

    final backgroundPosition = tester.widget<Positioned>(
      find.ancestor(of: find.byType(TvSpotlightBackground), matching: find.byType(Positioned)).first,
    );
    expect(backgroundPosition.left, -currentForegroundLeft);
    expect(backgroundPosition.width, 1280);

    tester.state<FocusableActionBarState>(find.byType(FocusableActionBar)).requestFocusOnFirst();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'ActionBar[0]');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv_browse_rail');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    tester.state<FocusableActionBarState>(find.byType(FocusableActionBar)).requestFocusOnFirst();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'ActionBar[0]');

    (discoverKey.currentState! as FocusableTab).focusActiveTabIfReady();
    (discoverKey.currentState! as TabVisibilityAware).onTabHidden();
    await tester.pump();
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'ActionBar[0]');

    (discoverKey.currentState! as TabVisibilityAware).onTabShown();
    (discoverKey.currentState! as FocusableTab).focusActiveTabIfReady();
    await tester.pump();
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv_browse_rail');
  });
  testWidgets('startup prime does not duplicate the load DiscoverScreen started in initState', (tester) async {
    // DiscoverScreen.initState fires load(); main_screen._primeOnlineServices
    // then primes the content tabs once libraries land. Asking for a full
    // refresh there queued a trailing pass through CoalescedLoadCoordinator and
    // ran the whole home fan-out twice on every cold start (#1784).
    await SettingsService.getInstance();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final hub = MediaHub(id: 'hub_1', title: 'Recommended', type: 'movie', items: const [], size: 0);
    final client = _GatedHubsFakeClient(hubs: [hub]);
    // Disposes both the provider and the manager it wraps; MultiServerProvider
    // does not own the manager, and manager.dispose() is what closes its
    // status/progress controllers and the registered clients.
    final multiServerProvider = testMultiServer(clients: [client]).provider;
    final hiddenLibrariesProvider = HiddenLibrariesProvider();
    final librariesProvider = LibrariesProvider();
    final watchTogetherProvider = WatchTogetherProvider();
    final companionRemoteProvider = CompanionRemoteProvider();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final connectionRegistry = _FakeConnectionRegistry(db);
    final profileConnectionRegistry = _FakeProfileConnectionRegistry(db);
    final storage = await StorageService.getInstance();
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
      isProfileBinding: () => false,
    );
    addTearDown(() async {
      discoverProvider.dispose();
      activeProfileProvider.dispose();
      companionRemoteProvider.dispose();
      watchTogetherProvider.dispose();
      librariesProvider.dispose();
      hiddenLibrariesProvider.dispose();
      // multiServerProvider + its manager are torn down by testMultiServer.
      await plexHome.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      TranslationProvider(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<MultiServerProvider>.value(value: multiServerProvider),
            ChangeNotifierProvider<HiddenLibrariesProvider>.value(value: hiddenLibrariesProvider),
            ChangeNotifierProvider<LibrariesProvider>.value(value: librariesProvider),
            ChangeNotifierProvider<DiscoverProvider>.value(value: discoverProvider),
            ChangeNotifierProvider<WatchTogetherProvider>.value(value: watchTogetherProvider),
            ChangeNotifierProvider<CompanionRemoteProvider>.value(value: companionRemoteProvider),
            ChangeNotifierProvider<ActiveProfileProvider>.value(value: activeProfileProvider),
          ],
          child: MaterialApp(
            theme: monoTheme(dark: true),
            home: MainScreenFocusScope(
              focusSidebar: () {},
              sideNavigationWidth: SideNavigationRailState.expandedWidth,
              reservedSideNavigationWidth: SideNavigationRailState.tvCollapsedWidth,
              foregroundLeft: 0,
              foregroundWidth: 1280,
              viewportWidth: 1280,
              child: const SizedBox(width: 1280, height: 720, child: DiscoverScreen()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The initState pass is in flight, waiting on the server.
    expect(discoverProvider.isLoadInFlight, isTrue);
    expect(client.hubCalls, 1);

    final screen = tester.state(find.byType(DiscoverScreen)) as FullRefreshable;
    screen.primeRefresh();

    client.release();
    // Bounded pumps, not pumpAndSettle: the hero carousel runs a repeating
    // auto-scroll timer, so the frame loop never goes quiet.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(client.hubCalls, 1, reason: 'the prime rode along with the load already running');
    expect(discoverProvider.isLoadInFlight, isFalse);

    // A completed initial result must also survive the online-entry prime.
    screen.primeRefresh();
    await tester.pump();
    client.release();
    await tester.pump();
    await tester.pump();

    expect(client.hubCalls, 1);
    screen.fullRefresh();
    await tester.pump();
    client.release();
    await tester.pump();
    await tester.pump();
    expect(client.hubCalls, 2, reason: 'an explicit refresh still fetches fresh data');
  });

  testWidgets('Refreshable.refresh refetches hubs only once they are stale (#1646)', (tester) async {
    // The stale-resume gate goes through Refreshable.refresh(). A fresh
    // refresh must stay Continue Watching-only (zero hub calls), but once the
    // hub list is older than DiscoverProvider.staleAfter it must run a full
    // pass — otherwise media added server-side never appears until a restart.
    await SettingsService.getInstance();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    var currentTime = DateTime(2026, 1, 1, 12);
    final hub = MediaHub(id: 'hub_1', title: 'Recommended', type: 'movie', items: const [], size: 0);
    final client = _GatedHubsFakeClient(hubs: [hub]);
    final multiServerProvider = testMultiServer(clients: [client]).provider;
    final hiddenLibrariesProvider = HiddenLibrariesProvider();
    final librariesProvider = LibrariesProvider();
    final watchTogetherProvider = WatchTogetherProvider();
    final companionRemoteProvider = CompanionRemoteProvider();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final connectionRegistry = _FakeConnectionRegistry(db);
    final profileConnectionRegistry = _FakeProfileConnectionRegistry(db);
    final storage = await StorageService.getInstance();
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
      isProfileBinding: () => false,
      now: () => currentTime,
    );
    addTearDown(() async {
      discoverProvider.dispose();
      activeProfileProvider.dispose();
      companionRemoteProvider.dispose();
      watchTogetherProvider.dispose();
      librariesProvider.dispose();
      hiddenLibrariesProvider.dispose();
      // multiServerProvider + its manager are torn down by testMultiServer.
      await plexHome.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      TranslationProvider(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<MultiServerProvider>.value(value: multiServerProvider),
            ChangeNotifierProvider<HiddenLibrariesProvider>.value(value: hiddenLibrariesProvider),
            ChangeNotifierProvider<LibrariesProvider>.value(value: librariesProvider),
            ChangeNotifierProvider<DiscoverProvider>.value(value: discoverProvider),
            ChangeNotifierProvider<WatchTogetherProvider>.value(value: watchTogetherProvider),
            ChangeNotifierProvider<CompanionRemoteProvider>.value(value: companionRemoteProvider),
            ChangeNotifierProvider<ActiveProfileProvider>.value(value: activeProfileProvider),
          ],
          child: MaterialApp(
            theme: monoTheme(dark: true),
            home: MainScreenFocusScope(
              focusSidebar: () {},
              sideNavigationWidth: SideNavigationRailState.expandedWidth,
              reservedSideNavigationWidth: SideNavigationRailState.tvCollapsedWidth,
              foregroundLeft: 0,
              foregroundWidth: 1280,
              viewportWidth: 1280,
              child: const SizedBox(width: 1280, height: 720, child: DiscoverScreen()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Let the initState load pass commit, stamping hub freshness at T0.
    client.release();
    await tester.pump();
    await tester.pump();
    expect(client.hubCalls, 1);
    expect(discoverProvider.isLoadInFlight, isFalse);

    final screen = tester.state(find.byType(DiscoverScreen)) as Refreshable;

    // Fresh: normal navigation keeps all cached rows.
    screen.refresh();
    await tester.pump();
    await tester.pump();
    expect(client.hubCalls, 1, reason: 'a fresh refresh must not refetch hubs');

    // Stale: the same refresh entry point now runs the full pass.
    currentTime = currentTime.add(DiscoverProvider.staleAfter + const Duration(seconds: 1));
    screen.refresh();
    await tester.pump();
    client.release();
    await tester.pump();
    await tester.pump();
    expect(client.hubCalls, 2, reason: 'a stale refresh must refetch the home hubs');
  });

  testWidgets('TV selects Continue Watching when it arrives after recommendation hubs', (tester) async {
    await SettingsService.getInstance();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final recommendedItem = testMediaItem(
      id: 'recommended',
      backend: MediaBackend.plex,
      kind: MediaKind.movie,
      title: 'Recommended',
      serverId: 'server_1',
      serverName: 'Server',
    );
    final continueItem = testMediaItem(
      id: 'continue',
      backend: MediaBackend.plex,
      kind: MediaKind.movie,
      title: 'Continue Watching',
      serverId: 'server_1',
      serverName: 'Server',
    );
    final recommendedHub = MediaHub(
      id: 'recommended_hub',
      title: 'Recommended',
      type: 'movie',
      items: [recommendedItem],
      size: 1,
    );
    final client = _FakeMediaServerClient(hubs: [recommendedHub]);
    final manager = MultiServerManager()..debugRegisterClientForTesting(client);
    final multiServerProvider = MultiServerProvider(manager, DataAggregationService(manager));
    final hiddenLibrariesProvider = HiddenLibrariesProvider();
    final librariesProvider = LibrariesProvider();
    final watchTogetherProvider = WatchTogetherProvider();
    final companionRemoteProvider = CompanionRemoteProvider();

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final profileRegistry = _FakeProfileRegistry(db);
    final connectionRegistry = _FakeConnectionRegistry(db);
    final profileConnectionRegistry = _FakeProfileConnectionRegistry(db);
    final storage = await StorageService.getInstance();
    final plexHome = PlexHomeService(
      connections: connectionRegistry,
      profileConnections: profileConnectionRegistry,
      storage: storage,
      plexHomeUserFetcher: (_) async => const [],
    );
    final activeProfileProvider = ActiveProfileProvider(
      registry: profileRegistry,
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
    const foregroundWidth = 1280 - SideNavigationRailState.tvCollapsedWidth;

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
          child: MaterialApp(
            theme: monoTheme(dark: true),
            home: MainScreenFocusScope(
              focusSidebar: () {},
              sideNavigationWidth: SideNavigationRailState.expandedWidth,
              reservedSideNavigationWidth: SideNavigationRailState.tvCollapsedWidth,
              foregroundLeft: 0,
              foregroundWidth: foregroundWidth,
              viewportWidth: 1280,
              child: const SizedBox(width: foregroundWidth, height: 720, child: DiscoverScreen()),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv_browse_rail');
    expect(tester.widget<TvSpotlightBackground>(find.byType(TvSpotlightBackground)).item?.id, recommendedItem.id);

    client.continueWatching = [continueItem];
    await discoverProvider.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv_browse_rail');
    expect(tester.widget<TvSpotlightBackground>(find.byType(TvSpotlightBackground)).item?.id, continueItem.id);
  });

  testWidgets('non-TV hero keeps indicators visible in keyboard mode and fades to solid bg', (tester) async {
    TvDetectionService.debugSetAppleTVOverride(false);
    await SettingsService.getInstance();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final onDeck = [
      for (var i = 0; i < 3; i++)
        testMediaItem(
          id: 'movie_$i',
          backend: MediaBackend.plex,
          kind: MediaKind.movie,
          title: 'Movie $i',
          serverId: 'server_1',
          serverName: 'Server',
        ),
    ];
    final client = _FakeMediaServerClient(hubs: const [], continueWatching: onDeck);
    final manager = MultiServerManager()..debugRegisterClientForTesting(client);
    final multiServerProvider = testMultiServerProvider(manager);
    final hiddenLibrariesProvider = HiddenLibrariesProvider();
    final librariesProvider = LibrariesProvider();
    final watchTogetherProvider = WatchTogetherProvider();
    final companionRemoteProvider = CompanionRemoteProvider();

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final profileRegistry = _FakeProfileRegistry(db);
    final connectionRegistry = _FakeConnectionRegistry(db);
    final profileConnectionRegistry = _FakeProfileConnectionRegistry(db);
    final storage = await StorageService.getInstance();
    final plexHome = PlexHomeService(
      connections: connectionRegistry,
      profileConnections: profileConnectionRegistry,
      storage: storage,
      plexHomeUserFetcher: (_) async => const [],
    );
    final activeProfileProvider = ActiveProfileProvider(
      registry: profileRegistry,
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
              theme: monoTheme(dark: true).copyWith(platform: TargetPlatform.macOS),
              home: MainScreenFocusScope(
                focusSidebar: () {},
                sideNavigationWidth: SideNavigationRailState.expandedWidth,
                reservedSideNavigationWidth: SideNavigationRailState.tvCollapsedWidth,
                foregroundLeft: 0,
                foregroundWidth: 1280,
                viewportWidth: 1280,
                child: const DiscoverScreen(),
              ),
            ),
          ),
        ),
      ),
    );

    // Bounded pumps only: the hero runs periodic auto-scroll/indicator timers,
    // so pumpAndSettle would never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PageView), findsOneWidget);
    final indicators = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.customSemanticsActions?.keys.any((a) => a.label == t.accessibility.autoScrollPause) == true,
    );
    expect(indicators, findsOneWidget, reason: 'hero indicators render in pointer mode');
    expect(find.byIcon(Symbols.pause_rounded), findsNothing, reason: 'the prototype has no visible pause toggle');

    // Entering keyboard mode must not hide the indicators on non-TV devices
    // (regression: back-key/BT-keyboard events left them permanently hidden).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(indicators, findsOneWidget, reason: 'hero indicators stay visible in keyboard mode on non-TV');

    // The shared ambient fade must end in solid background at the hero edge.
    final scaffoldBg = monoTheme(dark: true).scaffoldBackgroundColor;
    final heroFades = tester
        .widgetList<DecoratedBox>(
          find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).gradient is LinearGradient,
          ),
        )
        .map((c) => (c.decoration as BoxDecoration).gradient! as LinearGradient)
        .where((g) => g.begin == Alignment.topCenter && g.end == Alignment.bottomCenter && g.colors.length == 5)
        .toList();
    expect(heroFades, isNotEmpty, reason: 'hero bottom fade overlay renders');
    for (final fade in heroFades) {
      expect(fade.stops, const [0.0, 0.45, 0.72, 0.90, 1.0]);
      expect(fade.colors.last, scaffoldBg);
    }

    // Dispose the screen so the hero's periodic timers are cancelled before
    // the binding's pending-timer check.
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(820, 1180), const Size(1180, 820), const Size(600, 960)]) {
    testWidgets('tablet home uses the fusion artwork and readable shelves at $size', (tester) async {
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
                onSecondary: () {},
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
      expect(find.byTooltip(t.common.options), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureTablet(tester, find.byKey(boundary), 'home-${size.width.toInt()}');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('the home clock is TV-only chrome', (tester) async {
    await _pumpDiscoverShell(tester, isTv: false);
    expect(find.byTooltip(t.common.options), findsOneWidget);
    expect(
      find.byType(SystemClock),
      findsNothing,
      reason: 'a phone status bar and a desktop menu bar already show the time',
    );
    await tester.pumpWidget(const SizedBox());

    await _pumpDiscoverShell(tester, isTv: true);
    expect(find.byType(SystemClock), findsOneWidget, reason: 'a fullscreen leanback app hides the system clock');
    await tester.pumpWidget(const SizedBox());
  });

  for (final tv in [false, true]) {
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
        expect(find.text('8.6'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('home keeps white text while retaining the outer light appearance', (tester) async {
    final item = testMediaItem(
      id: 'light-home',
      title: 'Light home movie',
      serverId: 'server_1',
      durationMs: 4003000,
      viewOffsetMs: 2238000,
    );
    await _pumpDiscoverShell(
      tester,
      isTv: false,
      dark: false,
      size: const Size(390, 844),
      clients: [
        _FakeMediaServerClient(hubs: const [], continueWatching: [item]),
      ],
    );
    final toolbarContext = tester.element(find.byTooltip(t.common.options));
    expect(Theme.of(toolbarContext).brightness, Brightness.light);
    expect(Theme.of(toolbarContext).colorScheme.onSurface, Colors.white);
    final heroContext = tester.element(find.byType(FusionHomeHero).first);
    expect(Theme.of(heroContext).brightness, Brightness.light);
    expect(Theme.of(heroContext).extension<HomeTypography>(), isNotNull);
    expect(find.text('37:18 / 1:06:43'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final cardContext = tester.element(find.byType(HubSection));
    expect(Theme.of(cardContext).brightness, Brightness.light);
    expect(Theme.of(cardContext).extension<HomeTypography>()!.cardTitle.fontWeight, FontWeight.w500);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a pending TV rail focus is dropped once the user has moved to the sidebar', (tester) async {
    // The first load arms "focus the rail when it has hubs"; an empty-items
    // hub keeps it armed because the rail has nothing to render yet. Items
    // landing on a later pass must not pull focus off a sidebar item the
    // user has since navigated to.
    final gated = await _pumpGatedDiscover(tester);
    gated.sidebarItem.requestFocus();
    await tester.pump();

    await gated.landItems(tester);

    expect(find.byType(TvBrowseRail), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus,
      same(gated.sidebarItem),
      reason: 'items landing must not steal the sidebar',
    );
  });

  testWidgets('a pending TV rail focus still claims the rail while focus sits on a bare scope', (tester) async {
    // Startup shape: MainScreen has focused its content scope but nothing
    // below it yet. That is "nowhere", not a destination the user chose, so
    // the rail keeps its initial-focus claim when hubs finally arrive.
    final gated = await _pumpGatedDiscover(tester);
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());

    await gated.landItems(tester);

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv_browse_rail');
  });

  testWidgets('an explicit tab handoff claims the rail while focus still sits on the sidebar', (tester) async {
    // Sidebar → Home: MainScreen calls focusActiveTabIfReady() without moving
    // focus off the sidebar item that selected the tab. Focus resting there
    // is the handoff in flight, not the user navigating away.
    final gated = await _pumpGatedDiscover(tester);
    await gated.landItems(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv_browse_rail');

    gated.sidebarItem.requestFocus();
    await tester.pump();
    (tester.state(find.byType(DiscoverScreen)) as FocusableTab).focusActiveTabIfReady();
    await tester.pump();
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv_browse_rail');
  });

  testWidgets('a handoff made while hubs are still loading claims the rail when they land', (tester) async {
    // Same handoff on a slow server: the rail has nothing to focus yet, so the
    // claim stays armed with focus on the sidebar item. Items landing later
    // must honor it — focus has not moved since the user selected Home.
    final gated = await _pumpGatedDiscover(tester);
    gated.sidebarItem.requestFocus();
    await tester.pump();
    (tester.state(find.byType(DiscoverScreen)) as FocusableTab).focusActiveTabIfReady();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(gated.sidebarItem));

    await gated.landItems(tester);

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv_browse_rail');
  });

  testWidgets('a handoff claim lapses once the user moves to another sidebar item', (tester) async {
    final gated = await _pumpGatedDiscover(tester);
    gated.sidebarItem.requestFocus();
    await tester.pump();
    (tester.state(find.byType(DiscoverScreen)) as FocusableTab).focusActiveTabIfReady();
    await tester.pump();

    gated.otherSidebarItem.requestFocus();
    await tester.pump();

    await gated.landItems(tester);

    expect(find.byType(TvBrowseRail), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus,
      same(gated.otherSidebarItem),
      reason: 'the user navigated on; do not yank focus',
    );
  });
}

class _GatedDiscover {
  _GatedDiscover({required this.client, required this.sidebarItem, required this.otherSidebarItem});

  final _GatedHubsFakeClient client;
  final FocusNode sidebarItem;
  final FocusNode otherSidebarItem;

  /// Replace the empty-items hub with a populated one and run a full pass.
  Future<void> landItems(WidgetTester tester) async {
    client.hubs
      ..clear()
      ..add(
        MediaHub(
          id: 'hub_1',
          title: 'Recommended',
          type: 'movie',
          items: [testMediaItem(id: 'movie_1', backend: MediaBackend.plex, kind: MediaKind.movie, title: 'Movie 1')],
          size: 1,
        ),
      );
    (tester.state(find.byType(DiscoverScreen)) as FullRefreshable).fullRefresh();
    await tester.pump();
    client.release();
    await tester.pump();
    await tester.pump();
  }
}

/// Mounts a TV [DiscoverScreen] beside a sidebar stand-in and completes its
/// first load with a hub that has no items, so the rail has nothing to render
/// and the screen's "focus the rail when ready" request stays armed.
Future<_GatedDiscover> _pumpGatedDiscover(WidgetTester tester) async {
  await SettingsService.getInstance();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1280, 720);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  final client = _GatedHubsFakeClient(
    hubs: [MediaHub(id: 'hub_1', title: 'Recommended', type: 'movie', items: const [], size: 0)],
  );
  final multiServerProvider = testMultiServer(clients: [client]).provider;
  final hiddenLibrariesProvider = HiddenLibrariesProvider();
  final librariesProvider = LibrariesProvider();
  final watchTogetherProvider = WatchTogetherProvider();
  final companionRemoteProvider = CompanionRemoteProvider();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final connectionRegistry = _FakeConnectionRegistry(db);
  final profileConnectionRegistry = _FakeProfileConnectionRegistry(db);
  final storage = await StorageService.getInstance();
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
    isProfileBinding: () => false,
  );
  final sidebarItem = FocusNode(debugLabel: 'sidebar_item');
  final otherSidebarItem = FocusNode(debugLabel: 'other_sidebar_item');
  addTearDown(() async {
    sidebarItem.dispose();
    otherSidebarItem.dispose();
    discoverProvider.dispose();
    activeProfileProvider.dispose();
    companionRemoteProvider.dispose();
    watchTogetherProvider.dispose();
    librariesProvider.dispose();
    hiddenLibrariesProvider.dispose();
    // multiServerProvider + its manager are torn down by testMultiServer.
    await plexHome.dispose();
    await db.close();
  });

  await tester.pumpWidget(
    TranslationProvider(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<MultiServerProvider>.value(value: multiServerProvider),
          ChangeNotifierProvider<HiddenLibrariesProvider>.value(value: hiddenLibrariesProvider),
          ChangeNotifierProvider<LibrariesProvider>.value(value: librariesProvider),
          ChangeNotifierProvider<DiscoverProvider>.value(value: discoverProvider),
          ChangeNotifierProvider<WatchTogetherProvider>.value(value: watchTogetherProvider),
          ChangeNotifierProvider<CompanionRemoteProvider>.value(value: companionRemoteProvider),
          ChangeNotifierProvider<ActiveProfileProvider>.value(value: activeProfileProvider),
        ],
        child: InputModeTracker(
          child: MaterialApp(
            theme: monoTheme(dark: true),
            home: Row(
              children: [
                Column(
                  children: [
                    Focus(focusNode: sidebarItem, child: const SizedBox(width: 80, height: 360)),
                    Focus(focusNode: otherSidebarItem, child: const SizedBox(width: 80, height: 360)),
                  ],
                ),
                MainScreenFocusScope(
                  focusSidebar: () {},
                  sideNavigationWidth: SideNavigationRailState.expandedWidth,
                  reservedSideNavigationWidth: SideNavigationRailState.tvCollapsedWidth,
                  foregroundLeft: 80,
                  foregroundWidth: 1200,
                  viewportWidth: 1280,
                  child: const SizedBox(width: 1200, height: 720, child: DiscoverScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  client.release();
  await tester.pump();
  await tester.pump();
  expect(find.byType(TvBrowseRail), findsNothing, reason: 'an empty-items hub gives the rail nothing to show');
  return _GatedDiscover(client: client, sidebarItem: sidebarItem, otherSidebarItem: otherSidebarItem);
}

/// Mounts [DiscoverScreen] in the smallest graph both layout branches need, so
/// one test can compare the TV and non-TV chrome without rebuilding it twice.
Future<void> _pumpDiscoverShell(
  WidgetTester tester, {
  required bool isTv,
  bool dark = true,
  List<MediaServerClient>? clients,
  Size size = const Size(1280, 720),
  Widget Function(Widget)? wrap,
  bool fixtureFont = false,
  bool settle = true,
  math.Random? heroRandom,
  bool prepareHomeBeforeMount = false,
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
            theme: fixtureFont
                ? monoTheme(dark: dark).copyWith(
                    textTheme: monoTheme(dark: dark).textTheme.apply(fontFamily: 'Go Noto Current'),
                  )
                : monoTheme(dark: dark),
            home: MainScreenFocusScope(
              focusSidebar: () {},
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
  final String id;
  final String name;
  final MediaBackend protocol;

  _FakeMediaServerClient({
    required this.hubs,
    this.continueWatching = const [],
    this.id = 'server_1',
    this.name = 'Server',
    this.protocol = MediaBackend.plex,
  });

  @override
  ServerId get serverId => ServerId(id);

  @override
  String? get serverName => name;

  @override
  MediaBackend get backend => protocol;

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

/// Publishes Continue Watching immediately while holding the hub leg open.
class _SplitLoadingFakeClient implements MediaServerClient {
  _SplitLoadingFakeClient({required this.continueWatching, this.gateContinueWatching = false});

  final List<MediaItem> continueWatching;
  final bool gateContinueWatching;
  final Completer<List<MediaItem>> _continueWatchingGate = Completer<List<MediaItem>>();
  final Completer<List<MediaHub>> _hubGate = Completer<List<MediaHub>>();

  @override
  ServerId get serverId => ServerId('server_1');

  @override
  String? get serverName => 'Server';

  @override
  MediaBackend get backend => MediaBackend.plex;

  @override
  ServerCapabilities get capabilities => ServerCapabilities.plex;

  @override
  Future<List<MediaItem>> fetchContinueWatching({int? count = 20, Set<String> excludedLibraryIds = const {}}) async =>
      gateContinueWatching ? _continueWatchingGate.future : continueWatching;

  @override
  Future<List<MediaLibrary>> fetchLibraries() async => const [];

  @override
  Future<List<MediaHub>> fetchGlobalHubs({
    int limit = defaultHubPreviewLimit,
    bool includePlaybackHubs = true,
    HubFetchDiagnostics? diagnostics,
  }) => _hubGate.future;

  @override
  void close() {
    if (!_hubGate.isCompleted) _hubGate.complete(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Hub client that holds each fetch open until [release], so a test can act
/// while a Discover load pass is genuinely in flight.
class _GatedHubsFakeClient implements MediaServerClient {
  _GatedHubsFakeClient({required this.hubs});

  final List<MediaHub> hubs;
  int hubCalls = 0;
  final _gates = <Completer<List<MediaHub>>>[];

  void release() {
    for (final gate in _gates.where((g) => !g.isCompleted)) {
      gate.complete(hubs);
    }
  }

  @override
  ServerId get serverId => ServerId('server_1');

  @override
  String? get serverName => 'Server';

  @override
  MediaBackend get backend => MediaBackend.plex;

  @override
  ServerCapabilities get capabilities => ServerCapabilities.plex;

  @override
  Future<List<MediaItem>> fetchContinueWatching({int? count = 20, Set<String> excludedLibraryIds = const {}}) async =>
      const [];

  @override
  Future<List<MediaLibrary>> fetchLibraries() async => const [];

  @override
  Future<List<MediaHub>> fetchGlobalHubs({
    int limit = defaultHubPreviewLimit,
    bool includePlaybackHubs = true,
    HubFetchDiagnostics? diagnostics,
  }) {
    hubCalls++;
    final gate = Completer<List<MediaHub>>();
    _gates.add(gate);
    return gate.future;
  }

  /// Reached by `MultiServerManager.dispose()` via `_closeClientGracefully`.
  /// Releases any gate still open so teardown cannot leave a fetch hanging.
  @override
  void close() => release();

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
