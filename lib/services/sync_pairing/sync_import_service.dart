import 'package:collection/collection.dart';

import '../../connection/connection.dart';
import '../../connection/connection_registry.dart';
import '../../danmaku/danmaku_settings_repository.dart';
import '../../models/plex/plex_home_user.dart';
import '../../profiles/plex_home_service.dart';
import '../../profiles/profile.dart';
import '../../profiles/profile_connection_registry.dart';
import '../../profiles/profile_registry.dart';
import '../../utils/app_logger.dart';
import '../api_cache.dart';
import '../credential_vault.dart';
import '../storage_service.dart';
import 'sync_pairing_protocol.dart';

/// Applies a decrypted sync payload to a fresh TV installation.
///
/// The import is intentionally additive: existing connections/profiles are
/// preserved and only rows from the payload are replaced by id. A wrong or
/// replayed QR therefore cannot silently erase unrelated data.
class SyncImportService {
  SyncImportService({
    required this.connections,
    required this.profiles,
    required this.profileConnections,
    required this.plexHome,
    required this.storage,
    DanmakuSettingsRepository? danmaku,
  }) : danmaku = danmaku ?? DanmakuSettingsRepository();

  final ConnectionRegistry connections;
  final ProfileRegistry profiles;
  final ProfileConnectionRegistry profileConnections;
  final PlexHomeService plexHome;
  final StorageService storage;
  final DanmakuSettingsRepository danmaku;

  Future<void> apply(SyncPayload payload) async {
    if (payload.connections.isEmpty) {
      throw const FormatException('No media server connections were included');
    }
    for (final connection in payload.connections) {
      await connections.upsert(connection);
    }

    for (final profile in payload.profiles) {
      if (!profile.isPlexHome) {
        await profiles.upsert(profile.toProfile());
      }
    }

    for (final entry in payload.plexHomeUsers.entries) {
      await storage.savePlexHomeUsersCache(entry.key, entry.value.map((user) => user.toJson()).toList());
    }
    if (payload.plexHomeUsers.isNotEmpty) await plexHome.reloadFromStorage();

    final connectionIds = payload.connections.map((connection) => connection.id).toSet();
    for (final pc in payload.profileConnections) {
      if (!connectionIds.contains(pc.connectionId)) continue;
      await profileConnections.upsert(pc, makeDefault: pc.isDefault);
    }

    final activeId = payload.activeProfileId;
    final importedProfileIds = payload.profiles.map((profile) => profile.id).toSet();
    if (activeId != null && activeId.isNotEmpty && importedProfileIds.contains(activeId)) {
      await storage.setActiveProfileId(activeId);
    } else {
      final defaultProfile = payload.profiles.where((profile) => profile.isDefault).firstOrNull;
      if (defaultProfile != null) {
        await storage.setActiveProfileId(defaultProfile.id);
      }
    }

    final importedDanmaku = payload.danmaku;
    if (importedDanmaku != null && !importedDanmaku.isEmpty) {
      final current = await danmaku.load();
      await danmaku.save(importedDanmaku.mergeInto(current));
    }

    // Cached API rows are scoped to the source installation's identity and
    // must not leak across devices.
    await ApiCache.clearRegisteredVolatile();
    CredentialVault.invalidateCache();
    appLogger.i(
      'SyncImport: imported ${payload.connections.length} connection(s), '
      '${payload.profiles.length} profile(s), '
      '${importedDanmaku?.sources.length ?? 0} danmaku source(s)',
    );
  }

