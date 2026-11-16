import 'package:xml/xml.dart';

import '../exceptions/media_server_exceptions.dart';
import '../utils/media_server_http_client.dart';

class ServerRouteIdentityMismatch implements Exception {
  const ServerRouteIdentityMismatch();
}

/// Validate an anonymous Plex probe before a route can be persisted.
void validatePlexRouteIdentity(MediaServerResponse response, String expectedServerId) {
  throwIfHttpError(response);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw const MediaServerUrlException('Plex identity endpoint did not succeed');
  }
  final String? identity;
  try {
    final document = XmlDocument.parse(response.data.toString());
    if (document.rootElement.name.local != 'MediaContainer') {
      throw const MediaServerUrlException('Invalid Plex identity response');
    }
    identity = document.rootElement.getAttribute('machineIdentifier');
  } on XmlException {
    throw const MediaServerUrlException('Invalid Plex identity response');
  }
  if (identity == null || identity.isEmpty) {
    throw const MediaServerUrlException('Missing Plex identity');
  }
  if (identity != expectedServerId) throw const ServerRouteIdentityMismatch();
}
