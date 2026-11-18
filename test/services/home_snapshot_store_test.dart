import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/connection/connection.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/services/api_cache.dart';
import 'package:plezy/services/home_snapshot_store.dart';
import 'package:plezy/services/plex_api_cache.dart';
import 'package:plezy/services/jellyfin_mappers.dart';
import 'package:plezy/profiles/profile.dart';
import 'package:plezy/profiles/profile_connection.dart';
import 'package:plezy/media/media_backend.dart';

import '../test_helpers/home_startup_fixtures.dart';
import '../test_helpers/media_items.dart';

void main() {
  late AppDatabase database;
  late HomeStartupClient client;
  late Map<String, MediaServerClient> clients;
  const store = HomeSnapshotStore();

  HomeSnapshotScope capture({String profile = 'profile-a', Set<String> hidden = const {}, bool global = true}) =>
      HomeSnapshotScope.capture(profileId: profile, clients: clients, hiddenLibraryKeys: hidden, useGlobalHubs: global);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    PlexApiCache.initialize(database);
    client = HomeStartupClient('server');
    clients = {'server': client};
  });
  tearDown(() => database.close());

  Future<void> save(HomeSnapshotScope scope) => store.write(
    scope,
    HomeSnapshot(
      onDeck: [testMediaItem(id: 'resume', serverId: 'server', viewOffsetMs: 1234)],
      hubs: [
        MediaHub(
          id: 'new',
          title: 'New',
          type: 'movie',
          serverId: 'server',
          items: [
            testMediaItem(
              id: 'new',
              serverId: 'server',
              raw: {'AccessToken': 'must-not-persist'},
              thumbPath: 'https://example.test/art?X-Plex-Token=must-not-persist',
            ),
          ],
        ),
      ],
    ),
    authoritativeServerIds: {'server'},
    isCurrent: () => scope.isCurrent(clients),
  );

  test('authorized snapshots restore display rows without credentials or opaque backend data', () async {
    final scope = capture();
    await save(scope);
    final restored = await store.read(scope, isCurrent: () => scope.isCurrent(clients));
    expect(restored!.onDeck.single.viewOffsetMs, 1234);
    expect(restored.hubs.single.items.single.raw, isNull);
    expect(restored.hubs.single.items.single.thumbPath, isNull);
    final rows = await database.select(database.apiCache).get();
    expect(rows.single.data, isNot(contains('must-not-persist')));
  });

  test('profile, scope, hidden libraries and layout stay isolated while server arrivals reuse existing rows', () async {
    final scope = capture();
    await save(scope);
    for (final other in [
      capture(profile: 'profile-b'),
      capture(hidden: {'server:hidden'}),
      capture(global: false),
    ]) {
      expect(await store.read(other, isCurrent: () => true), isNull);
    }
    clients['second'] = HomeStartupClient('second');
    expect(scope.isCurrent(clients), isFalse);
    expect(
      scope.isCurrent(clients, requireSameServers: false),
      isTrue,
      reason: 'new connections do not invalidate already-authorized network legs',
    );
    expect((await store.read(capture(), isCurrent: () => true))!.onDeck.single.id, 'resume');
    clients.remove('second');
    client.profileId = 'profile-b';
    expect(scope.isCurrent(clients), isFalse);
    expect(await store.read(capture(profile: 'profile-b'), isCurrent: () => true), isNull);
  });

  test('authentication rotation, revocation and logout invalidate in-flight reads and writes', () async {
    final scope = capture();
    await save(scope);
    client.authenticationSessionId = Object();
    expect(scope.isCurrent(clients), isFalse);
    expect(await store.read(scope, isCurrent: () => scope.isCurrent(clients)), isNull);
    await ApiCache.clearRegisteredVolatile();
    await save(scope);
    expect(await database.select(database.apiCache).get(), isEmpty);
    clients.clear();
    expect(scope.isCurrent(clients), isFalse);
  });

  test('write guard is checked after asynchronous encoding so logout cannot be undone', () async {
    final cache = PlexApiCache.instance;
    var authorized = true;
    final pending = cache.put(ServerId(client.scopedServerId), 'guarded', {
      'rows': List.filled(1000, 'metadata'),
    }, isCurrent: () => authorized);
    authorized = false;
    await ApiCache.clearRegisteredVolatile();
    await pending;
    expect(await cache.get(ServerId(client.scopedServerId), 'guarded'), isNull);
  });

  test('explicit retention limits apply while the default keeps the last successful page for refresh', () async {
    final scope = capture();
    await save(scope);
    await database
        .update(database.apiCache)
        .write(ApiCacheCompanion(cachedAt: Value(DateTime.now().subtract(const Duration(days: 30)))));
    expect((await store.read(scope, isCurrent: () => true))!.onDeck.single.id, 'resume');
    expect(await const HomeSnapshotStore(maxAge: Duration.zero).read(scope, isCurrent: () => true), isNull);
  });

  test('authorized local owners restore without a client or connection probe and reject revoked reads', () async {
    await save(capture());
    final scope = HomeSnapshotScope.forOwners(
      profileId: 'profile-a',
      owners: [
        HomeSnapshotOwner(
          serverId: 'server',
          backend: MediaBackend.plex,
          scope: client.scopedServerId,
          serverName: 'Offline server',
        ),
      ],
      hiddenLibraryKeys: {},
      useGlobalHubs: true,
    );
    clients.clear();
    final restored = await store.read(scope, isCurrent: () => true);
    expect(restored!.onDeck.single.id, 'resume');
    expect(restored.hubs.single.serverName, 'Offline server');
    expect(await store.read(scope, isCurrent: () => false), isNull);
  });

  test('local owner projection includes only the bound MediaBrowser user', () {
    final profile = Profile.local(id: 'profile-a', displayName: 'A', createdAt: DateTime(2026));
    final connection = JellyfinConnection(
      id: 'connection',
      baseUrl: 'https://server.invalid',
      serverName: 'Saved server',
      serverMachineId: 'machine',
      userId: 'user-a',
      userName: 'A',
      accessToken: 'not-persisted-in-owner',
      deviceId: 'device',
      createdAt: DateTime(2026),
    );
    List<HomeSnapshotOwner> owners(String boundUser, {Set<String> excluded = const {}}) =>
        HomeSnapshotOwner.fromBindings(
          profile: profile,
          connections: {'connection': connection},
          bindings: [ProfileConnection(profileId: profile.id, connectionId: 'connection', userIdentifier: boundUser)],
          excludedServerIds: excluded,
        );
    expect(owners('user-a').single.scope, 'machine/user-a');
    expect(owners('user-b'), isEmpty);
    expect(owners('user-a', excluded: {'machine'}), isEmpty);
  });

  test('legacy snapshots remain readable during the first upgraded launch', () async {
    final scope = capture();
    await PlexApiCache.instance.put(ServerId(client.scopedServerId), scope.endpoint, {
      'version': 1,
      'onDeck': [HomeSnapshotStore.displayJson(testMediaItem(id: 'legacy', serverId: 'server'))],
      'hubs': <Object>[],
    });
    expect((await store.read(scope, isCurrent: () => true))!.onDeck.single.id, 'legacy');
  });

  test('MediaBrowser images persist as safe paths and restore with the current authorized connection', () async {
    final mediaClient = _MediaBrowserSnapshotClient('machine');
    final scope = HomeSnapshotScope.capture(
      profileId: 'profile-a',
      clients: {'machine': mediaClient},
      hiddenLibraryKeys: {},
      useGlobalHubs: true,
    );
    final item = testMediaItem(
      id: 'film',
      serverId: 'machine',
      backend: MediaBackend.jellyfin,
      thumbPath: 'https://old.invalid/old-prefix/Items/film/Images/Primary?tag=revision&api_key=old-secret',
      backdropPaths: ['https://old.invalid/old-prefix/Items/film/Images/Backdrop/0?api_key=old-secret'],
    );
    await store.write(
      scope,
      HomeSnapshot(onDeck: [item], hubs: const []),
      authoritativeServerIds: {'machine'},
      isCurrent: () => true,
    );
    final rows = await database.select(database.apiCache).get();
    expect(rows.single.data, isNot(contains('old-secret')));
    expect(rows.single.data, isNot(contains('old-prefix')));
    final connection = JellyfinConnection(
      id: 'connection',
      baseUrl: 'https://new.invalid/new-prefix',
      serverName: 'Saved',
      serverMachineId: 'machine',
      userId: 'user-a',
      userName: 'A',
      accessToken: 'current-secret',
      deviceId: 'device',
      createdAt: DateTime(2026),
    );
    final ownerScope = HomeSnapshotScope.forOwners(
      profileId: 'profile-a',
      owners: HomeSnapshotOwner.fromBindings(
        profile: Profile.local(id: 'profile-a', displayName: 'A', createdAt: DateTime(2026)),
        connections: {'connection': connection},
        bindings: const [
          ProfileConnection(profileId: 'profile-a', connectionId: 'connection', userIdentifier: 'user-a'),
        ],
      ),
      hiddenLibraryKeys: {},
      useGlobalHubs: true,
    );
    final restored = (await store.read(ownerScope, isCurrent: () => true))!.onDeck.single;
    expect(
      restored.thumbPath,
      'https://new.invalid/new-prefix/Items/film/Images/Primary?tag=revision&api_key=current-secret',
    );
    expect(restored.backdropPaths!.single, startsWith('https://new.invalid/new-prefix/Items/film/Images/Backdrop/0?'));
    expect(restored.backdropPaths!.single, contains('api_key=current-secret'));
    expect(rows.single.data, isNot(contains('current-secret')));
    final relative = testMediaItem(
      id: 'film',
      backend: MediaBackend.jellyfin,
      thumbPath: '/Items/film/Images/Primary?tag=revision',
    );
    expect(HomeSnapshotStore.restoreArtwork(relative, mediaClient).thumbPath, contains('api_key=active-client-secret'));
  });
}

class _MediaBrowserSnapshotClient extends HomeStartupClient {
  _MediaBrowserSnapshotClient(super.id);

  @override
  MediaBackend get backend => MediaBackend.jellyfin;

  @override
  String get scopedServerId => '$serverId/user-a';

  @override
  String thumbnailUrl(String? path, {int? width, int? height, bool cover = true}) => const JellyfinImageAbsolutizer(
    baseUrl: 'https://active.invalid',
    accessToken: 'active-client-secret',
  ).absolutize(path)!;
}
