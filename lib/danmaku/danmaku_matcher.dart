import 'danmaku_api_client.dart';

/// Search-box text: the work keyword plus the episode, e.g. `剧名 第2季 第5集`.
/// Only the keyword goes to `search/anime`; the episode picks the hit.
String danmakuDisplayQuery(String keyword, int? episode) => episode == null ? keyword : '$keyword 第$episode集';

final _episodeSuffix = RegExp(r'\s*第\s*(\d+)\s*[集话話]\s*$');

/// Splits a search-box query into the API keyword and an optional episode.
({String keyword, int? episode}) parseDanmakuQuery(String query) {
  final trimmed = query.trim();
  final match = _episodeSuffix.firstMatch(trimmed);
  if (match == null) return (keyword: trimmed, episode: null);
  final keyword = trimmed.substring(0, match.start).trim();
  if (keyword.length < 2) return (keyword: trimmed, episode: null);
  return (keyword: keyword, episode: int.tryParse(match.group(1)!));
}

final _season = RegExp(r'第\s*(\d+)\s*[季期部]|(?:season|s)\s*(\d+)', caseSensitive: false);
final _noise = RegExp(r'[\s\p{P}\p{S}]+', unicode: true);

String _normalize(String value) => value.toLowerCase().replaceAll(_season, '').replaceAll(_noise, '');

int? _seasonOf(String value) {
  final match = _season.firstMatch(value);
  return match == null ? null : int.tryParse(match.group(1) ?? match.group(2) ?? '');
}

/// Closeness of a work [title] to the show [keyword] (which may carry
/// `第N季`). Higher is better; 0 means unrelated.
int danmakuWorkScore(String title, String keyword) {
  final want = _normalize(keyword);
  final have = _normalize(title);
  if (want.isEmpty || have.isEmpty) return 0;
  var score = 0;
  if (have == want) {
    score = 100;
  } else if (have.startsWith(want)) {
    score = 70;
  } else if (have.contains(want)) {
    score = 55;
  } else if (want.contains(have)) {
    score = 40;
  } else {
    return 0;
  }
  // Season: a matching number is a strong signal, a different one rules the
  // work out of the top spot. Season 1 is often untitled on dandanplay.
  final wantSeason = _seasonOf(keyword) ?? 1;
  final haveSeason = _seasonOf(title) ?? 1;
  score += wantSeason == haveSeason ? 20 : -45;
  // Prefer the plain work over spin-offs/specials with longer titles.
  score -= (have.length - want.length).abs().clamp(0, 15);
  return score < 0 ? 0 : score;
}

/// [works] ordered best first (stable for ties).
List<DanmakuAnime> rankDanmakuWorks(List<DanmakuAnime> works, String keyword) {
  final indexed = [for (var i = 0; i < works.length; i++) (i, works[i], danmakuWorkScore(works[i].title, keyword))];
  indexed.sort((a, b) => b.$3 != a.$3 ? b.$3 - a.$3 : a.$1 - b.$1);
  return [for (final entry in indexed) entry.$2];
}

/// The work to pick without asking: the only candidate, or the top-ranked
/// one when it is a confident match that clearly beats the runner-up.
DanmakuAnime? confidentDanmakuWork(List<DanmakuAnime> works, String keyword) {
  if (works.isEmpty) return null;
  if (works.length == 1) return works.single;
  final ranked = rankDanmakuWorks(works, keyword);
  final best = danmakuWorkScore(ranked[0].title, keyword);
  final next = danmakuWorkScore(ranked[1].title, keyword);
  return best >= 90 && best - next >= 10 ? ranked.first : null;
}
