import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';

import '../../connection/connection.dart';
import '../../danmaku/danmaku_settings.dart';
import '../../danmaku/danmaku_source.dart';
import '../../media/media_browser_dialect.dart';
import '../../models/plex/plex_home_user.dart';
import '../../profiles/profile.dart';
import '../../profiles/profile_connection.dart';

const String syncPairingScheme = 'velo-sync';
const int syncPairingVersion = 1;
const int syncPairingDefaultPort = 48731;

/// Stable algorithm identifier included in the QR and every encrypted frame.
const String syncPairingAlgorithm = 'A256GCM-X25519-HKDF-SHA256';

/// QR payload. The token and the TV's ephemeral X25519 key authenticate the
/// local handoff; the QR itself never contains a media-server credential.
class SyncPairingUri {
  const SyncPairingUri({
    required this.host,
    required this.port,
    required this.publicKey,
    required this.token,
    required this.hostId,
  });

  final String host;
  final int port;
  final String publicKey;
  final String token;
  final String hostId;

  Uri toUri() => Uri(
    scheme: syncPairingScheme,
    host: host,
    port: port,
    path: '/$syncPairingVersion',
    queryParameters: {'key': publicKey, 'token': token, 'alg': syncPairingAlgorithm, 'host': hostId},
  );

  String encode() => toUri().toString();

  static SyncPairingUri parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != syncPairingScheme) {
      throw const FormatException('Not a Velo sync QR code');
    }
    final version = uri.pathSegments.length == 1 ? int.tryParse(uri.pathSegments.single) : null;
    if (version != syncPairingVersion) {
      throw const FormatException('Unsupported Velo sync protocol version');
    }
    final host = uri.host;
    final port = uri.hasPort ? uri.port : syncPairingDefaultPort;
    final publicKey = uri.queryParameters['key'] ?? '';
    final token = uri.queryParameters['token'] ?? '';
    final algorithm = uri.queryParameters['alg'] ?? '';
    final hostId = uri.queryParameters['host'] ?? '';
    if (host.isEmpty || port <= 0 || port > 65535 || token.isEmpty || publicKey.isEmpty || hostId.isEmpty) {
      throw const FormatException('Incomplete Velo sync QR code');
    }
    if (algorithm != syncPairingAlgorithm) {
      throw const FormatException('Unsupported Velo sync encryption');
    }
    final publicKeyBytes = base64Url.decode(base64Url.normalize(publicKey));
    if (publicKeyBytes.length != 32) {
      throw const FormatException('Invalid Velo sync public key');
    }
    return SyncPairingUri(host: host, port: port, publicKey: publicKey, token: token, hostId: hostId);
  }
}

/// A self-contained media connection and its selected profile identity.
///
/// The payload deliberately contains no download history, playback history or
/// arbitrary preferences. [profile] is either a local profile or a virtual
/// Plex Home profile; local PINs are preserved.
class SyncableProfile {
  const SyncableProfile({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.connectionIds,
    this.avatarThumbUrl,
    this.pinHash,
    this.parentConnectionId,
    this.plexHomeUserUuid,
    this.plexRestricted = false,
    this.plexAdmin = false,
    this.plexProtected = false,
    this.isDefault = false,
  });

  final String id;
  final String kind;
  final String displayName;
  final List<String> connectionIds;
  final String? avatarThumbUrl;
  final String? pinHash;
  final String? parentConnectionId;
  final String? plexHomeUserUuid;
  final bool plexRestricted;
  final bool plexAdmin;
  final bool plexProtected;
  final bool isDefault;

  bool get isPlexHome => kind == ProfileKind.plexHome.id;

  factory SyncableProfile.fromProfile({
    required Profile profile,
    required List<String> connectionIds,
    required bool isDefault,
  }) {
    return SyncableProfile(
      id: profile.id,
      kind: profile.kind.id,
      displayName: profile.displayName,
      connectionIds: List.unmodifiable(connectionIds),
      avatarThumbUrl: profile.avatarThumbUrl,
      pinHash: profile.pinHash,
      parentConnectionId: profile.parentConnectionId,
      plexHomeUserUuid: profile.plexHomeUserUuid,
      plexRestricted: profile.plexRestricted,
      plexAdmin: profile.plexAdmin,
      plexProtected: profile.plexProtected,
      isDefault: isDefault,
    );
  }

