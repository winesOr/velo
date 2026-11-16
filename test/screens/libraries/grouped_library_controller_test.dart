import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/library_query.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_library.dart';
import 'package:plezy/media/media_playlist.dart';
import 'package:plezy/screens/libraries/library_wall.dart';
import 'package:plezy/screens/libraries/grouped_library_controller.dart';
import 'package:plezy/services/library_query_translator.dart';
import 'package:plezy/utils/media_server_http_client.dart';

const a = MediaLibrary(
  id: 'same-library',
  backend: MediaBackend.plex,
  title: 'Movies A',
  kind: MediaKind.movie,
  serverId: 'a',
);
const b = MediaLibrary(
  id: 'same-library',
  backend: MediaBackend.emby,
  title: 'Movies B',
  kind: MediaKind.movie,
  serverId: 'b',
);

MediaItem item(MediaLibrary library, String id) => MediaItem(
  id: id,
  backend: library.backend,
  kind: MediaKind.movie,
  title: '${library.serverId} $id',
  serverId: library.serverId,
);

void main() {
  test('groups with matching library and media IDs retain separate owner cursors', () async {
    final requests = <(String, int)>[];
    final controller = GroupedLibraryController(
      pageSize: 2,
      fetchPage: (library, query, abort) async {
        requests.add((library.globalKey, query.offset));
        return LibraryPage(items: [item(library, '${query.offset}')], totalCount: 3, offset: query.offset);
      },
    );
    addTearDown(controller.dispose);
    controller.reset([a, b], const GroupedLibrarySelection(), load: false);
    await Future.wait(controller.groups.map(controller.loadMore));
    await controller.loadMore(controller.groups.first);
    expect(requests, [('a:same-library', 0), ('b:same-library', 0), ('a:same-library', 1)]);
    expect(controller.groups.first.items.map((i) => i.serverId), ['a', 'a']);
    expect(controller.groups.last.items.single.serverId, 'b');
    expect(controller.groups.last.offset, 1);
  });

  test('query reset aborts every old group and discards delayed responses', () async {
    final oldPage = Completer<LibraryPage<MediaItem>>();
    final aborts = <AbortController>[];
    final controller = GroupedLibraryController(
      fetchPage: (library, query, abort) {
        aborts.add(abort);
        if (query.search == 'old') return oldPage.future;
        return Future.value(LibraryPage(items: [item(library, 'new')], totalCount: 1));
      },
    );
    addTearDown(controller.dispose);
    controller.reset([a], const GroupedLibrarySelection(search: 'old'), load: false);
    final pending = controller.loadMore(controller.groups.single);
    controller.reset([b], const GroupedLibrarySelection(search: 'new'), load: false);
    expect(aborts.single.isAborted, isTrue);
    await controller.loadMore(controller.groups.single);
    oldPage.complete(LibraryPage(items: [item(a, 'old')], totalCount: 1));
    await pending;
    expect(controller.groups.single.library, b);
    expect(controller.groups.single.items.single.id, 'new');
    expect(controller.groups.single.loading, isFalse);
  });

  test('one failed page retains its items and does not block other groups; retry keeps offset', () async {
    var failed = false;
    final offsets = <int>[];
    final controller = GroupedLibraryController(
      fetchPage: (library, query, abort) async {
        if (library.serverId == 'a') {
          offsets.add(query.offset);
          if (query.offset == 1 && !failed) {
            failed = true;
            throw StateError('offline');
          }
        }
        return LibraryPage(items: [item(library, '${query.offset}')], totalCount: 2);
      },
    );
    addTearDown(controller.dispose);
    controller.reset([a, b], const GroupedLibrarySelection(), load: false);
    await Future.wait(controller.groups.map(controller.loadMore));
    final first = controller.groups.first;
    await controller.loadMore(first);
    expect(first.error, isNotNull);
    expect(first.items, hasLength(1));
    expect(controller.groups.last.error, isNull);
    await controller.loadMore(first);
    expect(offsets, [0, 1, 1]);
    expect(first.items, hasLength(2));
    expect(first.error, isNull);
  });

  test('clearing filters resets cursors and sends neutral server-side queries with source-specific sort', () async {
    final queries = <LibraryQuery>[];
    final controller = GroupedLibraryController(
      fetchPage: (library, query, abort) async {
        queries.add(query);
        return const LibraryPage(items: [], totalCount: 0);
      },
    );
    addTearDown(controller.dispose);
    const selected = GroupedLibrarySelection(search: 'movie', year: 2025, watched: true, sort: GroupedLibrarySort.year);
    controller.reset([b], selected, load: false);
    await controller.loadMore(controller.groups.single);
    final wire = const JellyfinLibraryQueryTranslator(
      userId: 'u',
      parentId: 'l',
      fields: '',
    ).toQueryParameters(queries.single);
    expect(wire['SearchTerm'], 'movie');
    expect(wire['Years'], '2025');
    expect(wire['Filters'], 'IsPlayed');
    expect(wire['SortBy'], 'ProductionYear');
    controller.reset([b], const GroupedLibrarySelection(), load: false);
    await controller.loadMore(controller.groups.single);
    expect(queries.last.offset, 0);
    expect(queries.last.filters, isEmpty);
    expect(queries.last.search, isNull);
    expect(queries.last.sort?.field, 'title');
    expect(const GroupedLibrarySelection().queryFor(a, 0, 10).sort?.field, 'titleSort');
  });

  test('empty page stops pagination even if remote total remains stale', () async {
    final controller = GroupedLibraryController(
      fetchPage: (_, query, _) async => LibraryPage(items: [], totalCount: 100),
    );
    addTearDown(controller.dispose);
    controller.reset([a], const GroupedLibrarySelection(), load: false);
    await controller.loadMore(controller.groups.single);
    expect(controller.groups.single.hasMore, isFalse);
  });

  test('a full page with a contradictory zero total keeps pagination enabled', () async {
    final controller = GroupedLibraryController(
      pageSize: 2,
      fetchPage: (library, query, _) async =>
          LibraryPage(items: [item(library, '1'), item(library, '2')], totalCount: 0),
    );
    addTearDown(controller.dispose);
    controller.reset([a], const GroupedLibrarySelection(), load: false);
    await controller.loadMore(controller.groups.single);
    expect(controller.groups.single.hasMore, isTrue);
  });

  test(
    'mobile wall merges source identities, sorts metadata and applies facet unions without moving cursors',
    () async {
      final controller = GroupedLibraryController(
        fetchPage: (library, query, abort) async {
          final media = MediaItem(
            id: 'same',
            backend: library.backend,
            serverId: library.serverId,
            kind: MediaKind.movie,
            title: library.title,
            rating: library == a ? 2 : 8,
            genres: [library == a ? 'Drama' : 'Animation'],
            year: library == a ? 2020 : 2025,
          ).copyWith(countries: [library == a ? 'US' : 'Japan']);
          return LibraryPage(items: [media, media], totalCount: 2);
        },
      );
      addTearDown(controller.dispose);
      controller.reset(
        [a, b],
        const GroupedLibrarySelection(wallType: LibraryWallType.all, sort: GroupedLibrarySort.rating),
        load: false,
      );
      await Future.wait(controller.groups.map(controller.loadMore));
      expect(controller.entries.map((entry) => entry.library.serverId), ['b', 'a']);
      expect(controller.genres, ['Animation', 'Drama']);
      expect(controller.countries, ['Japan', 'US']);
      expect(controller.years, [2025, 2020]);
      final original = controller.groups.first;
      controller.updateLocalSelection(
        const GroupedLibrarySelection(
          wallType: LibraryWallType.all,
          sort: GroupedLibrarySort.rating,
          genre: 'Drama',
          country: 'US',
          year: 2020,
        ),
      );
      expect(controller.entries.single.library, a);
      expect(controller.groups.first, same(original));
      expect(original.offset, 2);
      expect(controller.selection.queryFor(a, original.offset, 36).filters, isEmpty);
      controller.reset(
        [a, b],
        const GroupedLibrarySelection(
          wallType: LibraryWallType.all,
          sort: GroupedLibrarySort.rating,
          direction: LibrarySortDirection.ascending,
        ),
        load: false,
      );
      await Future.wait(controller.groups.map(controller.loadMore));
      expect(controller.entries.map((entry) => entry.library.serverId), ['a', 'b']);
      expect(controller.selection.queryFor(b, 0, 36).sort?.direction, LibrarySortDirection.ascending);
    },
  );

  test('mobile collections and playlists retain separate pages and deduplicate server-wide records', () async {
    const secondA = MediaLibrary(
      id: 'other',
      backend: MediaBackend.plex,
      title: 'Other',
      kind: MediaKind.movie,
      serverId: 'a',
    );
    final playlistRequests = <String>[];
    final playlistTypes = <String>[];
    final collectionRequests = <String>[];
    final controller = GroupedLibraryController(
      fetchPage: (_, _, _) async => throw StateError('ordinary browse must not own container pages'),
      fetchPlaylistsPage: (library, query, abort, playlistType) async {
        playlistRequests.add(library.globalKey);
        playlistTypes.add(playlistType);
        return LibraryPage(
          items: [
            MediaPlaylist(
              id: 'same-$playlistType',
              backend: library.backend,
              title: 'Keep',
              playlistType: playlistType,
              serverId: library.serverId,
            ),
            MediaPlaylist(
              id: 'other-$playlistType',
              backend: library.backend,
              title: 'Other',
              playlistType: playlistType,
              serverId: library.serverId,
            ),
          ],
          totalCount: 2,
        );
      },
      fetchCollectionsPage: (library, query, abort) async {
        collectionRequests.add(library.globalKey);
        return LibraryPage(
          items: [
            MediaItem(
              id: 'collection',
              backend: library.backend,
              serverId: library.serverId,
              kind: MediaKind.collection,
              title: 'Keep',
            ),
          ],
          totalCount: 1,
        );
      },
    );
    addTearDown(controller.dispose);
    controller.reset(
      [a, secondA, b],
      const GroupedLibrarySelection(wallType: LibraryWallType.playlists, search: 'Keep'),
      load: false,
    );
    await Future.wait(controller.groups.map(controller.loadMore));
    expect(playlistRequests, [a.globalKey, b.globalKey]);
    expect(controller.entries, hasLength(2));
    expect(controller.entries.every((entry) => entry.playlist?.title == 'Keep'), isTrue);
    const mixed = MediaLibrary(
      id: 'mixed',
      backend: MediaBackend.plex,
      title: 'Mixed',
      serverId: 'a',
      defaultBrowseKinds: [MediaKind.movie, MediaKind.artist],
    );
    playlistRequests.clear();
    playlistTypes.clear();
    controller.reset(
      [mixed],
      const GroupedLibrarySelection(wallType: LibraryWallType.playlists, search: 'Keep'),
      load: false,
    );
    await Future.wait(controller.groups.map(controller.loadMore));
    expect(playlistTypes, ['audio', 'video']);
    expect(controller.groups.map((group) => group.offset), [2, 2]);
    expect(controller.entries, hasLength(2));

    controller.reset([a, secondA], const GroupedLibrarySelection(wallType: LibraryWallType.collections), load: false);
    await Future.wait(controller.groups.map(controller.loadMore));
    expect(collectionRequests, [a.globalKey, secondA.globalKey]);
    expect(controller.entries, hasLength(1));
  });

  test('special categories use actual genres and basic types scope the source query', () {
    final namedOnly = item(a, 'Anime Library');
    expect(libraryWallTypeMatches(LibraryWallType.anime, namedOnly), isFalse);
    final animation = MediaItem(id: 'real', backend: MediaBackend.plex, kind: MediaKind.movie, genres: ['Animation']);
    expect(libraryWallTypeMatches(LibraryWallType.anime, animation), isTrue);
    expect(libraryWallTypeMatches(LibraryWallType.documentary, animation), isFalse);
    expect(const GroupedLibrarySelection(wallType: LibraryWallType.series).includesLibrary(a), isFalse);
    const mixed = MediaLibrary(
      id: 'mixed',
      backend: MediaBackend.emby,
      title: 'Mixed',
      defaultBrowseKinds: [MediaKind.movie, MediaKind.album],
    );
    expect(const GroupedLibrarySelection(wallType: LibraryWallType.music).queryFor(mixed, 0, 36).includeKinds, [
      MediaKind.album,
    ]);
    expect(const GroupedLibrarySelection(wallType: LibraryWallType.movies).queryFor(a, 0, 36).kind, MediaKind.movie);
  });
}
