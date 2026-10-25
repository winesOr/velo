import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/connection/connection.dart';
import 'package:plezy/media/media_browser_dialect.dart';
import 'package:plezy/profiles/profile_connection.dart';
import 'package:plezy/services/sync_pairing/sync_pairing_protocol.dart';

/// Manual live probe. Set VELO_SYNC_URI to the URI read from the TV QR code:
///
/// `VELO_SYNC_URI='velo-sync://...' flutter test \
///   test/services/sync_pairing/sync_pairing_live_probe_test.dart`
///
/// Set `VELO_SYNC_DIALECT=emby` when probing an Emby server; the default is
/// Jellyfin.
void main() {
  final rawUri = Platform.environment['VELO_SYNC_URI'];
  final dialect = MediaBrowserDialect.fromId(Platform.environment['VELO_SYNC_DIALECT'] ?? 'jellyfin');
  final baseUrl = Platform.environment['VELO_SYNC_BASE_URL'] ?? 'http://127.0.0.1:8096';
  final accessToken = Platform.environment['VELO_SYNC_ACCESS_TOKEN'];
  final userId = Platform.environment['VELO_SYNC_USER_ID'] ?? 'probe-user';
  final serverMachineId = Platform.environment['VELO_SYNC_SERVER_ID'] ?? 'probe-machine';
  final serverName = Platform.environment['VELO_SYNC_SERVER_NAME'] ?? 'Sync probe';
  final replay = Platform.environment['VELO_SYNC_REPLAY'] == '1';
  test('sends an encrypted payload to the live TV receiver', () async {
    final pairing = SyncPairingUri.parse(rawUri!);
    final payload = _payload(
      pairing: pairing,
      dialect: dialect,
      baseUrl: baseUrl,
      accessToken: accessToken,
      userId: userId,
      serverMachineId: serverMachineId,
      serverName: serverName,
    );
    if (replay) {
      await expectLater(
        SyncPairingHttpClient.fetch(pairing: pairing, payload: payload, hostId: pairing.hostId),
        throwsA(isA<SyncPairingHttpException>().having((error) => error.statusCode, 'statusCode', 410)),
      );
      return;
    }
    final response = await SyncPairingHttpClient.fetch(pairing: pairing, payload: payload, hostId: pairing.hostId);
    expect(response.hostId, pairing.hostId);
    expect(jsonDecode(jsonEncode(response.toJson())), containsPair('hostId', pairing.hostId));
  }, skip: rawUri == null ? 'Set VELO_SYNC_URI to probe a live TV receiver' : false);
}

SyncPayload _payload({
  required SyncPairingUri pairing,
  required MediaBrowserDialect dialect,
  required String baseUrl,
  required String? accessToken,
  required String userId,
  required String serverMachineId,
  required String serverName,
}) {
  final connection = JellyfinConnection(
    id: 'probe-connection',
    baseUrl: baseUrl,
    serverName: serverName,
    serverMachineId: serverMachineId,
    userId: userId,
    userName: 'probe',
    accessToken: accessToken ?? 'probe-token',
    deviceId: 'probe-device',
    dialect: dialect,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  );
  return SyncPayload(
    connections: [connection],
    profiles: const [
      SyncableProfile(
        id: 'probe-profile',
        kind: 'local',
        displayName: 'Sync probe',
        connectionIds: ['probe-connection'],
        isDefault: true,
      ),
    ],
    profileConnections: const [
      ProfileConnection(
        profileId: 'probe-profile',
        connectionId: 'probe-connection',
        userToken: 'probe-user-token',
        userIdentifier: 'probe-user',
        isDefault: true,
      ),
    ],
    plexHomeUsers: const {},
    activeProfileId: 'probe-profile',
    hostId: pairing.hostId,
  );
}
