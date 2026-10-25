import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../utils/app_logger.dart';
import 'sync_import_service.dart';
import 'sync_pairing_protocol.dart';
import 'sync_pairing_session.dart';

/// TV-side listener for a single phone-to-TV sync handoff.
class SyncReceiverServer {
  SyncReceiverServer({
    required this.importer,
    this.port = syncPairingDefaultPort,
    this.lifetime = const Duration(minutes: 5),
  });

  final SyncImportService importer;
  final int port;
  final Duration lifetime;

  HttpServer? _server;
  SyncPairingSession? _session;
  String? _hostId;
  KeyPair? _keyPair;
  String? _publicKey;
  String? _localAddress;
  int _actualPort = 0;
  Future<void>? _startFuture;
  StreamController<SyncReceiverState>? _stateController;
  Timer? _expiryTimer;
  bool _imported = false;

  Stream<SyncReceiverState> get states => (_stateController ??= StreamController<SyncReceiverState>.broadcast()).stream;

  SyncReceiverState get state =>
      SyncReceiverState(pairing: pairing, localAddress: _localAddress, publicKey: _publicKey, imported: _imported);

  SyncPairingUri? get pairing {
    final session = _session;
    final host = _localAddress;
    final publicKey = _publicKey;
    final hostId = _hostId;
    if (session == null ||
        session.isExpired() ||
        session.isClaimed ||
        session.isExhausted ||
        host == null ||
        publicKey == null ||
        hostId == null) {
      return null;
    }
    return SyncPairingUri(host: host, port: _actualPort, publicKey: publicKey, token: session.token, hostId: hostId);
  }

  String? get hostId => _hostId;

  Future<SyncReceiverState> start() async {
    final pending = _startFuture;
    if (pending != null) {
      await pending;
      return state;
    }
    final future = _start();
    _startFuture = future;
    try {
      await future;
      return state;
    } catch (_) {
      _startFuture = null;
      rethrow;
    }
  }

  Future<void> _start() async {
    await stop();

    final addresses = await _lanAddresses();
    if (addresses.isEmpty) throw const SocketException('No LAN IPv4 address available');
    final localAddress = addresses.first;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: false);
    final session = SyncPairingSession(
      token: SyncPairingSession.generateToken(),
      expiresAt: DateTime.now().add(lifetime),
    );
    final hostId = _newHostId();
    final keyPair = await SyncPairingCrypto.newKeyPair();
    final publicKey = await SyncPairingCrypto.publicKeyBase64(keyPair);
    _server = server;
    _session = session;
    _hostId = hostId;
    _keyPair = keyPair;
    _publicKey = publicKey;
    _localAddress = localAddress;
    _actualPort = server.port;
    _imported = false;
    _expiryTimer = Timer(lifetime, _expire);
    server.listen(
      _handleRequest,
      onError: (Object error) {
        appLogger.w('SyncReceiver: listener error', error: error);
      },
    );
    _emit();
    appLogger.i('SyncReceiver: listening on http://$localAddress:${server.port}');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    var headersCommitted = false;
    try {
      if (request.method != 'POST' || request.uri.path != '/v1/sync') {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      final session = _session;
      final hostId = _hostId;
      final receiverKeyPair = _keyPair;
      if (session == null || hostId == null || receiverKeyPair == null || session.isExpired() || session.isClaimed) {
        response.statusCode = HttpStatus.gone;
        await response.close();
        return;
      }
      final auth = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      final token = auth.startsWith('Bearer ') ? auth.substring(7) : '';
      if (!session.acceptToken(token)) {
        response.statusCode = session.isExhausted ? HttpStatus.tooManyRequests : HttpStatus.unauthorized;
        await response.close();
        _emit();
        return;
      }
      try {
        final body = await utf8.decoder.bind(request).join();
        if (body.length > 8 * 1024 * 1024) {
          response.statusCode = HttpStatus.requestEntityTooLarge;
          await response.close();
          return;
        }
        final decoded = jsonDecode(body);
        if (decoded is! Map) throw const FormatException('Invalid sync envelope');
        final envelope = SyncEnvelope.fromJson(Map<String, dynamic>.from(decoded));
        if (envelope.hostId != hostId) throw const FormatException('Wrong sync host');
        final requestKey = await SyncPairingCrypto.deriveKey(
          localKeyPair: receiverKeyPair,
          remotePublicKey: envelope.publicKey,
          token: session.token,
          hostId: hostId,
          direction: 'phone-to-tv',
        );
        final payload = await SyncPairingCrypto.open(key: requestKey, envelope: envelope);
        if (payload.hostId.isNotEmpty && payload.hostId != hostId) {
          throw const FormatException('Payload host mismatch');
        }
        await importer.apply(payload);

        final responseKey = await SyncPairingCrypto.deriveKey(
          localKeyPair: receiverKeyPair,
          remotePublicKey: envelope.publicKey,
          token: session.token,
          hostId: hostId,
          direction: 'tv-to-phone',
        );
        final ack = await SyncPairingCrypto.seal(
          key: responseKey,
          hostId: hostId,
          publicKey: _publicKey!,
          payload: SyncPayload(
            connections: const [],
            profiles: const [],
            profileConnections: const [],
            plexHomeUsers: const {},
            activeProfileId: null,
            hostId: hostId,
          ),
        );
        response.statusCode = HttpStatus.ok;
        headersCommitted = true;
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(ack.toJson()));
        await response.close();
        // Notify the UI only after the phone has the authenticated ACK. The
        // receive screen intentionally stays mounted so the claimed token can
        // still answer a replay with 410 instead of closing the listener.
        _imported = true;
        _expiryTimer?.cancel();
        _emit();
      } catch (error) {
        // A claimed token gets exactly one authenticated attempt. If the
        // ciphertext or payload is bad, never let the same QR be retried.
        _imported = false;
        _emit();
        if (!headersCommitted) {
          response.statusCode = HttpStatus.badRequest;
          await response.close();
        } else {
          await response.close();
        }
        rethrow;
      }
    } catch (error, stackTrace) {
      appLogger.w('SyncReceiver: failed to import payload', error: error, stackTrace: stackTrace);
      try {
        if (!headersCommitted) response.statusCode = HttpStatus.badRequest;
        await response.close();
      } catch (_) {}
    }
  }

  void _expire() {
    _emit();
  }

  void _emit() {
    final controller = _stateController;
    if (controller == null || controller.isClosed) return;
    controller.add(state);
  }

  Future<void> stop() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final server = _server;
    _server = null;
    _session = null;
    _hostId = null;
    _keyPair?.destroy();
    _keyPair = null;
    _publicKey = null;
    _localAddress = null;
    _actualPort = 0;
    _imported = false;
    await server?.close(force: true);
    _startFuture = null;
    _emit();
  }

  Future<void> dispose() async {
    await stop();
    await _stateController?.close();
    _stateController = null;
  }

  static Future<List<String>> _lanAddresses() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    final addresses = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback || address.isLinkLocal) continue;
        if (!addresses.contains(address.address)) addresses.add(address.address);
      }
    }
    return addresses;
  }

  static String _newHostId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class SyncReceiverState {
  const SyncReceiverState({
    required this.pairing,
    required this.localAddress,
    required this.publicKey,
    required this.imported,
  });

  final SyncPairingUri? pairing;
  final String? localAddress;
  final String? publicKey;
  final bool imported;

  bool get ready => pairing != null;
}
