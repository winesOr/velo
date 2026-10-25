import '../../connection/connection_registry.dart';
import '../../danmaku/danmaku_settings_repository.dart';
import '../../profiles/plex_home_service.dart';
import '../../profiles/profile_connection_registry.dart';
import '../../profiles/profile_registry.dart';
import '../storage_service.dart';
import 'sync_import_service.dart';
import 'sync_pairing_protocol.dart';

/// Phone-side entry point: read the QR, capture only the active identity, and
/// hand it to the TV over the one-shot encrypted LAN channel.
class SyncSender {
  SyncSender({
    required this.connections,
    required this.profiles,
    required this.profileConnections,
    required this.plexHome,
    required this.storage,
    required this.danmaku,
  });

  final ConnectionRegistry connections;
  final ProfileRegistry profiles;
  final ProfileConnectionRegistry profileConnections;
  final PlexHomeService plexHome;
  final StorageService storage;
  final DanmakuSettingsRepository danmaku;

  Future<SyncPayload> send(SyncPairingUri pairing) async {
    final payload = await SyncImportService.capture(
      connections: connections,
      profiles: profiles,
      profileConnections: profileConnections,
      plexHome: plexHome,
      storage: storage,
      danmaku: danmaku,
      hostId: pairing.hostId,
    );
    // The receiver's QR host is the certificate-pinned LAN address. The TV
    // creates its own hostId, so the sender uses the payload id as the HKDF
    // salt and the receiver validates it against the QR's host.
    await SyncPairingHttpClient.fetch(pairing: pairing, payload: payload, hostId: payload.hostId);
    return payload;
  }
}
