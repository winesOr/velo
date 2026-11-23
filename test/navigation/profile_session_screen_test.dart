import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/connection/connection_registry.dart';
import 'package:plezy/connection/connection.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/models/plex/plex_home_user.dart';
import 'package:plezy/navigation/fusion_navigation.dart';
import 'package:plezy/navigation/profile_navigation_scope.dart';
import 'package:plezy/navigation/profile_session_screen.dart';
import 'package:plezy/profiles/active_profile_provider.dart';
import 'package:plezy/profiles/active_profile_binder.dart';
import 'package:plezy/profiles/plex_home_service.dart';
import 'package:plezy/profiles/profile.dart';
import 'package:plezy/profiles/profile_connection_registry.dart';
import 'package:plezy/profiles/profile_registry.dart';
import 'package:plezy/profiles/profile_connection.dart';
import 'package:plezy/providers/account_preferences_controller.dart';
import 'package:plezy/providers/companion_remote_provider.dart';
import 'package:plezy/providers/discover_provider.dart';
import 'package:plezy/providers/hidden_libraries_provider.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/providers/trackers_provider.dart';
import 'package:plezy/providers/offline_mode_provider.dart';
import 'package:plezy/screens/main_screen.dart';
import 'package:plezy/screens/discover_screen.dart';
import 'package:plezy/services/home_snapshot_store.dart';
import 'package:plezy/services/credential_vault.dart';
import 'package:plezy/services/plex_api_cache.dart';
import 'package:plezy/services/plex_auth_service.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/home_startup_gate.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/services/offline_watch_sync_service.dart';
import 'package:plezy/services/storage_service.dart';
import 'package:plezy/services/system_shelf_service.dart';
import 'package:provider/provider.dart';

