import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/connection/connection.dart';
import 'package:plezy/danmaku/danmaku_settings.dart';
import 'package:plezy/danmaku/danmaku_source.dart';
import 'package:plezy/media/media_browser_dialect.dart';
import 'package:plezy/profiles/profile_connection.dart';
import 'package:plezy/services/sync_pairing/sync_pairing_protocol.dart';
import 'package:plezy/services/sync_pairing/sync_pairing_session.dart';

void main() {
  group('SyncPairingUri', () {
    test('round-trips a TV QR payload', () {
      final publicKey = base64UrlEncode(List<int>.generate(32, (index) => index)).replaceAll('=', '');
      final original = SyncPairingUri(
        host: '192.168.2.43',
        port: 48731,
        publicKey: publicKey,
        token: 'one-time-token',
        hostId: 'tv-host',
      );

      final decoded = SyncPairingUri.parse(original.encode());

      expect(decoded.host, original.host);
      expect(decoded.port, original.port);
      expect(decoded.publicKey, original.publicKey);
      expect(decoded.token, original.token);
      expect(decoded.hostId, original.hostId);
    });

    test('rejects a non-Velo or malformed public key', () {
      expect(() => SyncPairingUri.parse('https://example.com'), throwsFormatException);
      final malformed = SyncPairingUri(
        host: '192.168.2.43',
        port: 48731,
        publicKey: base64UrlEncode([1, 2, 3]),
        token: 'token',
        hostId: 'host',
      );
      expect(() => SyncPairingUri.parse(malformed.encode()), throwsFormatException);
    });
  });

  group('SyncPairingSession', () {
    test('accepts the token exactly once', () {
      final session = SyncPairingSession(
        token: 'correct-token',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      );

      expect(session.acceptToken('wrong-token'), isFalse);
      expect(session.failedAttempts, 1);
      expect(session.acceptToken('correct-token'), isTrue);
      expect(session.isClaimed, isTrue);
      expect(session.acceptToken('correct-token'), isFalse);
    });

    test('expires and locks out after repeated failures', () {
      final expired = SyncPairingSession(
        token: 'token',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(expired.acceptToken('token'), isFalse);

      final limited = SyncPairingSession(
        token: 'token',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        maxFailedAttempts: 2,
      );
      expect(limited.acceptToken('bad'), isFalse);
      expect(limited.acceptToken('bad'), isFalse);
      expect(limited.isExhausted, isTrue);
      expect(limited.acceptToken('token'), isFalse);
    });
  });

  group('SyncPayload', () {
    test('round-trips the Emby dialect through encrypted JSON', () async {
      final source = _payload(dialect: MediaBrowserDialect.emby);
      final decoded = SyncPayload.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(source.toJson())) as Map));

      expect(decoded.connections, hasLength(1));
      final connection = decoded.connections.single as JellyfinConnection;
      expect(connection.dialect, MediaBrowserDialect.emby);
      expect(connection.kind.id, 'emby');
    });

    test('round-trips danmaku sources and their official credentials', () {
      final source = _payload();
      final decoded = SyncPayload.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(source.toJson())) as Map));

      expect(decoded.danmaku!.sources.map((source) => source.id), ['gateway', 'official']);
      expect(decoded.danmaku!.sources.first.baseUrl, 'https://danmaku.example/private/path');
      expect(decoded.danmaku!.credentials['official']!.appId, 'own-app-id');
      expect(decoded.danmaku!.credentials['official']!.appSecret, 'own-app-secret');
    });

    test('payloads from older senders remain valid without danmaku data', () {
      final json = _payload().toJson()..remove('danmaku');
      final decoded = SyncPayload.fromJson(Map<String, dynamic>.from(json));

      expect(decoded.danmaku, isNull);
    });
  });

  group('SyncableDanmaku', () {
    test('captures sources and only valid credentials for official endpoints', () {
      const settings = DanmakuSettings(
        sources: [
          DanmakuSource(id: 'gateway', name: 'Gateway', baseUrl: 'https://gateway.example/private'),
          DanmakuSource(id: 'official', name: 'Official', baseUrl: 'https://api.dandanplay.net'),
        ],
        credentials: {
          'gateway': DanmakuCredentials(appId: 'ignored-id', appSecret: 'ignored-secret'),
          'official': DanmakuCredentials(appId: 'own-id', appSecret: 'own-secret'),
        },
      );

      final captured = SyncableDanmaku.fromSettings(settings);

      expect(captured.sources.map((source) => source.id), ['gateway', 'official']);
      expect(captured.credentials.keys, ['official']);
    });

    test('merges additively and clears credentials when an official URL changes', () {
      const current = DanmakuSettings(
        sources: [
          DanmakuSource(id: 'official', name: 'Old', baseUrl: 'https://api.dandanplay.net'),
          DanmakuSource(id: 'tv-only', name: 'TV only', baseUrl: 'https://tv.example'),
        ],
        credentials: {
          'official': DanmakuCredentials(appId: 'old-id', appSecret: 'old-secret'),
          'tv-only': DanmakuCredentials(appId: 'tv-id', appSecret: 'tv-secret'),
        },
        memories: {'key': DanmakuMatchMemory(sourceId: 'official', animeId: '4', animeTitle: 'Title')},
      );
      const imported = SyncableDanmaku(
        sources: [
          DanmakuSource(id: 'official', name: 'Gateway', baseUrl: 'https://gateway.example'),
          DanmakuSource(id: 'phone-only', name: 'Phone only', baseUrl: 'https://phone.example'),
        ],
        credentials: {'official': DanmakuCredentials(appId: 'new-id', appSecret: 'new-secret')},
      );

      final merged = imported.mergeInto(current);

      expect(merged.sources.map((source) => source.id), ['official', 'tv-only', 'phone-only']);
      expect(merged.sources.first.baseUrl, 'https://gateway.example');
      expect(merged.credentials.containsKey('official'), isFalse);
      expect(merged.credentials['tv-only']!.appId, 'tv-id');
      expect(merged.memories, isEmpty);
    });
  });

  group('SyncPairingCrypto', () {
    test('seals and opens with keys derived from both X25519 sides', () async {
      final tv = await SyncPairingCrypto.newKeyPair();
      final phone = await SyncPairingCrypto.newKeyPair();
      final tvPublic = await SyncPairingCrypto.publicKeyBase64(tv);
      final phonePublic = await SyncPairingCrypto.publicKeyBase64(phone);
      final payload = _payload();

      final phoneKey = await SyncPairingCrypto.deriveKey(
        localKeyPair: phone,
        remotePublicKey: tvPublic,
        token: 'token',
        hostId: 'tv-host',
        direction: 'phone-to-tv',
      );
      final envelope = await SyncPairingCrypto.seal(
        key: phoneKey,
        hostId: 'tv-host',
        publicKey: phonePublic,
        payload: payload,
      );
      final tvKey = await SyncPairingCrypto.deriveKey(
        localKeyPair: tv,
        remotePublicKey: envelope.publicKey,
        token: 'token',
        hostId: 'tv-host',
        direction: 'phone-to-tv',
      );

      final opened = await SyncPairingCrypto.open(key: tvKey, envelope: envelope);
      expect(opened.hostId, payload.hostId);
      expect(opened.connections.single.id, 'jellyfin-1');
      expect(opened.profileConnections.single.userToken, 'secret-token');
    });

    test('does not open with the opposite direction or wrong token', () async {
      final tv = await SyncPairingCrypto.newKeyPair();
      final phone = await SyncPairingCrypto.newKeyPair();
      final tvPublic = await SyncPairingCrypto.publicKeyBase64(tv);
      final phonePublic = await SyncPairingCrypto.publicKeyBase64(phone);
      final key = await SyncPairingCrypto.deriveKey(
        localKeyPair: phone,
        remotePublicKey: tvPublic,
        token: 'token',
        hostId: 'tv-host',
        direction: 'phone-to-tv',
      );
      final envelope = await SyncPairingCrypto.seal(
        key: key,
        hostId: 'tv-host',
        publicKey: phonePublic,
        payload: _payload(),
      );

      final wrongDirection = await SyncPairingCrypto.deriveKey(
        localKeyPair: tv,
        remotePublicKey: phonePublic,
        token: 'token',
        hostId: 'tv-host',
        direction: 'tv-to-phone',
      );
      final wrongToken = await SyncPairingCrypto.deriveKey(
        localKeyPair: tv,
        remotePublicKey: phonePublic,
        token: 'other-token',
        hostId: 'tv-host',
        direction: 'phone-to-tv',
      );

      await expectLater(SyncPairingCrypto.open(key: wrongDirection, envelope: envelope), throwsA(anything));
      await expectLater(SyncPairingCrypto.open(key: wrongToken, envelope: envelope), throwsA(anything));
    });
  });
}

