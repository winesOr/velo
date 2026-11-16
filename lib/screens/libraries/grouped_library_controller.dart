import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../media/library_query.dart';
import '../../media/media_item.dart';
import '../../media/media_kind.dart';
import '../../media/media_library.dart';
import '../../media/media_playlist.dart';
import 'library_wall.dart';
import '../../utils/media_server_http_client.dart';

typedef GroupedLibraryFetcher =
    Future<LibraryPage<MediaItem>> Function(MediaLibrary library, LibraryQuery query, AbortController abort);

typedef GroupedPlaylistFetcher =
    Future<LibraryPage<MediaPlaylist>> Function(
      MediaLibrary library,
      LibraryQuery query,
      AbortController abort,
      String playlistType,
    );

enum GroupedLibrarySort { title, year, rating, updated, released }

@immutable
class GroupedLibrarySelection {
  const GroupedLibrarySelection({
    this.search = '',
    this.kind,
    this.year,
    this.watched,
    this.sort = GroupedLibrarySort.title,
    this.direction,
    this.wallType,
    this.genre,
    this.country,
  });

  final String search;
  final MediaKind? kind;
  final int? year;
  final bool? watched;
  final GroupedLibrarySort sort;
  final LibrarySortDirection? direction;
  final LibraryWallType? wallType;
  final String? genre;
  final String? country;

  Set<MediaKind> _rootKinds(MediaLibrary library) => library.defaultBrowseKinds.isNotEmpty
      ? library.defaultBrowseKinds.toSet()
      : {if (library.kind != MediaKind.unknown) library.kind};

  MediaKind? get _requestedKind =>
      kind ??
      switch (wallType) {
        LibraryWallType.movies => MediaKind.movie,
        LibraryWallType.series => MediaKind.show,
        _ => null,
      };

  bool get _videoCategory => const [
    LibraryWallType.anime,
    LibraryWallType.variety,
    LibraryWallType.concert,
    LibraryWallType.documentary,
  ].contains(wallType);

  bool includesLibrary(MediaLibrary library) {
    final kinds = _rootKinds(library);
    // An untyped view remains queryable; no type is inferred from its name.
    if (kinds.isEmpty) return true;
    if (_requestedKind case final requested?) return kinds.contains(requested);
    if (wallType == LibraryWallType.music) return kinds.any((kind) => kind.isMusic);
    if (_videoCategory) return kinds.any((kind) => !kind.isMusic);
    return true;
  }

  MediaKind? _queryKind(MediaLibrary library) {
    if (_requestedKind case final requested?) return requested;
    final kinds = _queryKinds(library);
    if (kinds.length == 1) return kinds.single;
    if (kinds.isNotEmpty) return null;
    return library.kind == MediaKind.unknown ? null : library.kind;
  }

  List<MediaKind> _queryKinds(MediaLibrary library) {
    if (_requestedKind != null) return const [];
    final kinds = _rootKinds(library);
    if (wallType == LibraryWallType.music) {
      return kinds.isEmpty
          ? const [MediaKind.artist, MediaKind.album, MediaKind.track]
          : kinds.where((kind) => kind.isMusic).toList();
    }
    if (_videoCategory) return kinds.where((kind) => !kind.isMusic).toList();
    return library.defaultBrowseKinds;
  }

