import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../connection/connection.dart';
import '../media/ids.dart';
import '../media/media_backend.dart';
import '../media/media_hub.dart';
import '../media/media_item.dart';
import '../media/media_server_client.dart';
import '../profiles/profile.dart';
import '../profiles/profile_connection.dart';
import '../utils/active_client_scope.dart';
import '../utils/app_logger.dart';
import 'api_cache.dart';
import 'jellyfin_mappers.dart';

class HomeSnapshot {
  const HomeSnapshot({required this.onDeck, required this.hubs});
  final List<MediaItem> onDeck;
  final List<MediaHub> hubs;
}

/// A persisted display cache belongs to an authorized profile/server/user,
/// independently of whether a connection probe has produced a live client.
class HomeSnapshotOwner {
  const HomeSnapshotOwner({
    required this.serverId,
    required this.backend,
    required this.scope,
    required this.serverName,
    this.resolveArtwork,
  });

  final String serverId;
  final MediaBackend backend;
  final String scope;
  final String serverName;
  final MediaItem Function(MediaItem)? resolveArtwork;

  static List<HomeSnapshotOwner> fromBindings({
    required Profile profile,
    required Map<String, Connection> connections,
    required List<ProfileConnection> bindings,
    Set<String> excludedServerIds = const {},
  }) {
    final ids = {
      for (final binding in bindings)
        if (binding.profileId == profile.id) binding.connectionId,
      ?profile.parentConnectionId,
    };
    final owners = <String, HomeSnapshotOwner>{};
    for (final id in ids) {
      switch (connections[id]) {
        case PlexAccountConnection(:final servers):
          for (final server in servers) {
            if (server.clientIdentifier.isEmpty || excludedServerIds.contains(server.clientIdentifier)) continue;
            owners.putIfAbsent(
              server.clientIdentifier,
              () => HomeSnapshotOwner(
                serverId: server.clientIdentifier,
                backend: MediaBackend.plex,
                scope: buildPlexProfileScopeId(serverId: ServerId(server.clientIdentifier), profileId: profile.id),
                serverName: server.name,
              ),
            );
          }
        case JellyfinConnection(
          :final serverMachineId,
          :final userId,
          :final serverName,
          :final backend,
          :final baseUrl,
          :final accessToken,
        ):
          final bound = bindings.where((binding) => binding.connectionId == id && binding.profileId == profile.id);
          if (excludedServerIds.contains(serverMachineId) ||
              serverMachineId.isEmpty ||
              userId.isEmpty ||
              !bound.any((binding) => binding.userIdentifier == userId)) {
            continue;
          }
          owners.putIfAbsent(
            serverMachineId,
            () => HomeSnapshotOwner(
              serverId: serverMachineId,
              backend: backend,
              scope: '$serverMachineId/$userId',
              serverName: serverName,
              resolveArtwork: (item) => HomeSnapshotStore._restoreArtwork(
                item,
                JellyfinImageAbsolutizer(baseUrl: baseUrl, accessToken: accessToken).absolutize,
              ),
            ),
          );
        case null:
          break;
      }
    }
    return List.unmodifiable(owners.values);
  }
}

class HomeSnapshotAuthorization {
  const HomeSnapshotAuthorization({required this.owners, required this.isCurrent});
  final List<HomeSnapshotOwner> owners;
  final bool Function() isCurrent;
}

/// Captures both persistent user namespaces and the live authentication
/// epoch. No credential is stored in the key or snapshot body.
class HomeSnapshotScope {
  HomeSnapshotScope._(this._clients, this._onlineServerIds, this._owners, this.endpoint, this._endpoints);

  final Map<String, ({MediaServerClient client, Object authentication, String scope})> _clients;
  final String endpoint;
  final Set<String> _onlineServerIds;
  final Map<String, HomeSnapshotOwner> _owners;
  final Map<String, String> _endpoints;

  static HomeSnapshotScope forOwners({
    required String profileId,
    required Iterable<HomeSnapshotOwner> owners,
    required Set<String> hiddenLibraryKeys,
    required bool useGlobalHubs,
  }) {
    final valid = <String, HomeSnapshotOwner>{};
    for (final owner in owners) {
      final scope = resolveActiveClientScopeId(serverId: ServerId(owner.serverId), cacheServerId: owner.scope);
      if (scope == null) continue;
      final plexScope = PlexProfileScopeId.tryParse(scope);
      if (plexScope != null && plexScope.profileId != profileId) continue;
      valid[owner.serverId] = owner;
    }
    final hidden = hiddenLibraryKeys.toList()..sort();
    final serverScopes = [for (final entry in valid.entries) '${entry.key}:${entry.value.scope}']..sort();
    final legacy = sha256.convert(utf8.encode(jsonEncode([1, profileId, serverScopes, hidden, useGlobalHubs])));
    final endpoints = {
      for (final owner in valid.values)
        owner.serverId:
            'velo/home-snapshot/v2/${sha256.convert(utf8.encode(jsonEncode([2, profileId, owner.backend.name, owner.serverId, owner.scope, hidden, useGlobalHubs])))}',
    };
    return HomeSnapshotScope._(
      const {},
      const {},
      Map.unmodifiable(valid),
      'velo/home-snapshot/v1/$legacy',
      Map.unmodifiable(endpoints),
    );
  }

