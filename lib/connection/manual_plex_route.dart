import 'package:xml/xml.dart';

import '../exceptions/media_server_exceptions.dart';
import '../services/plex_auth_service.dart';
import '../utils/media_server_http_client.dart';
import '../utils/media_server_timeouts.dart';

/// A manually selected endpoint bypasses Plex discovery/latency ordering.
/// Fresh server objects still supply the active profile's scoped token.
class ManualPlexRoute extends PlexServer {
  final String selectedUrl;

  ManualPlexRoute(PlexServer server, this.selectedUrl)
    : super(
        name: server.name,
        clientIdentifier: server.clientIdentifier,
        accessToken: server.accessToken,
        connections: server.connections,
        owned: server.owned,
        product: server.product,
        platform: server.platform,
        lastSeenAt: server.lastSeenAt,
      );

  @override
  List<String> prioritizedEndpointUrls({String? preferredFirst}) => [selectedUrl];

  @override
  Stream<PlexConnection> findBestWorkingConnection({
    String? preferredUri,
    String? clientIdentifier,
    void Function(bool)? onTranscoderCapability,
  }) async* {
    final http = MediaServerHttpClient(baseUrl: selectedUrl, defaultHeaders: const {'Accept': 'application/json'});
    String? identity(MediaServerResponse response) {
      final data = response.data;
      if (data is Map && data['MediaContainer'] is Map) {
        return (data['MediaContainer'] as Map)['machineIdentifier']?.toString();
      }
      return data is String ? XmlDocument.parse(data).rootElement.getAttribute('machineIdentifier') : null;
    }

    try {
      // Confirm the destination before forwarding the active profile's token.
      final public = await http.get('/identity', timeout: MediaServerTimeouts.plexProbe);
      throwIfHttpError(public);
      if (identity(public) != this.clientIdentifier) {
        throw const MediaServerUrlException('Plex route identity mismatch');
      }
      final authenticated = await http.get(
        '/',
        headers: {'X-Plex-Token': accessToken, 'X-Plex-Client-Identifier': ?clientIdentifier},
        timeout: MediaServerTimeouts.plexProbe,
      );
      throwIfHttpError(authenticated);
      if (identity(authenticated) != this.clientIdentifier) {
        throw const MediaServerUrlException('Plex route identity mismatch');
      }
    } finally {
      http.close();
    }
    final uri = Uri.parse(selectedUrl);
    yield PlexConnection(
      protocol: uri.scheme,
      address: uri.host,
      port: uri.port,
      uri: selectedUrl,
      local: false,
      relay: false,
      ipv6: uri.host.contains(':'),
    );
  }
}