  LibraryQuery queryFor(MediaLibrary library, int offset, int pageSize) => LibraryQuery(
    search: search.trim().isEmpty ? null : search.trim(),
    kind: _queryKind(library),
    includeKinds: _queryKinds(library),
    offset: offset,
    limit: pageSize,
    sort: LibrarySort(
      field: switch (sort) {
        GroupedLibrarySort.title => library.backend.usesMediaBrowserApi ? 'title' : 'titleSort',
        GroupedLibrarySort.year => library.backend.usesMediaBrowserApi ? 'productionYear' : 'year',
        GroupedLibrarySort.rating => 'rating',
        GroupedLibrarySort.updated => library.backend.usesMediaBrowserApi ? 'addedAt' : 'updatedAt',
        GroupedLibrarySort.released => 'originallyAvailableAt',
      },
      direction:
          direction ??
          (sort == GroupedLibrarySort.title ? LibrarySortDirection.ascending : LibrarySortDirection.descending),
    ),
    filters: [
      if (year != null && wallType == null) LibraryFilter(field: 'year', values: ['$year']),
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
  LibraryBrowseGroup(this.library, {this.playlistType});

  final String? playlistType;

  final MediaLibrary library;
  final List<MediaItem> items = [];
  final List<MediaPlaylist> playlists = [];
  int offset = 0;
  int total = 0;
  bool loading = false;
  Object? error;
  AbortController? _abort;

  bool get hasMore => offset < total;
}

/// Each library owns its cursor, cancellation and failure state. The search
/// wall merges the loaded pages without conflating server-local identities.
class GroupedLibraryController extends ChangeNotifier {
  GroupedLibraryController({
    required this.fetchPage,
    this.fetchCollectionsPage,
    this.fetchPlaylistsPage,
    this.pageSize = 36,
  });

  final GroupedLibraryFetcher fetchPage;
  final GroupedLibraryFetcher? fetchCollectionsPage;
  final GroupedPlaylistFetcher? fetchPlaylistsPage;
  final int pageSize;
  List<LibraryBrowseGroup> _groups = [];
  List<LibraryBrowseGroup> get groups => List.unmodifiable(_groups);
  GroupedLibrarySelection selection = const GroupedLibrarySelection();
  int _generation = 0;
  bool _disposed = false;

  List<LibraryWallEntry> get entries {
    final unique = <String, LibraryWallEntry>{};
    for (final group in _groups) {
      for (final item in <Object>[...group.items, ...group.playlists]) {
        final entry = LibraryWallEntry(group.library, item);
        final media = entry.media;
        final type = selection.wallType;
        if (media != null && type != null && !libraryWallTypeMatches(type, media)) continue;
        if (selection.genre != null && !(media?.genres?.contains(selection.genre) ?? false)) continue;
        if (selection.country != null && !(media?.countries?.contains(selection.country) ?? false)) continue;
        if (selection.wallType != null && selection.year != null && media?.year != selection.year) continue;
        if ((type == LibraryWallType.collections || type == LibraryWallType.playlists) &&
            !entry.title.toLowerCase().contains(selection.search.trim().toLowerCase())) {
          continue;
        }
        unique.putIfAbsent('${group.library.backend.name}:${entry.globalKey}', () => entry);
      }
    }
    final result = unique.values.toList();
    int compareNullable<T extends Comparable<T>>(T? a, T? b) {
      // Missing metadata stays at the end in both directions.
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      final comparison = a.compareTo(b);
      return (selection.direction ??
                  (selection.sort == GroupedLibrarySort.title
                      ? LibrarySortDirection.ascending
                      : LibrarySortDirection.descending)) ==
              LibrarySortDirection.ascending
          ? comparison
          : -comparison;
    }

    result.sort((a, b) {
      final compared = switch (selection.sort) {
        GroupedLibrarySort.title => compareNullable(a.title.toLowerCase(), b.title.toLowerCase()),
        GroupedLibrarySort.year => compareNullable(a.media?.year, b.media?.year),
        GroupedLibrarySort.rating => compareNullable(a.rating, b.rating),
        GroupedLibrarySort.updated => compareNullable(a.updatedAt, b.updatedAt),
        GroupedLibrarySort.released => compareNullable(a.releasedAt, b.releasedAt),
      };
      return compared != 0 ? compared : a.globalKey.compareTo(b.globalKey);
    });
    return result;
  }

  List<String> get genres =>
      entries.expand((entry) => entry.media?.genres ?? const <String>[]).toSet().toList()..sort();
  List<String> get countries =>
      entries.expand((entry) => entry.media?.countries ?? const <String>[]).toSet().toList()..sort();
  List<int> get years =>
      entries.map((entry) => entry.media?.year).whereType<int>().toSet().toList()..sort((a, b) => b.compareTo(a));

  /// Facets are applied to the loaded union, so changing them must not change
  /// a source query midway through its cursor. Server-side selections reset.
  void updateLocalSelection(GroupedLibrarySelection next) {
    if (_groups.any(
      (group) => selection.queryFor(group.library, 0, pageSize) != next.queryFor(group.library, 0, pageSize),
    )) {
      reset(_groups.map((group) => group.library).toList(), next);
      return;
    }
    selection = next;
    notifyListeners();
  }

  void reset(List<MediaLibrary> libraries, GroupedLibrarySelection next, {bool load = true}) {
    _generation++;
    for (final group in _groups) {
      group._abort?.abort();
    }
    selection = next;
    final included = next.wallType == null ? libraries : libraries.where(next.includesLibrary);
    final playlistOwners = <String>{};
    final groups = <LibraryBrowseGroup>[];
    for (final library in included) {
      if (next.wallType != LibraryWallType.playlists) {
        groups.add(LibraryBrowseGroup(library));
        continue;
      }
      final kinds = library.defaultBrowseKinds;
      final unknown = library.kind == MediaKind.unknown;
      final playlistTypes = {
        if (library.kind.isMusic || kinds.any((kind) => kind.isMusic) || (unknown && kinds.isEmpty)) 'audio',
        if (!library.kind.isMusic && (!unknown || kinds.isEmpty || kinds.any((kind) => !kind.isMusic))) 'video',
      };
      for (final type in playlistTypes) {
        if (playlistOwners.add('${library.serverId ?? library.globalKey}:$type')) {
          groups.add(LibraryBrowseGroup(library, playlistType: type));
        }
      }
    }
    _groups = groups;
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
    if (!selection.includesLibrary(group.library)) return;
    final generation = _generation;
    final abort = AbortController();
    group._abort = abort;
    group.loading = true;
    group.error = null;
    notifyListeners();
    try {
      final query = selection.queryFor(group.library, group.offset, pageSize);
      final LibraryPage<Object> page;
      if (selection.wallType == LibraryWallType.playlists) {
        final fetcher = fetchPlaylistsPage;
        if (fetcher == null) throw StateError('Playlist fetcher unavailable');
        page = await fetcher(group.library, query, abort, group.playlistType ?? 'video');
      } else {
        final fetcher = selection.wallType == LibraryWallType.collections
            ? fetchCollectionsPage ?? fetchPage
            : fetchPage;
        page = await fetcher(group.library, query, abort);
      }
      if (_disposed || generation != _generation || abort.isAborted) return;
      group.items.addAll(
        page.items.whereType<MediaItem>().map(
          (item) => item.serverId == null && group.library.serverId != null
              ? item.copyWith(serverId: group.library.serverId, serverName: item.serverName ?? group.library.serverName)
              : item,
        ),
      );
      group.playlists.addAll(page.items.whereType<MediaPlaylist>());
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