  static HomeSnapshotScope capture({
    required String profileId,
    required Map<String, MediaServerClient> clients,
    required Set<String> hiddenLibraryKeys,
    required bool useGlobalHubs,
  }) {
    final scoped = <String, ({MediaServerClient client, Object authentication, String scope})>{};
    for (final entry in clients.entries) {
      final client = entry.value;
      final scope = resolveActiveClientScopeId(serverId: ServerId(entry.key), cacheServerId: client.cacheServerId);
      if (scope == null) continue;
      final plexScope = PlexProfileScopeId.tryParse(scope);
      if (plexScope != null && plexScope.profileId != profileId) continue;
      scoped[entry.key] = (client: client, authentication: client.authenticationSessionId, scope: scope);
    }
    final readScope = forOwners(
      profileId: profileId,
      owners: [
        for (final entry in scoped.entries)
          HomeSnapshotOwner(
            serverId: entry.key,
            backend: entry.value.client.backend,
            scope: entry.value.scope,
            serverName: entry.value.client.serverName ?? entry.key,
            resolveArtwork: (item) => HomeSnapshotStore.restoreArtwork(item, entry.value.client),
          ),
      ],
      hiddenLibraryKeys: hiddenLibraryKeys,
      useGlobalHubs: useGlobalHubs,
    );
    return HomeSnapshotScope._(
      Map.unmodifiable(scoped),
      Set.unmodifiable(clients.keys),
      readScope._owners,
      readScope.endpoint,
      readScope._endpoints,
    );
  }

  bool isCurrent(Map<String, MediaServerClient> clients, {bool requireSameServers = true}) =>
      (!requireSameServers || clients.length == _onlineServerIds.length) &&
      _onlineServerIds.every(clients.containsKey) &&
      _clients.entries.every((entry) {
        final current = clients[entry.key];
        return identical(current, entry.value.client) &&
            identical(current?.authenticationSessionId, entry.value.authentication) &&
            current?.cacheServerId == entry.value.scope;
      });
}

/// Uses the existing volatile API cache table, so sign-out/cache cleanup
/// already removes these rows. Display snapshots are not live observations;
/// callers revalidate profile authorization before displaying any cache row.
class HomeSnapshotStore {
  const HomeSnapshotStore({this.maxAge});

  /// The last successful page stays usable until logout/cache clear. A
  /// caller may set a shorter retention window; network refresh always runs.
  final Duration? maxAge;

  Future<HomeSnapshot?> read(HomeSnapshotScope scope, {required bool Function() isCurrent}) async {
    final onDeck = <MediaItem>[];
    final hubs = <MediaHub>[];
    await Future.wait(
      scope._owners.entries.map((entry) async {
        try {
          final cache = ApiCache.forBackend(entry.value.backend);
          Future<Map<String, dynamic>?> read(String endpoint) => maxAge == null
              ? cache.get(ServerId(entry.value.scope), endpoint)
              : cache.getIfFresh(ServerId(entry.value.scope), endpoint, maxAge: maxAge!);
          final row = await read(scope._endpoints[entry.key]!) ?? await read(scope.endpoint);
          if (row == null || (row['version'] != 1 && row['version'] != 2) || !isCurrent()) return;
          List<MediaItem> items(dynamic raw) => [
            for (final item in _items(raw, entry.key)) entry.value.resolveArtwork?.call(item) ?? item,
          ];
          final rows = (row['hubs'] as List<dynamic>? ?? const []).map((raw) {
            final json = Map<String, dynamic>.from(raw as Map);
            return MediaHub(
              id: json['id'] as String,
              title: json['title'] as String,
              type: json['type'] as String,
              identifier: json['identifier'] as String?,
              size: json['size'] as int? ?? 0,
              more: json['more'] as bool? ?? false,
              libraryId: json['libraryId'] as String?,
              serverId: entry.key,
              serverName: entry.value.serverName,
              items: items(json['items']),
            );
          }).toList();
          onDeck.addAll(items(row['onDeck']));
          hubs.addAll(rows);
        } catch (error, stackTrace) {
          appLogger.d('Home snapshot read skipped', error: error, stackTrace: stackTrace);
        }
      }),
    );
    if (!isCurrent() || (onDeck.isEmpty && hubs.every((hub) => hub.items.isEmpty))) return null;
    onDeck.sort((a, b) {
      final recency = b.recencySortKey.compareTo(a.recencySortKey);
      return recency != 0 ? recency : a.globalKey.compareTo(b.globalKey);
    });
    final serverOrder = scope._owners.keys.toList();
    hubs.sort((a, b) => serverOrder.indexOf(a.serverId ?? '').compareTo(serverOrder.indexOf(b.serverId ?? '')));
    return HomeSnapshot(onDeck: onDeck, hubs: hubs);
  }

