import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../media/ids.dart';
import '../media/library_query.dart';
import '../media/media_item.dart';
import '../media/media_library.dart';
import '../media/media_server_client.dart';
import '../utils/active_client_scope.dart';
import '../utils/app_logger.dart';
import 'api_cache.dart';
import 'home_snapshot_store.dart';

/// A request captures its owner before any disk or network await. Reusing it
/// for the write cannot attribute an old response to a new login.
abstract interface class LibraryPageCacheEntry {
  Future<LibraryPage<MediaItem>?> read();
  Future<void> write(LibraryPage<MediaItem> page);
}

/// Display snapshots live in the existing local API cache and are cleared by
/// its normal sign-out/cache cleanup. Age never blocks the first display:
/// every restored page is revalidated in the background.
class LibraryPageSnapshotStore {
  const LibraryPageSnapshotStore();

  LibraryPageCacheEntry? open({
    required String profileId,
    required MediaLibrary library,
    required MediaServerClient client,
    required LibraryQuery query,
    required bool collections,
    required bool Function() isCurrent,
  }) {
    final id = library.serverId;
    if (profileId.isEmpty || id == null || query.offset != 0 || client.backend != library.backend) return null;
    final scope = resolveActiveClientScopeId(serverId: ServerId(id), cacheServerId: client.cacheServerId);
    if (scope == null) return null;
    final plex = PlexProfileScopeId.tryParse(scope);
    if (plex != null && plex.profileId != profileId) return null;
    final authentication = client.authenticationSessionId;
    final key = sha256.convert(
      utf8.encode(
        jsonEncode([
          1,
          profileId,
          library.backend.name,
          library.id,
          collections,
          query.kind?.id,
          query.includeKinds.map((kind) => kind.id).toList(),
          query.offset,
          query.limit,
          query.sort?.field,
          query.sort?.direction.name,
          query.filters.map((filter) => filter.toStorageJson()).toList(),
          query.search,
          query.nameStartsWith,
        ]),
      ),
    );
    return _LibraryPageEntry(
      library: library,
      client: client,
      owner: ServerId(scope),
      endpoint: 'velo/library-page/v1/$key',
      limit: query.limit,
      isCurrent: () =>
          isCurrent() && identical(client.authenticationSessionId, authentication) && client.cacheServerId == scope,
    );
  }
}

class _LibraryPageEntry implements LibraryPageCacheEntry {
  const _LibraryPageEntry({
    required this.library,
    required this.client,
    required this.owner,
    required this.endpoint,
    required this.limit,
    required this.isCurrent,
  });

  final MediaLibrary library;
  final MediaServerClient client;
  final ServerId owner;
  final String endpoint;
  final int limit;
  final bool Function() isCurrent;

  @override
  Future<LibraryPage<MediaItem>?> read() async {
    try {
      if (!isCurrent()) return null;
      final row = await ApiCache.forBackend(library.backend).get(owner, endpoint);
      if (!isCurrent() || row == null || row['version'] != 1) return null;
      final items = <MediaItem>[];
      for (final raw in row['items'] as List) {
        final item = MediaItem.fromJson(Map<String, dynamic>.from(raw as Map));
        if (item.serverId == library.serverId && item.backend == library.backend) {
          items.add(HomeSnapshotStore.restoreArtwork(item, client));
        }
      }
      return LibraryPage(items: items.take(limit).toList(), totalCount: row['total'] as int);
    } catch (error, stackTrace) {
      appLogger.d('Library display cache read skipped', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<void> write(LibraryPage<MediaItem> page) async {
    try {
      if (!isCurrent()) return;
      await ApiCache.forBackend(library.backend).put(owner, endpoint, {
        'version': 1,
        'total': page.totalCount,
        'items': [
          for (final item in page.items.take(limit))
            if (item.serverId == library.serverId && item.backend == library.backend)
              HomeSnapshotStore.displayJson(item),
        ],
      }, isCurrent: isCurrent);
    } catch (error, stackTrace) {
      appLogger.d('Library display cache write skipped', error: error, stackTrace: stackTrace);
    }
  }
}
