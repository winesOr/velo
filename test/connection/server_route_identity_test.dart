import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/connection/server_route_identity.dart';
import 'package:plezy/exceptions/media_server_exceptions.dart';
import 'package:plezy/utils/media_server_http_client.dart';

MediaServerResponse response(int status, String body) =>
    MediaServerResponse(statusCode: status, data: body, headers: const {});

void main() {
  for (final status in [401, 403, 500]) {
    test('R2-19 HTTP $status is checked before a plausible server identity', () {
      expect(
        () => validatePlexRouteIdentity(response(status, '<MediaContainer machineIdentifier="server"/>'), 'server'),
        throwsA(isA<MediaServerHttpException>().having((error) => error.statusCode, 'status', status)),
      );
    });
  }

  test('R2-19 a different server has a distinct identity failure', () {
    expect(
      () => validatePlexRouteIdentity(response(200, '<MediaContainer machineIdentifier="other"/>'), 'server'),
      throwsA(isA<ServerRouteIdentityMismatch>()),
    );
  });

  test('R2-19 malformed, empty, HTML and missing identities are invalid endpoints', () {
    for (final body in ['invalid XML', '', '<html>Unavailable</html>', '<MediaContainer/>']) {
      expect(
        () => validatePlexRouteIdentity(response(200, body), 'server'),
        throwsA(isA<MediaServerUrlException>()),
        reason: body,
      );
    }
  });

  test('only a successful response from the expected server is accepted', () {
    expect(
      () => validatePlexRouteIdentity(response(200, '<MediaContainer machineIdentifier="server"/>'), 'server'),
      returnsNormally,
    );
    expect(
      () => validatePlexRouteIdentity(response(302, '<MediaContainer machineIdentifier="server"/>'), 'server'),
      throwsA(isA<MediaServerUrlException>()),
    );
  });
}
