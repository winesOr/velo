import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/connection/server_routes.dart';
import 'package:plezy/connection/manual_plex_route.dart';
import 'package:plezy/services/plex_auth_service.dart';

void main() {
  test('route form rejects unsafe authorities and invalid boundary values', () {
    for (final port in ['0', '65536', '1.5', 'abc', '-1', '']) {
      expect(ServerRoute.validPort(port), isFalse, reason: port);
    }
    for (final port in ['1', '65535']) {
      expect(ServerRoute.validPort(port), isTrue);
    }
    for (final address in [
      'https://user:secret@media.test',
      'https://media.test:443',
      'http://media.test:80',
      'https://media.test/path',
      'https://media.test?a=1',
      'https://media.test#fragment',
      'ftp://media.test',
      'https://media.test:',
    ]) {
      expect(ServerRoute.validAddress(address), isFalse, reason: address);
    }
    expect(ServerRoute.validAddress('https://media.test'), isTrue);
    expect(ServerRoute.validAddress('http://[::1]/'), isTrue);
    expect(ServerRoute.validName('   '), isFalse);
    expect(ServerRoute.validName('名' * 41), isFalse);
    expect(ServerRoute.validName('名' * 40), isTrue);
    expect(ServerRoute.fromInput(name: ' Main ', address: 'http://media.test', port: '1').url, 'http://media.test:1');
  });

  test('manual Plex routes verify identity before forwarding the scoped token', () async {
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousHttpOverrides);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <({String path, String? token})>[];
    server.listen((request) async {
      requests.add((path: request.uri.path, token: request.headers.value('X-Plex-Token')));
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'MediaContainer': {'machineIdentifier': 'server'},
        }),
      );
      await request.response.close();
    });
    final url = 'http://127.0.0.1:${server.port}';
    final source = PlexServer(
      name: 'Authorized',
      clientIdentifier: 'server',
      accessToken: 'profile-token',
      connections: [],
      owned: false,
    );
    final selected = ManualPlexRoute(source, url);
    expect(selected.prioritizedEndpointUrls(preferredFirst: 'https://cached.test'), [url]);
    expect((await selected.findBestWorkingConnection().single).uri, url);
    expect(requests, [(path: '/identity', token: null), (path: '/', token: source.accessToken)]);
  });

  test('manual Plex routes reject a wrong server before authentication', () async {
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousHttpOverrides);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var requests = 0;
    server.listen((request) async {
      requests++;
      expect(request.headers.value('X-Plex-Token'), isNull);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'MediaContainer': {'machineIdentifier': 'wrong-server'},
        }),
      );
      await request.response.close();
    });
    final source = PlexServer(
      name: 'Authorized',
      clientIdentifier: 'server',
      accessToken: 'profile-token',
      connections: [],
      owned: false,
    );
    final selected = ManualPlexRoute(source, 'http://127.0.0.1:${server.port}');
    await expectLater(selected.findBestWorkingConnection().single, throwsA(isA<Exception>()));
    expect(requests, 1);
  });
}