SyncPayload _payload({MediaBrowserDialect dialect = MediaBrowserDialect.jellyfin}) {
  final connection = JellyfinConnection(
    id: 'jellyfin-1',
    baseUrl: 'http://192.168.2.10:8096',
    serverName: 'Home',
    serverMachineId: 'machine-1',
    userId: 'user-1',
    userName: 'wines',
    accessToken: 'server-access-token',
    deviceId: 'device-1',
    dialect: dialect,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  );
  return SyncPayload(
    connections: [connection],
    profiles: const [
      SyncableProfile(
        id: 'profile-1',
        kind: 'local',
        displayName: 'Home',
        connectionIds: ['jellyfin-1'],
        isDefault: true,
      ),
    ],
    profileConnections: const [
      ProfileConnection(
        profileId: 'profile-1',
        connectionId: 'jellyfin-1',
        userToken: 'secret-token',
        userIdentifier: 'user-1',
        isDefault: true,
      ),
    ],
    plexHomeUsers: const {},
    activeProfileId: 'profile-1',
    hostId: 'tv-host',
    danmaku: const SyncableDanmaku(
      sources: [
        DanmakuSource(id: 'gateway', name: 'Gateway', baseUrl: 'https://danmaku.example/private/path'),
        DanmakuSource(id: 'official', name: 'Official', baseUrl: 'https://api.dandanplay.net'),
      ],
      credentials: {'official': DanmakuCredentials(appId: 'own-app-id', appSecret: 'own-app-secret')},
    ),
  );
}
