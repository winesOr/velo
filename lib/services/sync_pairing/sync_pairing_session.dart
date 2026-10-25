import 'dart:math';

/// One-time pairing state shared by the TV receiver and the phone scanner.
///
/// The QR code carries the host, port, ephemeral X25519 public key and a random
/// bearer token. It never carries a media-server credential. A session can be
/// claimed once, expires quickly, and stops accepting guesses after a small
/// number of failed attempts.
class SyncPairingSession {
  SyncPairingSession({required this.token, required this.expiresAt, DateTime? now, this.maxFailedAttempts = 8})
    : createdAt = now ?? DateTime.now();

  static const int tokenBytes = 32;

  final String token;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int maxFailedAttempts;

  bool _claimed = false;
  int _failedAttempts = 0;

  bool isExpired([DateTime? at]) => !(at ?? DateTime.now()).isBefore(expiresAt);

  bool get isClaimed => _claimed;
  bool get isExhausted => _failedAttempts >= maxFailedAttempts;
  int get failedAttempts => _failedAttempts;

  /// Returns true only for the live, unclaimed, non-exhausted token.
  bool acceptToken(String candidate, [DateTime? at]) {
    if (isExpired(at) || _claimed || isExhausted) return false;
    if (!_constantTimeEquals(token, candidate)) {
      _failedAttempts++;
      return false;
    }
    _claimed = true;
    return true;
  }

  void resetClaim() {
    _claimed = false;
  }

  static String generateToken([Random? random]) {
    final source = random ?? Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
    return List<String>.generate(tokenBytes, (_) => alphabet[source.nextInt(alphabet.length)]).join();
  }

  static bool _constantTimeEquals(String a, String b) {
    var diff = a.length ^ b.length;
    final length = max(a.length, b.length);
    for (var i = 0; i < length; i++) {
      final ac = i < a.length ? a.codeUnitAt(i) : 0;
      final bc = i < b.length ? b.codeUnitAt(i) : 0;
      diff |= ac ^ bc;
    }
    return diff == 0;
  }
}
