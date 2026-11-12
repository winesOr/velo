import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../media/ids.dart';
import '../media/media_hub.dart';
import '../media/media_item.dart';
import '../media/media_server_client.dart';
import '../utils/active_client_scope.dart';
import '../utils/app_logger.dart';
import 'api_cache.dart';

class HomeSnapshot {
  const HomeSnapshot({required this.onDeck, required this.hubs});
  final List<MediaItem> onDeck;
  final List<MediaHub> hubs;
}

/// Captures both persistent user namespaces and the live authentication
/// epoch. No credential is stored in the key or snapshot body.
class HomeSnapshotScope {
  HomeSnapshotScope._(this._clients, this._onlineServerIds, this.endpoint);

  final Map<String, ({MediaServerClient client, Object authentication, String scope})> _clients;
  final String endpoint;
  final Set<String> _onlineServerIds;

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
    final serverScopes = [for (final entry in scoped.entries) '${entry.key}:${entry.value.scope}']..sort();
    final hidden = hiddenLibraryKeys.toList()..sort();
    final key = sha256.convert(utf8.encode(jsonEncode([1, profileId, serverScopes, hidden, useGlobalHubs])));
    return HomeSnapshotScope._(Map.unmodifiable(scoped), Set.unmodifiable(clients.keys), 'velo/home-snapshot/v1/$key');
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
/// already removes these rows. Only currently authorized, online client
/// scopes can produce a readable request.
class HomeSnapshotStore {
  const HomeSnapshotStore({this.maxAge = const Duration(hours: 24)});

  // TODO(VELO-P4-02): Tune the injectable warm-start snapshot lifetime.
  final Duration maxAge;

  Future<HomeSnapshot?> read(HomeSnapshotScope scope, {required bool Function() isCurrent}) async {
    final onDeck = <MediaItem>[];
    final hubs = <MediaHub>[];
    await Future.wait(
      scope._clients.entries.map((entry) async {
        try {
          final row = await ApiCache.forBackend(
            entry.value.client.backend,
          ).getIfFresh(ServerId(entry.value.scope), scope.endpoint, maxAge: maxAge);
          if (row == null || row['version'] != 1 || !isCurrent()) return;
          final items = _items(row['onDeck'], entry.key);
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
              serverName: entry.value.client.serverName,
              items: _items(json['items'], entry.key),
            );
          }).toList();
          onDeck.addAll(items);
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
    final serverOrder = scope._clients.keys.toList();
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
            'version': 1,
            'onDeck': [
              for (final item in snapshot.onDeck)
                if (item.serverId == entry.key) _displayJson(item),
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
                        if (item.serverId == entry.key) _displayJson(item),
                    ],
                  },
            ],
          };
          if (!isCurrent()) return;
          await ApiCache.forBackend(
            entry.value.client.backend,
          ).put(ServerId(entry.value.scope), scope.endpoint, payload, isCurrent: isCurrent);
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

  static Map<String, dynamic> _displayJson(MediaItem item) {
    final json = item.toJson()
      ..remove('raw')
      ..remove('mediaVersions')
      ..remove('trailerKey')
      ..remove('backendFolderKey')
      ..remove('roles');
    bool safeArtwork(String value) {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.userInfo.isNotEmpty) return false;
      return !uri.queryParameters.keys.any((key) {
        final normalized = key.toLowerCase();
        return normalized.contains('token') ||
            normalized == 'api_key' ||
            normalized == 'apikey' ||
            normalized == 'password';
      });
    }

    for (final key in json.keys.toList()) {
      final value = json[key];
      if (key.endsWith('Path') && value is String && !safeArtwork(value)) json.remove(key);
      if (key.endsWith('Paths') && value is List) {
        json[key] = value.whereType<String>().where(safeArtwork).toList();
      }
    }
    return json;
  }
}
