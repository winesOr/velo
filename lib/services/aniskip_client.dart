import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../media/media_source_info.dart';
import '../utils/app_logger.dart';

/// AniSkip community anime skip timestamps (`https://api.aniskip.com`).
///
/// Wire contract, verified live 2026-10-24:
/// ```
/// GET /v2/skip-times/{malAnimeId}/{episodeNumber}?types[]=op&types[]=ed
///                            &episodeLength=1420
/// → { "found": true, "statusCode": 200, "results": [
///      { "interval": { "startTime": 34.54, "endTime": 124.54 },
///        "skipType": "op", "skipId": "…", "episodeLength": 1420.1 } ] }
/// ```
/// No API key. [fetchSkipTimes] never throws — AniSkip only enriches the
/// marker list, so every failure mode degrades to "no markers".
class AniSkipClient {
  AniSkipClient({this.httpClient, this.timeout = const Duration(seconds: 4)});

  static const _baseUrl = 'https://api.aniskip.com/v2';
  static const _userAgent = 'Plezy/1.0';

  final http.Client? httpClient;
  final Duration timeout;

  http.Client? _ownedClient;

  http.Client get _client {
    if (httpClient != null) return httpClient!;
    return _ownedClient ??= http.Client();
  }

  final _cache = <String, List<MediaMarker>>{};

  /// Skip markers for one episode, mapped onto the player's marker types:
  /// `op`/`mixed-op` → intro, `ed`/`mixed-ed` → credits, `recap` → recap.
  /// [episodeLengthSeconds] lets AniSkip prefer intervals recorded against
  /// releases of a similar length.
  Future<List<MediaMarker>> fetchSkipTimes({
    required int malId,
    required int episodeNumber,
    required double episodeLengthSeconds,
  }) async {
    final cacheKey = '$malId/$episodeNumber';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.parse('$_baseUrl/skip-times/$malId/$episodeNumber').replace(
      queryParameters: {
        'types[]': const ['op', 'ed', 'mixed-op', 'mixed-ed', 'recap'],
        'episodeLength': episodeLengthSeconds.round().toString(),
      },
    );
    try {
      final response = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(timeout);
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final markers = parseSkipTimes(decoded);
      _cache[cacheKey] = markers;
      return markers;
    } on TimeoutException {
      return const [];
    } catch (e) {
      appLogger.d('AniSkip fetch failed for $cacheKey', error: e);
      return const [];
    }
  }

  static List<MediaMarker> parseSkipTimes(Object? decoded) {
    if (decoded is! Map || decoded['found'] != true) return const [];
    final results = decoded['results'];
    if (results is! List) return const [];

    final markers = <MediaMarker>[];
    for (var i = 0; i < results.length; i++) {
      final entry = results[i];
      if (entry is! Map) continue;
      final interval = entry['interval'];
      if (interval is! Map) continue;
      final type = _skipTypeToMarkerType(entry['skipType']?.toString());
      final start = _secondsToMs(interval['startTime']);
      final end = _secondsToMs(interval['endTime']);
      if (type == null || start == null || end == null || end <= start) continue;
      markers.add(MediaMarker(id: i, type: type, startTimeOffset: start, endTimeOffset: end, source: 'aniskip'));
    }
    return markers;
  }

  static String? _skipTypeToMarkerType(String? value) => switch (value) {
    'op' || 'mixed-op' => 'intro',
    'ed' || 'mixed-ed' => 'credits',
    'recap' => 'recap',
    _ => null,
  };

  static int? _secondsToMs(Object? value) {
    if (value is! num) return null;
    final seconds = value.toDouble();
    if (seconds < 0) return null;
    return (seconds * 1000).round();
  }
}
