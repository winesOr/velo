import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/providers/discover_provider.dart';
import 'package:plezy/providers/hidden_libraries_provider.dart';
import 'package:plezy/providers/libraries_provider.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/providers/watch_state_store.dart';
import 'package:plezy/services/data_aggregation_service.dart';
import 'package:plezy/services/home_snapshot_store.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/services/plex_api_cache.dart';
import 'package:plezy/services/settings_service.dart';

import '../test_helpers/home_startup_fixtures.dart';
import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late HomeStartupClient client;
  late MultiServerManager manager;
  late MultiServerProvider multiServer;
  late HiddenLibrariesProvider hidden;
  late LibrariesProvider libraries;
  late DiscoverProvider provider;
  late _DeltaAggregationService aggregation;
  late _RecordingHomeSnapshotStore snapshotStore;
  late _RecordingWatchStateStore watchStateStore;
  late bool binding;

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    PlexApiCache.initialize(database);
    client = HomeStartupClient('server')
      ..onDeckGate = Completer<void>()
      ..hubsGate = Completer<void>();
    manager = MultiServerManager()..debugRegisterClientForTesting(client);
    aggregation = _DeltaAggregationService(manager);
    multiServer = MultiServerProvider(manager, aggregation);
    hidden = HiddenLibrariesProvider();
    await hidden.ensureInitialized();
    libraries = LibrariesProvider();
    binding = false;
    snapshotStore = _RecordingHomeSnapshotStore();
    watchStateStore = _RecordingWatchStateStore();
    provider = DiscoverProvider(
      multiServer,
      hidden,
      libraries,
      profileId: 'profile-a',
      isProfileBinding: () => binding,
      homeSnapshotStore: snapshotStore,
      watchStateStore: watchStateStore,
      syncSystemShelf: (_, _) async {},
      syncServerSources: (_, _) async {},
    );
  });
  tearDown(() async {
    provider.dispose();
    watchStateStore.dispose();
    libraries.dispose();
    hidden.dispose();
    multiServer.dispose();
    await database.close();
  });

  Future<void> cacheHome() async {
    final scope = HomeSnapshotScope.capture(
      profileId: 'profile-a',
      clients: {'server': client},
      hiddenLibraryKeys: {},
      useGlobalHubs: SettingsService.instanceOrNull!.read(SettingsService.useGlobalHubs),
    );
    await const HomeSnapshotStore().write(
      scope,
      HomeSnapshot(
        onDeck: [testMediaItem(id: 'cached', title: 'Cached', serverId: 'server')],
        hubs: [
          MediaHub(
            id: 'cached-hub',
            title: 'Cached',
            type: 'movie',
            serverId: 'server',
            items: [testMediaItem(id: 'cached-hub-item', serverId: 'server')],
          ),
        ],
      ),
      authoritativeServerIds: {'server'},
      isCurrent: () => true,
    );
  }

  Future<void> loadBase() async {
    client.onDeck = [testMediaItem(id: 'base', title: 'Base', serverId: 'server')];
    client.hubs = [MediaHub(id: 'base-hub', title: 'Base', type: 'movie', serverId: 'server', items: client.onDeck)];
    client.onDeckGate!.complete();
    client.hubsGate!.complete();
    await provider.ensureLoaded();
    await snapshotStore.lastWrite;
    snapshotStore.acceptedWrites.clear();
    watchStateStore.observed.clear();
  }

  Future<({HomeStartupClient client, Future<void> pending})> startLateDelta({required bool duringMerge}) async {
    final lateClient = HomeStartupClient('late')
      ..onDeck = [testMediaItem(id: 'late-old', title: 'Late', serverId: 'late')]
      ..onDeckGate = Completer<void>()
      ..hubsGate = Completer<void>()
      ..onDeckStarted = Completer<void>()
      ..hubsStarted = Completer<void>();
    lateClient.hubs = [
      MediaHub(id: 'late-hub', title: 'Late', type: 'movie', serverId: 'late', items: lateClient.onDeck),
    ];
    if (duringMerge) {
      aggregation.mergeGate = Completer<void>();
      aggregation.mergeStarted = Completer<void>();
    }
    manager.debugRegisterClientForTesting(lateClient);
    final pending = provider.syncToOnlineServers({'server', 'late'});
    await Future.wait([lateClient.onDeckStarted!.future, lateClient.hubsStarted!.future]);
    if (duringMerge) {
      lateClient.onDeckGate!.complete();
      lateClient.hubsGate!.complete();
      await aggregation.mergeStarted!.future;
    }
    return (client: lateClient, pending: pending);
  }

  test('authorized cached content is published before pending network legs, then refreshed once', () async {
    await cacheHome();
    client.onDeck = [testMediaItem(id: 'fresh', title: 'Fresh', serverId: 'server')];
    final visible = Completer<void>();
    provider.addListener(() {
      if (provider.hasDisplayableContent && !visible.isCompleted) visible.complete();
    });
    final pending = provider.ensureLoaded();
    await visible.future;
    expect(provider.onDeck.single.id, 'cached');
    expect(provider.restoredHomeSnapshot, isTrue);
    final generation = provider.loadGeneration;
    client.onDeckGate!.complete();
    client.hubsGate!.complete();
    await pending;
    expect(provider.onDeck.single.id, 'fresh');
    expect(client.onDeckCalls, 1);
    expect(client.hubCalls, 1);
    expect(provider.loadGeneration, generation, reason: 'refresh must not steal initial focus a second time');
  });

  test('binding does not hydrate cached content or fetch; rotated authorization drops late data', () async {
    await cacheHome();
    binding = true;
    await provider.ensureLoaded();
    expect(provider.hasDisplayableContent, isFalse);
    expect(client.onDeckCalls, 0);
    binding = false;
    client.authenticationSessionId = Object();
    final scope = HomeSnapshotScope.capture(
      profileId: 'profile-a',
      clients: {'server': client},
      hiddenLibraryKeys: {},
      useGlobalHubs: true,
    );
    // Removing volatile cache lets the test observe only the delayed response.
    await PlexApiCache.instance.clearVolatile();
    client.onDeck = [testMediaItem(id: 'stale', serverId: 'server')];
    final started = Completer<void>();
    provider.addListener(() {
      if (provider.isLoading && !started.isCompleted) started.complete();
    });
    final pending = provider.load();
    await started.future;
    // Let preparatory awaits finish without sleeping or completing either leg.
    for (var i = 0; i < 10 && client.onDeckCalls == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(client.onDeckCalls, 1);
    client.authenticationSessionId = Object();
    client.onDeckGate!.complete();
    client.hubsGate!.complete();
    await pending;
    expect(scope.isCurrent({'server': client}), isFalse);
    expect(provider.onDeck, isEmpty);
    expect(provider.hubs, isEmpty);
  });

  for (final duringMerge in [false, true]) {
    for (final invalidation in ['authentication', 'scope', 'visibility', 'binding']) {
      test(
        'late delta drops $invalidation changes during ${duringMerge ? 'merge' : 'network'} and safely retries',
        () async {
          await loadBase();
          final delta = await startLateDelta(duringMerge: duringMerge);
          switch (invalidation) {
            case 'authentication':
              delta.client.authenticationSessionId = Object();
            case 'scope':
              delta.client.profileId = 'profile-b';
            case 'visibility':
              multiServer.setVisibleServerIds({'server'});
            case 'binding':
              binding = true;
          }
          if (duringMerge) {
            aggregation.mergeGate!.complete();
          } else {
            delta.client.onDeckGate!.complete();
            delta.client.hubsGate!.complete();
          }
          await delta.pending;
          expect(provider.onDeck.map((item) => item.id), ['base']);
          expect(provider.hubs.map((hub) => hub.id), ['base-hub']);
          expect(watchStateStore.observed, isEmpty, reason: 'discarded rows cannot acknowledge local watch patches');
          expect(snapshotStore.acceptedWrites, isEmpty, reason: 'old rows cannot be saved under the current scope');

          aggregation.mergeGate = null;
          delta.client.profileId = 'profile-a';
          binding = false;
          delta.client.onDeck = [testMediaItem(id: 'late-fresh', title: 'Fresh', serverId: 'late')];
          delta.client.hubs = [
            MediaHub(id: 'fresh-hub', title: 'Fresh', type: 'movie', serverId: 'late', items: delta.client.onDeck),
          ];
          multiServer.setVisibleServerIds(null);
          await provider.syncToOnlineServers({'server', 'late'});
          await snapshotStore.lastWrite;
          expect(delta.client.onDeckCalls, 2, reason: 'invalid work must not retain a loaded marker');
          expect(provider.onDeck.map((item) => item.id).toSet(), {'base', 'late-fresh'});
          expect(watchStateStore.observed.any((item) => item.id == 'late-old'), isFalse);
        },
      );
    }
  }

  test('an additional authorized server does not cancel or repeat an in-flight late delta', () async {
    await loadBase();
    final delta = await startLateDelta(duringMerge: false);
    final third = HomeStartupClient('third')..onDeck = [testMediaItem(id: 'third', title: 'Third', serverId: 'third')];
    manager.debugRegisterClientForTesting(third);
    final trailing = provider.syncToOnlineServers({'server', 'late', 'third'});
    delta.client.onDeckGate!.complete();
    delta.client.hubsGate!.complete();
    await Future.wait([delta.pending, trailing]);
    await snapshotStore.lastWrite;
    expect(provider.onDeck.map((item) => item.id).toSet(), {'base', 'late-old', 'third'});
    expect(client.onDeckCalls, 1);
    expect(delta.client.onDeckCalls, 1);
    expect(third.onDeckCalls, 1);
  });

  test('delta snapshot keeps request scope when authorization changes while write is pending', () async {
    await loadBase();
    snapshotStore.writeGate = Completer<void>();
    snapshotStore.writeStarted = Completer<void>();
    final delta = await startLateDelta(duringMerge: false);
    delta.client.onDeckGate!.complete();
    delta.client.hubsGate!.complete();
    await snapshotStore.writeStarted!.future;
    await delta.pending;
    delta.client.authenticationSessionId = Object();
    await PlexApiCache.instance.clearVolatile();
    snapshotStore.writeGate!.complete();
    await snapshotStore.lastWrite;
    expect(snapshotStore.acceptedWrites, isEmpty);
    final currentScope = HomeSnapshotScope.capture(
      profileId: 'profile-a',
      clients: {'server': client, 'late': delta.client},
      hiddenLibraryKeys: {},
      useGlobalHubs: SettingsService.instanceOrNull!.read(SettingsService.useGlobalHubs),
    );
    expect(await const HomeSnapshotStore().read(currentScope, isCurrent: () => true), isNull);
  });
}

