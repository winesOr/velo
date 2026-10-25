import 'dart:convert';

import 'package:http/http.dart' as http;

enum DlnaFailure { unavailable, rejected, unconfirmed, unsupportedSource }

/// Never includes network responses or URLs: both may contain server tokens.
class DlnaException implements Exception {
  const DlnaException(this.failure, {this.mayBePlaying = false});

  final DlnaFailure failure;
  final bool mayBePlaying;

  @override
  String toString() => 'DlnaException(${failure.name})';
}

Future<({int status, String body})> readDlnaResponse(
  http.Client client,
  http.Request request, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  return (() async {
    final response = await client.send(request);
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > 256 * 1024) throw const DlnaException(DlnaFailure.rejected);
      bytes.addAll(chunk);
    }
    return (status: response.statusCode, body: utf8.decode(bytes));
  })().timeout(timeout);
}