  Future<void> write(
    HomeSnapshotScope scope,
    HomeSnapshot snapshot, {
    required Set<String> authoritativeServerIds,
    required bool Function() isCurrent,
  }) async {
    await Future.wait(
      scope._clients.entries.map((entry) async {
        if (!authoritativeServerIds.contains(entry.key) || !isCurrent()) return;
        try {
          final payload = <String, dynamic>{
            'version': 2,
            'onDeck': [
              for (final item in snapshot.onDeck)
                if (item.serverId == entry.key) displayJson(item),
            ],
            'hubs': [
              for (final hub in snapshot.hubs)
                if (hub.serverId == entry.key)
                  {
                    'id': hub.id,
                    'title': hub.title,
                    'type': hub.type,
                    'identifier': hub.identifier,
                    'size': hub.size,
                    'more': hub.more,
                    'libraryId': hub.libraryId,
                    'items': [
                      for (final item in hub.items)
                        if (item.serverId == entry.key) displayJson(item),
                    ],
                  },
            ],
          };
          if (!isCurrent()) return;
          await ApiCache.forBackend(
            entry.value.client.backend,
          ).put(ServerId(entry.value.scope), scope._endpoints[entry.key]!, payload, isCurrent: isCurrent);
        } catch (error, stackTrace) {
          appLogger.d('Home snapshot write skipped', error: error, stackTrace: stackTrace);
        }
      }),
    );
  }

  static List<MediaItem> _items(dynamic value, String serverId) => [
    for (final raw in value as List<dynamic>? ?? const [])
      if (MediaItem.fromJson(Map<String, dynamic>.from(raw as Map)) case final item)
        if (item.serverId == serverId) item,
  ];

  static Map<String, dynamic> displayJson(MediaItem item) {
    final json = item.toJson()
      ..remove('raw')
      ..remove('mediaVersions')
      ..remove('trailerKey')
      ..remove('backendFolderKey')
      ..remove('roles');
    String? safeArtwork(String value) {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.userInfo.isNotEmpty) return null;
      bool sensitive(String key) {
        final normalized = key.toLowerCase();
        return normalized.contains('token') ||
            normalized == 'api_key' ||
            normalized == 'apikey' ||
            normalized == 'password';
      }

      if (!uri.queryParameters.keys.any(sensitive)) return value;
      // MediaBrowser image URLs include credentials and may carry a reverse
      // proxy prefix. Keep only the known server asset path and safe query;
      // the authorized connection adds its current address/token on restore.
      if (item.backend.usesMediaBrowserApi) {
        final imagePath = RegExp(r'/Items/[^/]+/Images/', caseSensitive: false).firstMatch(uri.path);
        if (imagePath != null) {
          return Uri.parse('${uri.path.substring(imagePath.start)}${uri.hasQuery ? '?${uri.query}' : ''}')
              .replace(
                queryParameters: {
                  for (final entry in uri.queryParameters.entries)
                    if (!sensitive(entry.key)) entry.key: entry.value,
                },
              )
              .toString();
        }
      }
      return null;
    }

    for (final key in json.keys.toList()) {
      final value = json[key];
      if (key.endsWith('Path') && value is String) {
        final path = safeArtwork(value);
        if (path == null) {
          json.remove(key);
        } else {
          json[key] = path;
        }
      }
      if (key.endsWith('Paths') && value is List) {
        json[key] = value.whereType<String>().map(safeArtwork).whereType<String>().toList();
      }
    }
    return json;
  }

  static MediaItem restoreArtwork(MediaItem item, MediaServerClient client) =>
      client.backend.usesMediaBrowserApi ? _restoreArtwork(item, client.thumbnailUrl) : item;

  static MediaItem _restoreArtwork(MediaItem item, String? Function(String?) resolve) {
    final json = item.toJson();
    String restore(String path) =>
        RegExp(r'^/Items/[^/]+/Images/', caseSensitive: false).hasMatch(path) ? resolve(path) ?? path : path;
    for (final key in json.keys.toList()) {
      final value = json[key];
      if (key.endsWith('Path') && value is String) json[key] = restore(value);
      if (key.endsWith('Paths') && value is List) json[key] = value.whereType<String>().map(restore).toList();
    }
    return MediaItem.fromJson(json);
  }
}
