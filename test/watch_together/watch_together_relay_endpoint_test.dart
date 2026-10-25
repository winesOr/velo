import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/watch_together/services/watch_together_relay_endpoint.dart';

void main() {
  test('HTTP(S) bases derive health and websocket routes without dropping prefixes', () {
    for (final entry in [
      (
        ' https://relay.example.test/watch/ ',
        'https://relay.example.test/watch',
        'https://relay.example.test/watch/health',
        'wss://relay.example.test/watch/relay',
      ),
      (
        'http://relay.example.test:8080/team/room',
        'http://relay.example.test:8080/team/room',
        'http://relay.example.test:8080/team/room/health',
        'ws://relay.example.test:8080/team/room/relay',
      ),
      (
        'https://relay.example.test:443/',
        'https://relay.example.test',
        'https://relay.example.test/health',
        'wss://relay.example.test/relay',
      ),
      (
        'https://relay.example.test/a/../watch///',
        'https://relay.example.test/watch',
        'https://relay.example.test/watch/health',
        'wss://relay.example.test/watch/relay',
      ),
    ]) {
      final endpoint = WatchTogetherRelayEndpoint.tryParseCustom(entry.$1)!;
      expect(endpoint.canonicalBaseUrl, entry.$2);
      expect(endpoint.healthUri.toString(), entry.$3);
      expect(endpoint.webSocketUri.toString(), entry.$4);
    }
  });

  test('rejects websocket URLs and ambiguous bases instead of saving them', () {
    for (final value in [
      'ws://relay.example.test',
      'wss://relay.example.test/relay',
      'ftp://relay.example.test',
      'relay.example.test',
      'https://user:password@relay.example.test',
      'https://relay.example.test?token=secret',
      'https://relay.example.test#relay',
      'http://relay.example.test:0',
      'http://relay.example.test:65536',
      '',
    ]) {
      expect(WatchTogetherRelayEndpoint.tryParseCustom(value), isNull, reason: value);
    }
  });
}
