import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'danmaku_source.dart';

/// Dandanplay v2 subset. Every result carries the originating source identity.
class DanmakuApiClient {
  final http.Client _http;
  final DanmakuEndpoint endpoint;
  final String sourceId;
  final DanmakuCredentials? credentials;
  final Duration timeout;
  final DateTime Function() _clock;
  final bool _ownsClient;

  DanmakuApiClient({
    http.Client? httpClient,
    required String baseUrl,
    this.sourceId = '',
    this.credentials,
    this.timeout = const Duration(seconds: 20),
    DateTime Function()? clock,
  }) : _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       endpoint = DanmakuEndpoint(baseUrl),
       _clock = clock ?? DateTime.now;

  void close() {
    if (_ownsClient) _http.close();
  }

  Future<List<DanmakuAnime>> searchAnime(String keyword) async {
    final query = keyword.trim();
    if (query.length < 2) return const [];
    try {
      final body = await _get('search/anime', {'keyword': query});
      final rows = body['animes'];
      if (rows is! List) throw const DanmakuApiException('invalid_response');
      return rows
          .map((row) {
            if (row is! Map) throw const DanmakuApiException('invalid_response');
            final id = row['bangumiId'] ?? row['animeId'];
            if (id == null) throw const DanmakuApiException('invalid_response');
            return DanmakuAnime(
              sourceId: sourceId,
              animeId: '$id',
              title: (row['animeTitle'] ?? row['title'] ?? '').toString(),
            );
          })
          .toList(growable: false);
    } on DanmakuApiException catch (error) {
      if (!error.isUnsupportedRoute) rethrow;
      final hits = await searchEpisodes(query);
      final groups = <String, List<DanmakuSearchHit>>{};
      for (final hit in hits) {
        groups.putIfAbsent(hit.animeId, () => []).add(hit);
      }
      return groups.entries
          .map(
            (entry) => DanmakuAnime(
              sourceId: sourceId,
              animeId: entry.key,
              title: entry.value.first.animeTitle,
              episodes: List.unmodifiable(entry.value),
            ),
          )
          .toList(growable: false);
    }
  }

  Future<List<DanmakuSearchHit>> bangumi(DanmakuAnime anime) async {
    if (anime.sourceId != sourceId) throw const DanmakuApiException('source_mismatch');
    if (anime.episodes != null) return anime.episodes!;
    try {
      final body = await _get('bangumi/${Uri.encodeComponent(anime.animeId)}');
      final bangumi = body['bangumi'];
      if (bangumi is! Map || bangumi['episodes'] is! List) throw const DanmakuApiException('invalid_response');
      return _episodes(bangumi['episodes'] as List, anime.animeId, anime.title);
    } on DanmakuApiException catch (error) {
      if (!error.isUnsupportedRoute) rethrow;
      // Legacy results must still belong to this source and selected work.
      final hits = await searchEpisodes(anime.title);
      final exact = hits.where((hit) => hit.animeId == anime.animeId).toList(growable: false);
      if (exact.isNotEmpty) return exact;
      final sameTitle = hits.where((hit) => hit.animeTitle == anime.title).toList(growable: false);
      if (sameTitle.map((hit) => hit.animeId).toSet().length > 1) throw const DanmakuApiException('ambiguous_work');
      return sameTitle;
    }
  }

  Future<List<DanmakuSearchHit>> searchEpisodes(String anime, {String? episode}) async {
    if (anime.trim().length < 2) return const [];
    final body = await _get('search/episodes', {
      'anime': anime.trim(),
      if (episode != null && episode.isNotEmpty) 'episode': episode,
    });
    final rows = body['animes'];
    if (rows is! List) throw const DanmakuApiException('invalid_response');
    final hits = <DanmakuSearchHit>[];
    for (final row in rows) {
      if (row is! Map) throw const DanmakuApiException('invalid_response');
      final title = (row['animeTitle'] ?? row['title'] ?? '').toString();
      final episodes = row['episodes'];
      if (episodes is! List) throw const DanmakuApiException('invalid_response');
      // Some legacy gateways omit animeId. A title is a grouping key only;
      // episode IDs remain bound to sourceId and are never shared across sources.
      hits.addAll(_episodes(episodes, '${row['animeId'] ?? title}', title));
    }
    return hits;
  }

  List<DanmakuSearchHit> _episodes(List rows, String animeId, String title) => rows
      .map((row) {
        if (row is! Map) throw const DanmakuApiException('invalid_response');
        if (row['episodeId'] == null) throw const DanmakuApiException('invalid_response');
        return DanmakuSearchHit(
          sourceId: sourceId,
          animeId: animeId,
          episodeId: '${row['episodeId']}',
          animeTitle: title,
          episodeTitle: (row['episodeTitle'] ?? '').toString(),
          episodeNumber: _episodeNumber(row['episodeNumber'] ?? row['episodeTitle']),
          commentCount: row['commentCount'] is num ? (row['commentCount'] as num).toInt() : null,
        );
      })
      .toList(growable: false);