  /// Builds the phone-side payload from the active installation.
  static Future<SyncPayload> capture({
    required ConnectionRegistry connections,
    required ProfileRegistry profiles,
    required ProfileConnectionRegistry profileConnections,
    required PlexHomeService plexHome,
    required StorageService storage,
    required DanmakuSettingsRepository danmaku,
    required String hostId,
  }) async {
    await plexHome.hydrate();
    final allConnections = await connections.list();
    if (allConnections.isEmpty) {
      throw const FormatException('Sign in to at least one media server first');
    }
    final localProfiles = await profiles.list();
    final allProfileConnections = await profileConnections.listAll();
    final activeId = storage.getActiveProfileId();
    final selected = <String, Profile>{for (final profile in localProfiles) profile.id: profile};

    // Include only profiles that can actually resolve on the TV. Virtual Plex
    // Home profiles are rebuilt from the cached user list after import.
    final connectedProfileIds = <String>{};
    for (final pc in allProfileConnections) {
      final id = pc.profileId;
      if (selected.containsKey(id)) connectedProfileIds.add(id);
      if (id == activeId) connectedProfileIds.add(id);
    }
    if (activeId != null && activeId.startsWith('plex-home-')) connectedProfileIds.add(activeId);

    final syncProfiles = <SyncableProfile>[];
    for (final id in connectedProfileIds) {
      final profile = selected[id];
      if (profile != null) {
        final pcs = allProfileConnections.where((pc) => pc.profileId == id).toList();
        syncProfiles.add(
          SyncableProfile.fromProfile(
            profile: profile,
            connectionIds: [for (final pc in pcs) pc.connectionId],
            isDefault: pcs.any((pc) => pc.isDefault),
          ),
        );
        continue;
      }
      final parsed = parsePlexHomeProfileId(id);
      if (parsed == null) continue;
      final users = plexHome.current[parsed.accountConnectionId] ?? const [];
      final user = users.where((candidate) => candidate.uuid == parsed.homeUserUuid).firstOrNull;
      if (user == null) continue;
      syncProfiles.add(
        SyncableProfile.fromProfile(
          profile: Profile.virtualPlexHome(connectionId: parsed.accountConnectionId, homeUser: user),
          connectionIds: [parsed.accountConnectionId],
          isDefault: true,
        ),
      );
    }

    // If the phone has no explicit profile rows yet, still send the account
    // connections and let the TV create the natural profile from its cache.
    if (syncProfiles.isEmpty) {
      final now = DateTime.now();
      final plexConnections = allConnections.whereType<PlexAccountConnection>().toList();
      final adminCandidate = plexConnections
          .map((connection) {
            final users = plexHome.current[connection.id] ?? const <PlexHomeUser>[];
            final admin = users.where((user) => user.admin).firstOrNull;
            return admin == null ? null : (connection: connection, user: admin);
          })
          .nonNulls
          .firstOrNull;
      if (adminCandidate != null) {
        syncProfiles.add(
          SyncableProfile.fromProfile(
            profile: Profile.virtualPlexHome(connectionId: adminCandidate.connection.id, homeUser: adminCandidate.user),
            connectionIds: [adminCandidate.connection.id],
            isDefault: true,
          ),
        );
      } else {
        final local = Profile.local(
          id: 'local-sync-${now.millisecondsSinceEpoch}',
          displayName: allConnections.first.displayLabel,
          createdAt: now,
        );
        syncProfiles.add(
          SyncableProfile.fromProfile(
            profile: local,
            connectionIds: [for (final connection in allConnections) connection.id],
            isDefault: true,
          ),
        );
      }
    }

    final allowedConnections = <String>{for (final profile in syncProfiles) ...profile.connectionIds};
    if (allowedConnections.isEmpty) {
      // A single local profile is a valid destination even before its first
      // connection is borrowed. Include the account connections so the TV can
      // still recreate a useful identity instead of failing the whole handoff.
      allowedConnections.addAll(allConnections.map((connection) => connection.id));
    }
    if (allowedConnections.isEmpty) {
      throw const FormatException('No active profile is available to sync');
    }
    final filteredConnections = allConnections
        .where((connection) => allowedConnections.contains(connection.id))
        .toList(growable: false);
    final filteredProfileConnections = allProfileConnections
        .where(
          (pc) =>
              allowedConnections.contains(pc.connectionId) &&
              (syncProfiles.any((profile) => profile.id == pc.profileId) ||
                  (pc.profileId.startsWith('plex-home-') && pc.profileId == activeId)),
        )
        .toList(growable: false);
    final homes = <String, List<PlexHomeUser>>{
      for (final connection in filteredConnections)
        if (plexHome.current[connection.id] != null) connection.id: plexHome.current[connection.id]!,
    };

    return SyncPayload(
      connections: filteredConnections,
      profiles: syncProfiles,
      profileConnections: filteredProfileConnections,
      plexHomeUsers: homes,
      activeProfileId: activeId,
      hostId: hostId,
      danmaku: SyncableDanmaku.fromSettings(await danmaku.load()),
    );
  }
}