class _DeltaAggregationService extends DataAggregationService {
  _DeltaAggregationService(super.manager);

  Completer<void>? mergeGate;
  Completer<void>? mergeStarted;

  @override
  Future<List<MediaItem>> mergeContinueWatching(List<MediaItem> existing, List<MediaItem> fresh, {int? limit}) async {
    if (mergeStarted case final started? when !started.isCompleted) started.complete();
    await mergeGate?.future;
    return super.mergeContinueWatching(existing, fresh, limit: limit);
  }
}

class _RecordingHomeSnapshotStore extends HomeSnapshotStore {
  final List<HomeSnapshot> acceptedWrites = [];
  Future<void>? lastWrite;
  Completer<void>? writeGate;
  Completer<void>? writeStarted;

  @override
  Future<void> write(
    HomeSnapshotScope scope,
    HomeSnapshot snapshot, {
    required Set<String> authoritativeServerIds,
    required bool Function() isCurrent,
  }) {
    final pending = _write(scope, snapshot, authoritativeServerIds: authoritativeServerIds, isCurrent: isCurrent);
    lastWrite = pending;
    return pending;
  }

  Future<void> _write(
    HomeSnapshotScope scope,
    HomeSnapshot snapshot, {
    required Set<String> authoritativeServerIds,
    required bool Function() isCurrent,
  }) async {
    if (writeStarted case final started? when !started.isCompleted) started.complete();
    await writeGate?.future;
    if (!isCurrent()) return;
    acceptedWrites.add(snapshot);
    await super.write(scope, snapshot, authoritativeServerIds: authoritativeServerIds, isCurrent: isCurrent);
  }
}

class _RecordingWatchStateStore extends WatchStateStore {
  final List<MediaItem> observed = [];

  @override
  void recordObservations(
    Iterable<({MediaItem item, String? clientScope})> rows, {
    required int watermark,
    required Object epoch,
  }) {
    observed.addAll(rows.map((row) => row.item));
    super.recordObservations(rows, watermark: watermark, epoch: epoch);
  }
}
