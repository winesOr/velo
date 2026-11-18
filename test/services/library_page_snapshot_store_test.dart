import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/media/library_query.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_library.dart';
import 'package:plezy/services/api_cache.dart';
import 'package:plezy/services/library_page_snapshot_store.dart';
import 'package:plezy/services/plex_api_cache.dart';
import 'package:plezy/services/jellyfin_api_cache.dart';

import '../test_helpers/home_startup_fixtures.dart';
import '../test_helpers/media_items.dart';

const library = MediaLibrary(
  id: 'movies',
  backend: MediaBackend.plex,
  kind: MediaKind.movie,
  title: 'Movies',
  serverId: 'server',
);

class _BrowserSnapshotClient extends HomeStartupClient {
  _BrowserSnapshotClient(this.protocol) : super('server');
  final MediaBackend protocol;
  @override
  MediaBackend get backend => protocol;
  @override
  String get scopedServerId => '$serverId/user-a';
  @override
  String thumbnailUrl(String? path, {int? width, int? height, bool cover = true}) {
    final uri = Uri.parse('https://example.test/current$path');
    return uri.replace(queryParameters: {...uri.queryParameters, 'api_key': 'current-memory-token'}).toString();
  }
}

void main() {
  late AppDatabase database;
  late HomeStartupClient client;
  var authorized = true;
  const store = LibraryPageSnapshotStore();

  LibraryPageCacheEntry? open({
    String profile = 'profile-a',
    MediaLibrary source = library,
    LibraryQuery query = const LibraryQuery(limit: 2),
    bool collections = false,
  }) => store.open(
    profileId: profile,
    library: source,
    client: client,
    query: query,
    collections: collections,
    isCurrent: () => authorized,
  );

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    PlexApiCache.initialize(database);
    client = HomeStartupClient('server');
    authorized = true;
  });
  tearDown(() => database.close());

  test('display pages persist only their bounded metadata and restore across store instances', () async {
    final entry = open()!;
    await entry.write(
      LibraryPage(
        items: [
          testMediaItem(
            id: 'first',
            serverId: 'server',
            year: 2025,
            genres: ['Drama'],
            raw: {'token': 'private-value'},
            thumbPath: 'https://example.test/image?api_key=private-value',
          ),
          testMediaItem(id: 'second', serverId: 'server'),
          testMediaItem(id: 'overflow', serverId: 'server'),
        ],
        totalCount: 100,
      ),
    );
    final restored = await open()!.read();
    expect(restored!.items.map((item) => item.id), ['first', 'second']);
    expect(restored.totalCount, 100);
    expect(restored.items.first.year, 2025);
    expect(restored.items.first.genres, ['Drama']);
    expect(restored.items.first.raw, isNull);
    expect(restored.items.first.thumbPath, isNull);
    final rows = await database.select(database.apiCache).get();
    expect(rows.single.data, isNot(contains('private-value')));
    await ApiCache.clearRegisteredVolatile();
    expect(await open()!.read(), isNull);
  });

  test('full query, library, profile and content mode isolate cached results', () async {
    await open()!.write(
      LibraryPage(
        items: [testMediaItem(id: 'film', serverId: 'server')],
        totalCount: 1,
      ),
    );
    final others = [
      open(
        source: const MediaLibrary(id: 'other', backend: MediaBackend.plex, title: 'Other', serverId: 'server'),
      ),
      open(collections: true),
      open(query: const LibraryQuery(limit: 2, search: 'different')),
      open(query: const LibraryQuery(limit: 2, kind: MediaKind.show)),
      open(query: const LibraryQuery(limit: 2, includeKinds: [MediaKind.movie])),
      open(query: const LibraryQuery(limit: 2, nameStartsWith: 'A')),
      open(
        query: const LibraryQuery(limit: 2, sort: LibrarySort(field: 'rating')),
      ),
      open(
        query: const LibraryQuery(
          limit: 2,
          filters: [
            LibraryFilter(field: 'year', values: ['2024']),
          ],
        ),
      ),
    ];
    for (final entry in others) {
      expect(await entry!.read(), isNull);
    }
    expect(open(profile: 'profile-b'), isNull);
    expect(open(query: const LibraryQuery(offset: 2)), isNull);
    client.profileId = 'profile-b';
    expect(await open(profile: 'profile-b')!.read(), isNull);
  });

  test('auth rotation and invalidation prevent delayed reads and writes after cache cleanup', () async {
    final entry = open()!;
    client.authenticationSessionId = Object();
    final page = LibraryPage(
      items: [testMediaItem(id: 'film', serverId: 'server')],
      totalCount: 1,
    );
    await entry.write(page);
    expect(await entry.read(), isNull);
    expect(await database.select(database.apiCache).get(), isEmpty);
    final current = open()!;
    final pending = current.write(page);
    authorized = false;
    await ApiCache.clearRegisteredVolatile();
    await pending;
    expect(await database.select(database.apiCache).get(), isEmpty);
  });

  test('older display data remains usable while malformed disk data falls back to the network path', () async {
    await open()!.write(
      LibraryPage(
        items: [testMediaItem(id: 'film', serverId: 'server')],
        totalCount: 1,
      ),
    );
    await database.update(database.apiCache).write(ApiCacheCompanion(cachedAt: Value(DateTime(2000))));
    expect((await open()!.read())!.items.single.id, 'film');
    await database.update(database.apiCache).write(const ApiCacheCompanion(data: Value('{broken')));
    expect(await open()!.read(), isNull);
  });

  for (final backend in [MediaBackend.jellyfin, MediaBackend.emby]) {
    test('${backend.name} display cache preserves images without persisting image credentials', () async {
      JellyfinApiCache.initialize(database);
      client = _BrowserSnapshotClient(backend);
      final source = MediaLibrary(id: 'movies', backend: backend, title: 'Movies', serverId: 'server');
      await open(source: source)!.write(
        LibraryPage(
          items: [
            testMediaItem(
              id: 'film',
              serverId: 'server',
              backend: backend,
              thumbPath: 'https://example.test/old-base/Items/film/Images/Primary?tag=one&api_key=old-private-token',
            ),
          ],
          totalCount: 1,
        ),
      );
      final rows = await database.select(database.apiCache).get();
      expect(rows.single.data, isNot(contains('old-private-token')));
      final restored = await open(source: source)!.read();
      expect(restored!.items.single.thumbPath, contains('/Items/film/Images/Primary'));
      expect(restored.items.single.thumbPath, contains('api_key=current-memory-token'));
      expect(rows.single.data, isNot(contains('current-memory-token')));
    });
  }
}