  Profile toProfile() {
    if (kind == ProfileKind.local.id) {
      return Profile.local(
        id: id,
        displayName: displayName,
        avatarThumbUrl: avatarThumbUrl,
        pinHash: pinHash,
        createdAt: DateTime.now(),
      );
    }
    if (kind == ProfileKind.plexHome.id) {
      return Profile.plexHome(
        id: id,
        displayName: displayName,
        avatarThumbUrl: avatarThumbUrl,
        parentConnectionId: parentConnectionId,
        plexHomeUserUuid: plexHomeUserUuid,
        plexRestricted: plexRestricted,
        plexAdmin: plexAdmin,
        plexProtected: plexProtected,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    throw FormatException('Unknown profile kind: $kind');
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'displayName': displayName,
    'connectionIds': connectionIds,
    'avatarThumbUrl': avatarThumbUrl,
    'pinHash': pinHash,
    'parentConnectionId': parentConnectionId,
    'plexHomeUserUuid': plexHomeUserUuid,
    'plexRestricted': plexRestricted,
    'plexAdmin': plexAdmin,
    'plexProtected': plexProtected,
    'isDefault': isDefault,
  };

  factory SyncableProfile.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String? ?? '';
    if (kind != ProfileKind.local.id && kind != ProfileKind.plexHome.id) {
      throw FormatException('Unknown profile kind: $kind');
    }
    return SyncableProfile(
      id: json['id'] as String? ?? '',
      kind: kind,
      displayName: json['displayName'] as String? ?? '',
      connectionIds: (json['connectionIds'] as List?)?.whereType<String>().toList(growable: false) ?? const [],
      avatarThumbUrl: json['avatarThumbUrl'] as String?,
      pinHash: json['pinHash'] as String?,
      parentConnectionId: json['parentConnectionId'] as String?,
      plexHomeUserUuid: json['plexHomeUserUuid'] as String?,
      plexRestricted: json['plexRestricted'] as bool? ?? false,
      plexAdmin: json['plexAdmin'] as bool? ?? false,
      plexProtected: json['plexProtected'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

/// User-owned danmaku source configuration carried over the encrypted pairing
/// channel. Presentation preferences and item match memories stay device-local.
class SyncableDanmaku {
  const SyncableDanmaku({required this.sources, required this.credentials});

  final List<DanmakuSource> sources;
  final Map<String, DanmakuCredentials> credentials;

  bool get isEmpty => sources.isEmpty;

  factory SyncableDanmaku.fromSettings(DanmakuSettings settings) {
    final sourceIds = {for (final source in settings.sources) source.id};
    return SyncableDanmaku(
      sources: List.unmodifiable(settings.sources),
      credentials: Map.unmodifiable({
        for (final entry in settings.credentials.entries)
          if (sourceIds.contains(entry.key) && entry.value.isValid && _isOfficialSource(settings, entry.key))
            entry.key: entry.value,
      }),
    );
  }

  /// Additive merge: imported source ids replace their existing rows, new ids
  /// are appended in phone order, and unrelated TV sources remain untouched.
  DanmakuSettings mergeInto(DanmakuSettings current) {
    final mergedSources = [...current.sources];
    final mergedCredentials = {...current.credentials};
    final importedCredentials = credentials;
    var memories = current.memories;
    for (final source in sources) {
      final index = mergedSources.indexWhere((candidate) => candidate.id == source.id);
      final previous = index < 0 ? null : mergedSources[index];
      if (index < 0) {
        mergedSources.add(source);
      } else {
        mergedSources[index] = source;
      }
      if (previous != null && previous.baseUrl != source.baseUrl) {
        memories = Map.fromEntries(memories.entries.where((entry) => entry.value.sourceId != source.id));
      }
      final sourceCredentials = importedCredentials[source.id];
      if (sourceCredentials != null && sourceCredentials.isValid && DanmakuEndpoint(source.baseUrl).isOfficial) {
        mergedCredentials[source.id] = sourceCredentials;
      } else if (previous == null ||
          previous.baseUrl != source.baseUrl ||
          !DanmakuEndpoint(source.baseUrl).isOfficial) {
        mergedCredentials.remove(source.id);
      }
    }
    return current.copyWith(sources: mergedSources, credentials: mergedCredentials, memories: memories);
  }

  Map<String, Object?> toJson() => {
    'sources': [for (final source in sources) source.toJson()],
    'credentials': {for (final entry in credentials.entries) entry.key: entry.value.toJson()},
  };

  factory SyncableDanmaku.fromJson(Map<String, dynamic> json) {
    final sources = <DanmakuSource>[];
    for (final raw in (json['sources'] as List?) ?? const []) {
      if (raw is! Map) throw const FormatException('Invalid danmaku source');
      sources.add(DanmakuSource.fromJson(Map<String, dynamic>.from(raw)));
    }
    if (sources.map((source) => source.id).toSet().length != sources.length) {
      throw const FormatException('Duplicate danmaku source');
    }
    final credentials = <String, DanmakuCredentials>{};
    final rawCredentials = json['credentials'];
    if (rawCredentials is Map) {
      for (final entry in rawCredentials.entries) {
        if (entry.value is! Map) throw const FormatException('Invalid danmaku credentials');
        credentials[entry.key.toString()] = DanmakuCredentials.fromJson(Map<String, dynamic>.from(entry.value as Map));
      }
    }
    return SyncableDanmaku(sources: List.unmodifiable(sources), credentials: Map.unmodifiable(credentials));
  }

  static bool _isOfficialSource(DanmakuSettings settings, String sourceId) {
    final source = settings.sources.where((candidate) => candidate.id == sourceId).firstOrNull;
    if (source == null) return false;
    return DanmakuEndpoint(source.baseUrl).isOfficial;
  }
}

class SyncPayload {
  const SyncPayload({
    required this.connections,
    required this.profiles,
    required this.profileConnections,
    required this.plexHomeUsers,
    required this.activeProfileId,
    required this.hostId,
    this.danmaku,
  });

  final List<Connection> connections;
  final List<SyncableProfile> profiles;
  final List<ProfileConnection> profileConnections;
  final Map<String, List<PlexHomeUser>> plexHomeUsers;
  final String? activeProfileId;
  final String hostId;
  final SyncableDanmaku? danmaku;

  /// Profile ids that exist only as virtual Plex Home rows on the sender.
  /// The TV has no local row for these, but needs the ids to bind the cached
  /// Home users and restore the sender's selected profile.
  List<String> get plexHomeProfileIds => [
    for (final profile in profiles)
      if (profile.isPlexHome) profile.id,
  ];

  Map<String, Object?> toJson() => {
    'format': 'velo-sync-connections',
    'version': syncPairingVersion,
    'hostId': hostId,
    'connections': [
      for (final connection in connections)
        {
          'id': connection.id,
          'kind': connection.kind.id,
          'displayName': connection.displayName,
          'config': connection.toConfigJson(),
        },
    ],
    'profiles': profiles.map((profile) => profile.toJson()).toList(),
    'profileConnections': [
      for (final pc in profileConnections)
        {
          'profileId': pc.profileId,
          'connectionId': pc.connectionId,
          'userToken': pc.userToken,
          'userIdentifier': pc.userIdentifier,
          'isDefault': pc.isDefault,
          'tokenAcquiredAt': pc.tokenAcquiredAt?.toUtc().toIso8601String(),
          'lastUsedAt': pc.lastUsedAt?.toUtc().toIso8601String(),
        },
    ],
    'plexHomeUsers': {
      for (final entry in plexHomeUsers.entries) entry.key: [for (final user in entry.value) user.toJson()],
    },
    'plexHomeProfileIds': plexHomeProfileIds,
    'activeProfileId': activeProfileId,
    'danmaku': danmaku?.toJson(),
  };

  factory SyncPayload.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'velo-sync-connections') {
      throw const FormatException('Unsupported Velo sync payload');
    }
    if (json['version'] != syncPairingVersion) {
      throw const FormatException('Unsupported Velo sync payload version');
    }
    final connections = <Connection>[];
    for (final raw in (json['connections'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'] as String? ?? '';
      final kind = map['kind'] as String? ?? '';
      final config = map['config'];
      if (id.isEmpty || config is! Map) continue;
      final configMap = Map<String, dynamic>.from(config);
      final createdAt = DateTime.now();
      connections.add(switch (kind) {
        'plex' => PlexAccountConnection.fromConfigJson(
          id: id,
          json: configMap,
          createdAt: createdAt,
          lastAuthenticatedAt: createdAt,
        ),
        'jellyfin' => JellyfinConnection.fromConfigJson(
          id: id,
          json: configMap,
          createdAt: createdAt,
          lastAuthenticatedAt: createdAt,
        ),
        'emby' => JellyfinConnection.fromConfigJson(
          id: id,
          json: configMap,
          dialect: MediaBrowserDialect.emby,
          createdAt: createdAt,
          lastAuthenticatedAt: createdAt,
        ),
        _ => throw FormatException('Unknown connection kind: $kind'),
      });
    }
    final profiles = <SyncableProfile>[];
    for (final raw in (json['profiles'] as List?) ?? const []) {
      if (raw is Map) profiles.add(SyncableProfile.fromJson(Map<String, dynamic>.from(raw)));
    }
    final profileConnections = <ProfileConnection>[];
    for (final raw in (json['profileConnections'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      profileConnections.add(
        ProfileConnection(
          profileId: map['profileId'] as String? ?? '',
          connectionId: map['connectionId'] as String? ?? '',
          userToken: map['userToken'] as String?,
          userIdentifier: map['userIdentifier'] as String? ?? '',
          isDefault: map['isDefault'] as bool? ?? false,
          tokenAcquiredAt: DateTime.tryParse(map['tokenAcquiredAt'] as String? ?? ''),
          lastUsedAt: DateTime.tryParse(map['lastUsedAt'] as String? ?? ''),
        ),
      );
    }
    final plexHomeUsers = <String, List<PlexHomeUser>>{};
    final rawHomes = json['plexHomeUsers'];
    if (rawHomes is Map) {
      for (final entry in rawHomes.entries) {
        final users = (entry.value as List?)?.whereType<Map>().map(
          (u) => PlexHomeUser.fromJson(Map<String, dynamic>.from(u)),
        );
        if (users != null) plexHomeUsers[entry.key.toString()] = users.toList(growable: false);
      }
    }
    final rawPlexProfileIds = json['plexHomeProfileIds'];
    final plexProfileIds = rawPlexProfileIds is List
        ? rawPlexProfileIds.whereType<String>().toList(growable: false)
        : const <String>[];
    for (final id in plexProfileIds) {
      final parsed = parsePlexHomeProfileId(id);
      if (parsed == null || profiles.any((profile) => profile.id == id)) continue;
      final users = plexHomeUsers[parsed.accountConnectionId];
      final user = users?.where((candidate) => candidate.uuid == parsed.homeUserUuid).firstOrNull;
      if (user == null) continue;
      profiles.add(
        SyncableProfile.fromProfile(
          profile: Profile.virtualPlexHome(connectionId: parsed.accountConnectionId, homeUser: user),
          connectionIds: [parsed.accountConnectionId],
          isDefault: true,
        ),
      );
    }
    final rawDanmaku = json['danmaku'];
    final danmaku = rawDanmaku is Map ? SyncableDanmaku.fromJson(Map<String, dynamic>.from(rawDanmaku)) : null;
    return SyncPayload(
      connections: List.unmodifiable(connections),
      profiles: List.unmodifiable(profiles),
      profileConnections: List.unmodifiable(profileConnections),
      plexHomeUsers: Map.unmodifiable(plexHomeUsers),
      activeProfileId: json['activeProfileId'] as String?,
      hostId: json['hostId'] as String? ?? '',
      danmaku: danmaku,
    );
  }
}

/// Encrypted frame sent from the signed-in phone to the TV.
class SyncEnvelope {
  const SyncEnvelope({
    required this.hostId,
    required this.publicKey,
    required this.sentAt,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  final String hostId;
  final String publicKey;
  final String sentAt;
  final String nonce;
  final String ciphertext;
  final String mac;

  Map<String, Object?> toJson() => {
    'version': syncPairingVersion,
    'algorithm': syncPairingAlgorithm,
    'hostId': hostId,
    'publicKey': publicKey,
    'sentAt': sentAt,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
  };

  factory SyncEnvelope.fromJson(Map<String, dynamic> json) {
    if (json['version'] != syncPairingVersion || json['algorithm'] != syncPairingAlgorithm) {
      throw const FormatException('Unsupported Velo sync envelope');
    }
    final hostId = json['hostId'] as String? ?? '';
    final publicKey = json['publicKey'] as String? ?? '';
    final sentAt = json['sentAt'] as String? ?? '';
    final nonce = json['nonce'] as String? ?? '';
    final ciphertext = json['ciphertext'] as String? ?? '';
    final mac = json['mac'] as String? ?? '';
    if (hostId.isEmpty || publicKey.isEmpty || nonce.isEmpty || ciphertext.isEmpty || mac.isEmpty) {
      throw const FormatException('Incomplete Velo sync envelope');
    }
    final publicKeyBytes = base64Url.decode(base64Url.normalize(publicKey));
    if (publicKeyBytes.length != 32) {
      throw const FormatException('Invalid Velo sync envelope public key');
    }
    return SyncEnvelope(
      hostId: hostId,
      publicKey: publicKey,
      sentAt: sentAt,
      nonce: nonce,
      ciphertext: ciphertext,
      mac: mac,
    );
  }
}

class SyncPairingCrypto {
  SyncPairingCrypto._();

  static final X25519 _x25519 = X25519();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);
  static final AesGcm _aes = AesGcm.with256bits();

  static Future<KeyPair> newKeyPair() => _x25519.newKeyPair();

  static Future<String> publicKeyBase64(KeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    if (publicKey is! SimplePublicKey) throw StateError('Expected an X25519 public key');
    return base64UrlEncode(publicKey.bytes).replaceAll('=', '');
  }

  static SimplePublicKey publicKeyFromBase64(String encoded) {
    final bytes = base64Url.decode(base64Url.normalize(encoded));
    if (bytes.length != 32) throw const FormatException('Invalid X25519 public key');
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  /// Derives a direction-specific AES key from X25519 and the one-shot token.
  ///
  /// The token is mixed into HKDF so knowing only the QR public key is not
  /// enough to decrypt the payload. [direction] prevents request and response
  /// ciphertexts from sharing a key.
  static Future<SecretKey> deriveKey({
    required KeyPair localKeyPair,
    required String remotePublicKey,
    required String token,
    required String hostId,
    required String direction,
  }) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: publicKeyFromBase64(remotePublicKey),
    );
    final sharedBytes = await shared.extractBytes();
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(sharedBytes),
      nonce: utf8.encode(token),
      info: utf8.encode('velo-sync-v1:$hostId:$direction'),
    );
    return SecretKey(await key.extractBytes());
  }

  static Future<SyncEnvelope> seal({
    required SecretKey key,
    required String hostId,
    required String publicKey,
    required SyncPayload payload,
  }) async {
    final box = await _aes.encrypt(utf8.encode(jsonEncode(payload.toJson())), secretKey: key);
    return SyncEnvelope(
      hostId: hostId,
      publicKey: publicKey,
      sentAt: DateTime.now().toUtc().toIso8601String(),
      nonce: base64UrlEncode(box.nonce),
      ciphertext: base64UrlEncode(box.cipherText),
      mac: base64UrlEncode(box.mac.bytes),
    );
  }

  static Future<SyncPayload> open({required SecretKey key, required SyncEnvelope envelope}) async {
    final box = SecretBox(
      base64Url.decode(envelope.ciphertext),
      nonce: base64Url.decode(envelope.nonce),
      mac: Mac(base64Url.decode(envelope.mac)),
    );
    final clear = await _aes.decrypt(box, secretKey: key);
    final json = jsonDecode(utf8.decode(clear));
    if (json is! Map) throw const FormatException('Invalid Velo sync payload');
    return SyncPayload.fromJson(Map<String, dynamic>.from(json));
  }
}

Uint8List utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));

/// Small HTTP transport used only for the local, one-shot pairing exchange.
///
/// Payload confidentiality and integrity come from the X25519 + AES-GCM
/// envelope, not the transport. The QR's ephemeral key and bearer token still
/// bind the response to the TV the phone actually scanned.
class SyncPairingHttpClient {
  SyncPairingHttpClient._();

  static Future<SyncEnvelope> fetch({
    required SyncPairingUri pairing,
    required SyncPayload payload,
    required String hostId,
    KeyPair? senderKeyPair,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final keyPair = senderKeyPair ?? await SyncPairingCrypto.newKeyPair();
    final senderPublicKey = await SyncPairingCrypto.publicKeyBase64(keyPair);
    final key = await SyncPairingCrypto.deriveKey(
      localKeyPair: keyPair,
      remotePublicKey: pairing.publicKey,
      token: pairing.token,
      hostId: hostId,
      direction: 'phone-to-tv',
    );
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .postUrl(Uri(scheme: 'http', host: pairing.host, port: pairing.port, path: '/v1/sync'))
          .timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${pairing.token}');
      final envelope = await SyncPairingCrypto.seal(
        key: key,
        hostId: hostId,
        publicKey: senderPublicKey,
        payload: payload,
      );
      request.add(utf8.encode(jsonEncode(envelope.toJson())));
      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw SyncPairingHttpException(response.statusCode, body);
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw const FormatException('Invalid Velo sync response');
      return SyncEnvelope.fromJson(Map<String, dynamic>.from(decoded));
    } finally {
      keyPair.destroy();
      client.close(force: true);
    }
  }
}

class SyncPairingHttpException implements Exception {
  const SyncPairingHttpException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'SyncPairingHttpException($statusCode): $body';
}