import '../test_helpers/io_fakes.dart';
import '../test_helpers/multi_server_fixtures.dart';
import '../test_helpers/prefs.dart';
import '../test_helpers/home_startup_fixtures.dart';
import '../test_helpers/media_items.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    resetSharedPreferencesForTest();
    CredentialVault.resetKeyForTesting();
    SystemShelfService().debugReset();
  });

  for (final startupOffline in [false, true]) {
    testWidgets(
      'a real ${startupOffline ? 'explicit offline' : 'normal'} startup keeps cached Home visible before connection',
      (tester) async {
        SettingsService.resetForTesting();
        final settings = await SettingsService.getInstance();
        await settings.write(SettingsService.autoCheckUpdatesOnStartup, false);
        await settings.write(SettingsService.requireProfileSelectionOnOpen, false);
        PlatformDetector.debugSetIsDesktopOSOverride(false);
        addTearDown(() => PlatformDetector.debugSetIsDesktopOSOverride(null));
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final graph = await _SessionGraph.create();
        PlexApiCache.initialize(graph.db);
        final owner = Profile.local(id: 'local-owner', displayName: 'Owner', createdAt: DateTime(2026));
        await graph.profileRegistry.upsert(owner);
        await graph.connectionRegistry.upsert(
          PlexAccountConnection(
            id: 'saved-connection',
            accountToken: 'test-owner-token',
            clientIdentifier: 'device',
            accountLabel: 'Owner',
            createdAt: DateTime(2026),
            servers: [
              PlexServer(
                name: 'Saved server',
                clientIdentifier: 'server',
                accessToken: 'test-token',
                connections: [
                  PlexConnection(
                    protocol: 'https',
                    address: 'saved.invalid',
                    port: 443,
                    uri: 'https://saved.invalid',
                    local: false,
                    relay: false,
                    ipv6: false,
                  ),
                ],
                owned: true,
              ),
            ],
          ),
        );
        await graph.profileConnectionRegistry.upsert(
          ProfileConnection(profileId: owner.id, connectionId: 'saved-connection', userIdentifier: 'owner'),
        );
        await graph.storage.setActiveProfileId(owner.id);
        await graph.activeProfile.initialize();
        graph.activeProfile.markBindingStarted();
        graph.activeProfile.markStartupIdentityReady(profileId: owner.id);
        graph.multiServer.setVisibleServerIds({'server'});
        graph.multiServer.setExpectedVisibleServerIds({'server'});
        final offline = OfflineModeProvider(graph.serverManager, multiServerProvider: graph.multiServer);
        final preferences = _ReadyAccountPreferences();
        final binder = _NoopStartupBinder();
        final client = HomeStartupClient('server', profileId: owner.id);
        final scope = HomeSnapshotScope.capture(
          profileId: owner.id,
          clients: {'server': client},
          hiddenLibraryKeys: {},
          useGlobalHubs: settings.read(SettingsService.useGlobalHubs),
        );
        await const HomeSnapshotStore().write(
          scope,
          HomeSnapshot(
            onDeck: const [],
            hubs: [
              MediaHub(
                id: 'saved-home',
                title: 'Saved shelf',
                type: 'movie',
                serverId: 'server',
                items: [testMediaItem(id: 'cached-title', title: 'Cached title', serverId: 'server')],
              ),
            ],
          ),
          authoritativeServerIds: {'server'},
          isCurrent: () => true,
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 16));
          offline.dispose();
          preferences.dispose();
          await graph.dispose();
        });
        await graph.pump(
          tester,
          httpClientFactory: () => FakeHttpClient(200, const []),
          wrap: (child) => MultiProvider(
            providers: [
              ChangeNotifierProvider<OfflineModeProvider>.value(value: offline),
              ChangeNotifierProvider<AccountPreferencesController>.value(value: preferences),
              Provider<ActiveProfileBinder>.value(value: binder),
            ],
            child: child,
          ),
          isOfflineMode: startupOffline,
          profileShellBuilder: null,
        );
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 40));
        }
        expect(offline.isOffline, isTrue);
        expect(graph.multiServer.onlineServerIds, isEmpty, reason: 'cached content does not fabricate a connection');
        final discover = tester.element(find.byType(MainScreen)).read<DiscoverProvider>();
        expect(discover.restoredHomeSnapshot, isTrue);
        expect(find.byType(DiscoverScreen).hitTestable(), findsOneWidget);
        expect(find.text('Cached title').hitTestable(), findsWidgets);
        expect(find.text(t.common.reconnect).hitTestable(), findsNothing);
        expect(find.byType(FusionNavigation).hitTestable(), startupOffline ? findsNothing : findsOneWidget);
        expect(find.byType(NavigationBar).hitTestable(), startupOffline ? findsOneWidget : findsNothing);
        final cachedRows = (await graph.db.select(graph.db.apiCache).get()).length;
        expect(cachedRows, greaterThan(0));
        await PlexApiCache.instance.put(ServerId(client.scopedServerId), '/runtime-api-response', {
          'token': 'old-runtime-token',
        });
        graph.activeProfile.markBindingFinished(success: false);
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 40));
        }
        expect(find.byType(DiscoverScreen).hitTestable(), findsOneWidget);
        expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);
        expect(
          (await graph.db.select(graph.db.apiCache).get()).length,
          cachedRows,
          reason: 'the initial binding is not an account mutation and must not erase the disk snapshot',
        );
        expect(
          await PlexApiCache.instance.get(ServerId(client.scopedServerId), '/runtime-api-response'),
          isNull,
          reason: 'retaining display snapshots must still clean runtime API responses',
        );
        expect(binder.starts, 1, reason: 'background binding starts automatically without a connect tap');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the real startup gate never exposes a cached Home before identity authorization', (tester) async {
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    PlatformDetector.debugSetIsDesktopOSOverride(false);
    addTearDown(() => PlatformDetector.debugSetIsDesktopOSOverride(null));
    final graph = await _SessionGraph.create();
    PlexApiCache.initialize(graph.db);
    final owner = Profile.local(
      id: 'locked-owner',
      displayName: 'Locked',
      pinHash: 'verified-by-authorizer',
      createdAt: DateTime(2026),
    );
    await graph.profileRegistry.upsert(owner);
    await graph.storage.setActiveProfileId(owner.id);
    await graph.activeProfile.initialize();
    graph.activeProfile.markBindingStarted();
    final client = HomeStartupClient('server', profileId: owner.id);
    await const HomeSnapshotStore().write(
      HomeSnapshotScope.capture(
        profileId: owner.id,
        clients: {'server': client},
        hiddenLibraryKeys: {},
        useGlobalHubs: true,
      ),
      HomeSnapshot(
        onDeck: [testMediaItem(id: 'private', title: 'Private cached title', serverId: 'server')],
        hubs: const [],
      ),
      authoritativeServerIds: {'server'},
      isCurrent: () => true,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await graph.dispose();
    });
    await graph.pump(tester, httpClientFactory: () => FakeHttpClient(200, const []), profileShellBuilder: null);
    await tester.pump(const Duration(seconds: 4));
    expect(graph.activeProfile.isStartupIdentityReady, isFalse);
    expect(find.byType(MainScreen), findsNothing);
    expect(find.text('Private cached title'), findsNothing);
    expect(tester.element(find.byType(HomeStartupGate)).read<DiscoverProvider>().restoredHomeSnapshot, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile switch disposes the profile navigator, routes, and providers', (tester) async {
    final graph = await _SessionGraph.create();
    final discoverProviders = <DiscoverProvider>[];
    final hiddenProviders = <HiddenLibrariesProvider>[];
    final trackerProviders = <TrackersProvider>[];
    final companionProviders = <CompanionRemoteProvider>[];
    final disposedActiveIds = <String>[];
    final trackerHttpClients = <FakeHttpClient>[];
    // TrackersProvider owns six eager auth HTTP clients across the five
    // services (MAL's proxy and token exchange use separate clients).
    const trackerAuthClientsPerProfile = 6;
    FakeHttpClient trackerHttpClientFactory() {
      final client = FakeHttpClient(200, const <int>[]);
      trackerHttpClients.add(client);
      return client;
    }

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await graph.dispose();
    });

    final owner = Profile.local(id: 'local-owner', displayName: 'Owner', createdAt: DateTime(2026, 1, 1));
    final kids = Profile.local(id: 'local-kids', displayName: 'Kids', createdAt: DateTime(2026, 1, 2));
    await graph.profileRegistry.upsert(owner);
    await graph.profileRegistry.upsert(kids);
    await graph.storage.saveHiddenLibrariesForProfile(owner.id, {'srv:owner'});
    await graph.storage.saveHiddenLibrariesForProfile(kids.id, {'srv:kids'});
    await graph.storage.setActiveProfileId(owner.id);
    await graph.activeProfile.initialize();

    await graph.pump(
      tester,
      httpClientFactory: trackerHttpClientFactory,
      profileShellBuilder: (context) => _ProfileProbeShell(
        discoverProviders: discoverProviders,
        hiddenProviders: hiddenProviders,
        trackerProviders: trackerProviders,
        companionProviders: companionProviders,
        disposedActiveIds: disposedActiveIds,
      ),
    );
    await tester.pumpAndSettle();
    expect(trackerHttpClients, hasLength(trackerAuthClientsPerProfile));
    final ownerHttpClients = List<FakeHttpClient>.of(trackerHttpClients);
    _expectCloseCount(ownerHttpClients, 0);

    expect(find.text('active:local-owner'), findsOneWidget);
    expect(SystemShelfService().debugActiveOwner, owner.id);
    expect(discoverProviders.single.profileId, owner.id);
    expect(discoverProviders, hasLength(1));
    expect(hiddenProviders, hasLength(1));
    expect(companionProviders, hasLength(1));
    final ownerNavigator = profileNavigationRegistry.navigator;
    final ownerDiscover = discoverProviders.single;
    final ownerHidden = hiddenProviders.single;
    final ownerTrackers = trackerProviders.single;
    final ownerCompanion = companionProviders.single;
    await ownerHidden.ensureInitialized();
    expect(ownerHidden.profileId, owner.id);
    expect(ownerHidden.hiddenLibraryKeys, {'srv:owner'});

    await tester.tap(find.byKey(const ValueKey('push-profile-route')));
    await tester.pumpAndSettle();
    expect(find.text('old profile route'), findsOneWidget);

    expect(await graph.activeProfile.activate(kids), isTrue);
    await tester.pumpAndSettle();
    expect(trackerHttpClients, hasLength(trackerAuthClientsPerProfile * 2));
    final kidsHttpClients = trackerHttpClients.sublist(ownerHttpClients.length);
    _expectCloseCount(ownerHttpClients, 1);
    _expectCloseCount(kidsHttpClients, 0);

    expect(find.text('old profile route'), findsNothing);
    expect(find.text('active:local-kids'), findsOneWidget);
    expect(disposedActiveIds, contains('local-owner'));
    expect(discoverProviders, hasLength(2));
    expect(discoverProviders.last, isNot(same(ownerDiscover)));
    expect(hiddenProviders, hasLength(2));
    expect(hiddenProviders.last, isNot(same(ownerHidden)));
    expect(trackerProviders, hasLength(2));
    expect(trackerProviders.last, isNot(same(ownerTrackers)));
    expect(ownerTrackers.isDisposed, isTrue);
    expect(companionProviders, hasLength(2));
    expect(companionProviders.last, isNot(same(ownerCompanion)));
    expect(ownerCompanion.isDisposed, isTrue);
    await hiddenProviders.last.ensureInitialized();
    expect(hiddenProviders.last.profileId, kids.id);
    expect(hiddenProviders.last.hiddenLibraryKeys, {'srv:kids'});
    expect(profileNavigationRegistry.navigator, isNot(same(ownerNavigator)));
    expect(SystemShelfService().debugActiveOwner, kids.id);
    expect(discoverProviders.last.profileId, kids.id);

    await graph.activeProfile.clearActiveProfile();
    await tester.pumpAndSettle();
    expect(trackerHttpClients, hasLength(trackerAuthClientsPerProfile * 3));
    final signedOutHttpClients = trackerHttpClients.sublist(ownerHttpClients.length + kidsHttpClients.length);
    _expectCloseCount(ownerHttpClients, 1);
    _expectCloseCount(kidsHttpClients, 1);
    _expectCloseCount(signedOutHttpClients, 0);
    expect(SystemShelfService().debugActiveOwner, isNull);
    expect(discoverProviders.last.profileId, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(trackerHttpClients.toSet(), hasLength(trackerAuthClientsPerProfile * 3));
    _expectCloseCount(trackerHttpClients, 1);
  });

  testWidgets(
    'a root-navigator route over the session blocks focus steals below it and hands focus back on pop (#2239)',
    (tester) async {
      final graph = await _SessionGraph.create();
      final rootNavigator = GlobalKey<NavigatorState>();
      final content = FocusNode(debugLabel: 'SessionContent');
      final sidebar = FocusNode(debugLabel: 'SessionSidebar');
      final picker = FocusNode(debugLabel: 'RootPicker');

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        content.dispose();
        sidebar.dispose();
        picker.dispose();
        await graph.dispose();
      });

      final owner = Profile.local(id: 'local-owner', displayName: 'Owner', createdAt: DateTime(2026, 1, 1));
      await graph.profileRegistry.upsert(owner);
      await graph.storage.setActiveProfileId(owner.id);
      await graph.activeProfile.initialize();

      await graph.pump(
        tester,
        navigatorKey: rootNavigator,
        httpClientFactory: () => FakeHttpClient(200, const <int>[]),
        profileShellBuilder: (context) => Column(
          children: [
            Focus(focusNode: sidebar, child: const SizedBox(height: 10, width: 10)),
            Focus(focusNode: content, autofocus: true, child: const SizedBox(height: 10, width: 10)),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(content.hasPrimaryFocus, isTrue);

      // The picker/PIN shape: pushed on the root navigator, above the whole
      // nested profile-session navigator.
      rootNavigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Focus(focusNode: picker, autofocus: true, child: const SizedBox.expand()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(picker.hasPrimaryFocus, isTrue);

      // A resume-time self-heal under MainScreen (sidebar reveal, grid load).
      sidebar.requestFocus();
      await tester.pump();
      expect(sidebar.hasPrimaryFocus, isFalse, reason: 'covered session must not take focus');
      expect(picker.hasPrimaryFocus, isTrue);

      rootNavigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(content.hasPrimaryFocus, isTrue, reason: 'focus returns to the session leaf that had it');
    },
  );
}

void _expectCloseCount(Iterable<FakeHttpClient> clients, int expected) {
  for (final client in clients) {
    expect(client.closeCount, expected);
  }
}

class _SessionGraph {
  _SessionGraph._({
    required this.db,
    required this.profileRegistry,
    required this.connectionRegistry,
    required this.profileConnectionRegistry,
    required this.storage,
    required this.plexHome,
    required this.activeProfile,
    required this.serverManager,
    required this.multiServer,
    required this.offlineWatch,
  });

  final AppDatabase db;
  final ProfileRegistry profileRegistry;
  final ConnectionRegistry connectionRegistry;
  final ProfileConnectionRegistry profileConnectionRegistry;
  final StorageService storage;
  final _FakePlexHomeService plexHome;
  final ActiveProfileProvider activeProfile;
  final MultiServerManager serverManager;
  final MultiServerProvider multiServer;
  final OfflineWatchSyncService offlineWatch;

  static Future<_SessionGraph> create() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    PlexApiCache.initialize(db);
    final profileRegistry = ProfileRegistry(db);
    final connectionRegistry = ConnectionRegistry(db);
    final profileConnectionRegistry = ProfileConnectionRegistry(db);
    final storage = await StorageService.getInstance();
    final plexHome = _FakePlexHomeService(
      connections: connectionRegistry,
      profileConnections: profileConnectionRegistry,
      storage: storage,
    );
    final serverManager = MultiServerManager();
    return _SessionGraph._(
      db: db,
      profileRegistry: profileRegistry,
      connectionRegistry: connectionRegistry,
      profileConnectionRegistry: profileConnectionRegistry,
      storage: storage,
      plexHome: plexHome,
      activeProfile: ActiveProfileProvider(
        registry: profileRegistry,
        plexHome: plexHome,
        connections: connectionRegistry,
        profileConnections: profileConnectionRegistry,
        storage: storage,
      ),
      serverManager: serverManager,
      multiServer: testMultiServerProvider(serverManager),
      // The session tree instantiates MusicPlaybackServiceImpl (the mini-player
      // overlay watches it), which needs the database + offline watch service.
      offlineWatch: OfflineWatchSyncService(database: db, serverManager: serverManager),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required FakeHttpClient Function() httpClientFactory,
    required WidgetBuilder? profileShellBuilder,
    GlobalKey<NavigatorState>? navigatorKey,
    Widget Function(Widget)? wrap,
    bool isOfflineMode = false,
  }) => tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<AppDatabase>.value(value: db),
        Provider<ConnectionRegistry>.value(value: connectionRegistry),
        Provider<ProfileConnectionRegistry>.value(value: profileConnectionRegistry),
        Provider<PlexHomeService>.value(value: plexHome),
        ChangeNotifierProvider<ActiveProfileProvider>.value(value: activeProfile),
        ChangeNotifierProvider<MultiServerProvider>.value(value: multiServer),
        ChangeNotifierProvider<OfflineWatchSyncService>.value(value: offlineWatch),
      ],
      child: InputModeTracker(
        child: MaterialApp(
          theme: monoTheme(dark: true).copyWith(platform: TargetPlatform.android),
          navigatorKey: navigatorKey,
          home: (wrap ?? (child) => child)(
            ProfileSessionScreen.forTesting(
              initialPromptHandled: true,
              isOfflineMode: isOfflineMode,
              httpClientFactory: httpClientFactory,
              profileShellBuilder: profileShellBuilder,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> dispose() async {
    await activeProfile.resetForTesting();
    activeProfile.dispose();
    multiServer.dispose();
    serverManager.dispose();
    await plexHome.dispose();
    offlineWatch.dispose();
    await db.close();
  }
}

class _ReadyAccountPreferences extends ChangeNotifier implements AccountPreferencesController {
  @override
  Future<void> ensureActiveLoaded() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopStartupBinder implements ActiveProfileBinder {
  int starts = 0;
  @override
  void start({bool allowInitialPinPrompt = true}) => starts++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileProbeShell extends StatefulWidget {
  const _ProfileProbeShell({
    required this.discoverProviders,
    required this.companionProviders,
    required this.hiddenProviders,
    required this.disposedActiveIds,
    required this.trackerProviders,
  });

  final List<CompanionRemoteProvider> companionProviders;
  final List<DiscoverProvider> discoverProviders;
  final List<HiddenLibrariesProvider> hiddenProviders;
  final List<TrackersProvider> trackerProviders;
  final List<String> disposedActiveIds;

  @override
  State<_ProfileProbeShell> createState() => _ProfileProbeShellState();
}

class _ProfileProbeShellState extends State<_ProfileProbeShell> {
  CompanionRemoteProvider? _companionProvider;
  DiscoverProvider? _discoverProvider;
  HiddenLibrariesProvider? _hiddenProvider;
  TrackersProvider? _trackersProvider;
  String _activeId = 'none';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _companionProvider = context.read<CompanionRemoteProvider>();
    _discoverProvider = context.read<DiscoverProvider>();
    _hiddenProvider = context.read<HiddenLibrariesProvider>();
    _trackersProvider = context.read<TrackersProvider>();
    _activeId = context.read<ActiveProfileProvider>().activeId ?? 'none';
    if (widget.discoverProviders.isEmpty || !identical(widget.discoverProviders.last, _discoverProvider)) {
      widget.discoverProviders.add(_discoverProvider!);
    }
    if (widget.hiddenProviders.isEmpty || !identical(widget.hiddenProviders.last, _hiddenProvider)) {
      widget.hiddenProviders.add(_hiddenProvider!);
    }
    if (widget.trackerProviders.isEmpty || !identical(widget.trackerProviders.last, _trackersProvider)) {
      widget.trackerProviders.add(_trackersProvider!);
    }
    if (widget.companionProviders.isEmpty || !identical(widget.companionProviders.last, _companionProvider)) {
      widget.companionProviders.add(_companionProvider!);
    }
  }

  @override
  void dispose() {
    widget.disposedActiveIds.add(_activeId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeId = context.watch<ActiveProfileProvider>().activeId;
    return Scaffold(
      body: Column(
        children: [
          Text('active:$activeId'),
          ElevatedButton(
            key: const ValueKey('push-profile-route'),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Text('old profile route')));
            },
            child: const Text('push profile route'),
          ),
        ],
      ),
    );
  }
}

class _FakePlexHomeService extends PlexHomeService {
  _FakePlexHomeService({required super.connections, required super.profileConnections, required StorageService storage})
    : super(storage: storage, plexHomeUserFetcher: (_) async => const []);

  @override
  Map<String, List<PlexHomeUser>> get current => const {};

  @override
  Stream<Map<String, List<PlexHomeUser>>> get stream => Stream.value(const {});

  @override
  Future<void> start() async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  Future<void> dispose() async {}
}
