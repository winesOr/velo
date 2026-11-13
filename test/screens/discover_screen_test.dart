import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
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
            theme: fixtureFont
                ? monoTheme(dark: dark).copyWith(
                    textTheme: monoTheme(dark: dark).textTheme.apply(fontFamily: 'Go Noto Current'),
                  )
                : monoTheme(dark: dark),
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
