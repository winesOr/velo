import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/library_query.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_library.dart';
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
}
