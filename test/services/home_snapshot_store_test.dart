import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/services/api_cache.dart';
import 'package:plezy/services/home_snapshot_store.dart';
import 'package:plezy/services/plex_api_cache.dart';

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

  test('profile, scope, hidden libraries, layout and server set cannot share a snapshot', () async {
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
    expect(await store.read(capture(), isCurrent: () => true), isNull);
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

  test('expired snapshot is not displayed', () async {
    final scope = capture();
    await save(scope);
    expect(await const HomeSnapshotStore(maxAge: Duration.zero).read(scope, isCurrent: () => true), isNull);
  });
}
