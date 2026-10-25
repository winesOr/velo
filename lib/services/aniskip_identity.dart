import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';
import 'settings_service.dart';

/// Remembers AniSkip MAL-id resolutions per series: successful bindings
/// forever, failed ones for [AniSkipIdentityResolver.retryAfter] so an
/// unmatchable library does not re-query Jikan on every playback.
class AniSkipBindings {
  static const version = 1;

  final Map<String, int> malIds;
  final Map<String, int> missAtMs;

  const AniSkipBindings({this.malIds = const {}, this.missAtMs = const {}});

  static AniSkipBindings decode(String? raw) {
    if (raw == null || raw.isEmpty) return const AniSkipBindings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const AniSkipBindings();
      final bindings = decoded['bindings'];
      final misses = decoded['misses'];
      return AniSkipBindings(
        malIds: bindings is Map ? {for (final e in bindings.entries) e.key: (e.value as num).toInt()} : const {},
        missAtMs: misses is Map ? {for (final e in misses.entries) e.key: (e.value as num).toInt()} : const {},
      );
    } catch (_) {
      return const AniSkipBindings();
    }
  }

  String encode() => jsonEncode({'v': version, 'bindings': malIds, 'misses': missAtMs});
}

/// Strips a trailing season marker from a series title — MAL keeps each
/// season as its own anime under its own name, so "Foo 第2季" / "Foo Season 2"
/// must search as "Foo".
String stripSeasonSuffix(String title) {
  var result = title.trim();
  for (final pattern in [
    RegExp(r'\s*第\s*[0-9一二三四五六七八九十]+\s*[季部]\s*$'),
    RegExp(r'\s*(season|s)\s*[0-9]+\s*$', caseSensitive: false),
    RegExp(r'\s*[0-9]+\s*(nd|rd|th)\s+season\s*$', caseSensitive: false),
  ]) {
    result = result.replaceFirst(pattern, '').trim();
  }
  return result;
}

/// Normalizes a title for comparison: case-folded, all spacing and common
/// CJK/Latin punctuation removed. "Sousou no Frieren" and "sousou no frieren:"
/// compare equal.
String normalizeTitle(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'''[\s\-–—_:：·.,，。!！?？「」『』"'`~*&^%$#+;；/\\|<>\[\]{}()（）【】]'''), '');

/// Picks the Jikan (unofficial MAL API) entry whose any title form exactly
/// matches [queryTitle] after normalization. Exact-only on purpose: a wrong
/// MAL id produces confidently wrong skip ranges, which is worse than none —
/// non-exact candidates wait for a manual binding UI.
int? matchJikanResult(Object? jikanResponse, String queryTitle) {
  if (jikanResponse is! Map) return null;
  final data = jikanResponse['data'];
  if (data is! List || data.isEmpty) return null;

  final query = normalizeTitle(queryTitle);
  if (query.isEmpty) return null;

  for (final entry in data) {
    if (entry is! Map) continue;
    final malId = entry['mal_id'];
    if (malId is! num) continue;
    final titles = entry['titles'];
    if (titles is! List) continue;
    for (final form in titles) {
      if (form is! Map) continue;
      final value = form['title'];
      if (value is String && normalizeTitle(value) == query) return malId.toInt();
    }
    final plainTitle = entry['title'];
    if (plainTitle is String && normalizeTitle(plainTitle) == query) return malId.toInt();
  }
  return null;
}

/// Resolves a playing series to a MAL anime id for [AniSkipClient].
///
/// Chain: session memory → persisted bindings → Jikan exact-title search
/// (once per unresolved series, negative results retried after
/// [retryAfter]). Chinese-only titles rarely match MAL's romaji/English/Japanese
/// forms; those series keep falling through to the custom-seconds fallback
/// until a manual binding UI exists. Jikan's 3 req/s limit is not a concern:
/// at most one search fires per unresolved series per playback.
class AniSkipIdentityResolver {
  AniSkipIdentityResolver({
    http.Client? httpClient,
    this.jikanBaseUrl = 'https://api.jikan.moe/v4',
    this.timeout = const Duration(seconds: 4),
    DateTime Function()? now,
    this.settings,
  }) : _httpClient = httpClient,
       _now = now ?? DateTime.now {
    _ownedClient = httpClient == null ? http.Client() : null;
  }

  static const retryAfter = Duration(days: 7);

  final http.Client? _httpClient;
  http.Client? _ownedClient;
  final String jikanBaseUrl;
  final Duration timeout;
  final DateTime Function() _now;

  /// Injected lazily from [SettingsService.getInstance] when omitted.
  final SettingsService? settings;

  final _sessionCache = <String, int>{};

  http.Client get _client => _httpClient ?? _ownedClient!;

  /// [seriesKey] is the stable series identity ([MediaItem.seriesGlobalKey]);
  /// [title] the series title as the server spells it.
  Future<int?> resolveMalId({required String seriesKey, required String title}) async {
    final sessionHit = _sessionCache[seriesKey];
    if (sessionHit != null) return sessionHit;

    final settings = this.settings ?? await SettingsService.getInstance();
    var bindings = AniSkipBindings.decode(settings.read(SettingsService.aniskipBindings));
    final remembered = bindings.malIds[seriesKey];
    if (remembered != null) return _sessionCache[seriesKey] = remembered;

    final missedAt = bindings.missAtMs[seriesKey];
    if (missedAt != null && _now().millisecondsSinceEpoch - missedAt < retryAfter.inMilliseconds) return null;

    final queryTitle = stripSeasonSuffix(title);
    if (queryTitle.isEmpty) return null;

    final malId = await _searchJikan(queryTitle);
    if (malId != null) {
      _sessionCache[seriesKey] = malId;
      bindings = AniSkipBindings(malIds: {...bindings.malIds, seriesKey: malId}, missAtMs: bindings.missAtMs);
      await _persist(settings, bindings);
      return malId;
    }

    bindings = AniSkipBindings(
      malIds: bindings.malIds,
      missAtMs: {...bindings.missAtMs, seriesKey: _now().millisecondsSinceEpoch},
    );
    await _persist(settings, bindings);
    return null;
  }

  Future<int?> _searchJikan(String queryTitle) async {
    final uri = Uri.parse(
      '$jikanBaseUrl/anime',
    ).replace(queryParameters: {'q': queryTitle, 'limit': '10', 'sfw': 'true'});
    try {
      final response = await _client.get(uri, headers: {'User-Agent': 'Plezy/1.0'}).timeout(timeout);
      if (response.statusCode != 200) return null;
      return matchJikanResult(jsonDecode(utf8.decode(response.bodyBytes)), queryTitle);
    } on TimeoutException {
      return null;
    } catch (e) {
      appLogger.d('AniSkip identity search failed for "$queryTitle"', error: e);
      return null;
    }
  }

  Future<void> _persist(SettingsService settings, AniSkipBindings bindings) async {
    try {
      await settings.write(SettingsService.aniskipBindings, bindings.encode());
    } catch (e) {
      appLogger.d('AniSkip bindings persist failed', error: e);
    }
  }
}