  static int? _episodeNumber(Object? raw) {
    if (raw is int) return raw;
    final value = raw?.toString().trim() ?? '';
    final number = int.tryParse(value);
    if (number != null) return number;
    // Specials (SP/OVA/decimal numbers) deliberately stay ambiguous.
    final match = RegExp(r'^(?:第\s*(\d+)\s*[集话話]|[Ee][Pp]?\s*(\d+))(?:\s|$|[ :：.])').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(1) ?? match.group(2) ?? '');
  }

  Future<String> fetchCommentsRaw(String episodeId, {bool withRelated = true, int chConvert = 0}) async {
    if (chConvert < 0 || chConvert > 2) throw const DanmakuApiException('invalid_conversion');
    final body = await _get('comment/${Uri.encodeComponent(episodeId)}', {
      'withRelated': '$withRelated',
      'chConvert': '$chConvert',
    });
    if (body['comments'] is! List) throw const DanmakuApiException('invalid_response');
    return jsonEncode(body);
  }

  Future<Map<String, dynamic>> _get(String route, [Map<String, String> query = const {}]) async {
    var uri = endpoint.route(route, query);
    var headers = <String, String>{'User-Agent': 'Velo/1.0'};
    if (endpoint.isOfficial) {
      final own = credentials;
      if (own == null || !own.isValid) throw const DanmakuApiException('credentials_required');
      headers.addAll(DanmakuOfficialSigner.headers(own, uri, _clock().millisecondsSinceEpoch ~/ 1000));
    }
    try {
      for (var redirects = 0; redirects <= 5; redirects++) {
        final request = http.Request('GET', uri)..followRedirects = false;
        request.headers.addAll(headers);
        final response = await (() async => http.Response.fromStream(await _http.send(request)))().timeout(timeout);
        if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers['location'];
          if (location == null || redirects == 5) throw const DanmakuApiException('invalid_redirect');
          final target = uri.resolve(location);
          if (!const ['http', 'https'].contains(target.scheme) ||
              target.userInfo.isNotEmpty ||
              (uri.scheme == 'https' && target.scheme != 'https')) {
            throw const DanmakuApiException('invalid_redirect');
          }
          if (target.origin != uri.origin) {
            headers = {'User-Agent': 'Velo/1.0'};
          } else if (headers.containsKey('X-AppId')) {
            headers = {
              'User-Agent': 'Velo/1.0',
              ...DanmakuOfficialSigner.headers(credentials!, target, _clock().millisecondsSinceEpoch ~/ 1000),
            };
          }
          uri = target;
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw DanmakuApiException('http_error', statusCode: response.statusCode);
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic>) throw const DanmakuApiException('invalid_response');
        final code = decoded['errorCode'];
        if ((code is num && code != 0) || decoded['success'] == false) {
          // Upstream error messages can echo gateway path tokens or secrets.
          throw const DanmakuApiException('service_error');
        }
        return decoded;
      }
      throw const DanmakuApiException('invalid_redirect');
    } on TimeoutException {
      throw const DanmakuApiException('timeout');
    } on FormatException {
      throw const DanmakuApiException('invalid_response');
    } on http.ClientException {
      throw const DanmakuApiException('network_error');
    } on DanmakuApiException {
      rethrow;
    } catch (_) {
      throw const DanmakuApiException('network_error');
    }
  }
}

/// Contract: https://doc.dandanplay.com/open/ section 5 (verified 2026-10-23).
class DanmakuOfficialSigner {
  static Map<String, String> headers(DanmakuCredentials own, Uri uri, int timestamp) => {
    'X-AppId': own.appId,
    'X-Timestamp': '$timestamp',
    'X-Signature': base64Encode(sha256.convert(utf8.encode('${own.appId}$timestamp${uri.path}${own.appSecret}')).bytes),
  };
}

class DanmakuAnime {
  final String sourceId;
  final String animeId;
  final String title;
  final List<DanmakuSearchHit>? episodes;
  const DanmakuAnime({required this.sourceId, required this.animeId, required this.title, this.episodes});
}

class DanmakuSearchHit {
  final String sourceId;
  final String animeId;
  final String episodeId;
  final String animeTitle;
  final String episodeTitle;
  final int? episodeNumber;
  final int? commentCount;
  const DanmakuSearchHit({
    required this.sourceId,
    required this.animeId,
    required this.episodeId,
    required this.animeTitle,
    required this.episodeTitle,
    this.episodeNumber,
    this.commentCount,
  });
  String get label => episodeTitle.isEmpty ? animeTitle : '$animeTitle · $episodeTitle';
}

/// Safe for UI/logs: only local codes and numeric HTTP status, never remote text.
class DanmakuApiException implements Exception {
  final String message;
  final int? statusCode;
  const DanmakuApiException(this.message, {this.statusCode});
  bool get isUnsupportedRoute => statusCode == 404 || statusCode == 405 || statusCode == 501;
  @override
  String toString() => statusCode == null ? message : '$message ($statusCode)';
}

class DanmakuConnectionResult {
  final Duration elapsed;
  final String? error;
  const DanmakuConnectionResult({required this.elapsed, this.error});
  bool get isSuccess => error == null;
}
