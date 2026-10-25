import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../media/library_query.dart';
import '../../media/media_item.dart';
import '../../media/media_kind.dart';
import '../../media/media_library.dart';
import '../../utils/media_server_http_client.dart';

typedef GroupedLibraryFetcher =
    Future<LibraryPage<MediaItem>> Function(MediaLibrary library, LibraryQuery query, AbortController abort);

enum GroupedLibrarySort { title, year, rating }

@immutable
class GroupedLibrarySelection {
  const GroupedLibrarySelection({
    this.search = '',
    this.kind,
    this.year,
    this.watched,
    this.sort = GroupedLibrarySort.title,
  });

  final String search;
  final MediaKind? kind;
  final int? year;
  final bool? watched;
  final GroupedLibrarySort sort;

  LibraryQuery queryFor(MediaLibrary library, int offset, int pageSize) => LibraryQuery(
    search: search.trim().isEmpty ? null : search.trim(),
    kind: kind ?? (library.kind == MediaKind.unknown ? null : library.kind),
    includeKinds: kind == null ? library.defaultBrowseKinds : const [],
    offset: offset,
    limit: pageSize,
    sort: LibrarySort(
      field: switch (sort) {
        GroupedLibrarySort.title => library.backend.usesMediaBrowserApi ? 'title' : 'titleSort',
        GroupedLibrarySort.year => library.backend.usesMediaBrowserApi ? 'productionYear' : 'year',
        GroupedLibrarySort.rating => 'rating',
      },
      direction: sort == GroupedLibrarySort.title ? LibrarySortDirection.ascending : LibrarySortDirection.descending,
    ),
    filters: [
      if (year != null) LibraryFilter(field: 'year', values: ['$year']),
      if (watched != null)
        LibraryFilter(
          field: 'unwatched',
          op: watched! ? LibraryFilterOperator.isNot : LibraryFilterOperator.is_,
          values: const ['1'],
        ),
    ],
  );
}

class LibraryBrowseGroup {
  LibraryBrowseGroup(this.library);

  final MediaLibrary library;
  final List<MediaItem> items = [];
  int offset = 0;
  int total = 0;
  bool loading = false;
  Object? error;
  AbortController? _abort;

  bool get hasMore => offset < total;
}

/// No cross-server ranking or shared cursor: each library owns its page state.
class GroupedLibraryController extends ChangeNotifier {
  GroupedLibraryController({required this.fetchPage, this.pageSize = 36});

  final GroupedLibraryFetcher fetchPage;
  final int pageSize;
  List<LibraryBrowseGroup> _groups = [];
  List<LibraryBrowseGroup> get groups => List.unmodifiable(_groups);
  GroupedLibrarySelection selection = const GroupedLibrarySelection();
  int _generation = 0;
  bool _disposed = false;

  void reset(List<MediaLibrary> libraries, GroupedLibrarySelection next, {bool load = true}) {
    _generation++;
    for (final group in _groups) {
      group._abort?.abort();
    }
    selection = next;
    _groups = [for (final library in libraries) LibraryBrowseGroup(library)];
    notifyListeners();
    if (load) loadAll();
  }

  void loadAll() {
    for (final group in _groups) {
      unawaited(loadMore(group));
    }
  }

  Future<void> loadMore(LibraryBrowseGroup group) async {
    if (_disposed || !_groups.contains(group) || group.loading || (group.offset > 0 && !group.hasMore)) return;
    final kind = selection.kind;
    if (kind != null && group.library.kind != MediaKind.unknown && group.library.kind != kind) return;
    final generation = _generation;
    final abort = AbortController();
    group._abort = abort;
    group.loading = true;
    group.error = null;
    notifyListeners();
    try {
      final page = await fetchPage(group.library, selection.queryFor(group.library, group.offset, pageSize), abort);
      if (_disposed || generation != _generation || abort.isAborted) return;
      group.items.addAll(page.items);
      group.offset += page.items.length;
      // A backend can omit an exact count. Do not display total as a claim.
      group.total = page.items.isEmpty
          ? group.offset
          : page.totalCount < group.offset
          ? fallbackPageTotal(
              offset: group.offset - page.items.length,
              itemCount: page.items.length,
              requestedSize: pageSize,
            )
          : page.totalCount;
    } catch (error) {
      if (_disposed || generation != _generation || abort.isAborted) return;
      group.error = error;
    } finally {
      if (!_disposed && generation == _generation && !abort.isAborted) {
        group.loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final group in _groups) {
      group._abort?.abort();
    }
    super.dispose();
  }
}
