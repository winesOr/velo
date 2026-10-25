import '../i18n/strings.g.dart';
import '../media/media_item.dart';

/// Release-group file names leak into episode titles when a server has no
/// scraped metadata, e.g. `[GM-Team][国漫][一念永恒 第4季][2026][04][AVC][1080P]`.
/// Such a title carries no name worth showing; the episode number is better.
final _bracketGroup = RegExp(r'\[[^\]]*\]');
final _releaseToken = RegExp(
  r'\b(1080p|2160p|720p|480p|4k|x26[45]|h\.?26[45]|hevc|avc|aac|flac|ac3|e-?ac-?3|dts|web-?dl|webrip|bluray|bdrip|hdr|10bit)\b',
  caseSensitive: false,
);
final _fileExtension = RegExp(r'\.(mkv|mp4|avi|ts|m2ts|mov|wmv|flv|webm|rmvb)$', caseSensitive: false);

bool looksLikeReleaseFileName(String title) {
  final text = title.trim();
  if (text.isEmpty) return false;
  if (_fileExtension.hasMatch(text)) return true;
  if (_bracketGroup.allMatches(text).length >= 2) return true;
  return _releaseToken.allMatches(text).length >= 2;
}

/// Episode number written into a release file name, e.g. the `[04]` in
/// `[GM-Team][国漫][一念永恒 第4季][2026][04][AVC][1080P]`. Takes the last
/// bracket that holds only 1–3 digits, so a `[2026]` year is skipped.
final _bracketNumber = RegExp(r'\[(\d{1,3})\]');

int? episodeNumberFromReleaseName(String? title) {
  if (title == null || !looksLikeReleaseFileName(title)) return null;
  final matches = _bracketNumber.allMatches(title).toList();
  if (matches.isEmpty) return null;
  return int.tryParse(matches.last.group(1)!);
}

/// The server's episode number, or the one in a release file name when the
/// server never scraped it (Emby leaves `IndexNumber` unset).
int? effectiveEpisodeIndex(MediaItem episode) => episode.index ?? episodeNumberFromReleaseName(episode.title);

/// Display title for an episode row: the server title unless it is a release
/// file name, in which case `Episode N` (or the raw title when the number is
/// unknown too).
String episodeDisplayTitle(MediaItem episode) {
  final title = episode.title?.trim() ?? '';
  final index = effectiveEpisodeIndex(episode);
  if (title.isNotEmpty && !looksLikeReleaseFileName(title)) {
    return index != null ? '$index. $title' : title;
  }
  if (index != null) return t.common.episodeNumber(number: index);
  return title;
}

/// Compact `S1E2` play label. A missing episode number is not shown as 0:
/// the label falls back to the season alone, and to nothing when both are
/// unknown.
String compactEpisodeLabel({int? season, int? episode}) {
  if (season != null && episode != null) {
    return t.discover.playEpisode(season: season.toString(), episode: episode.toString());
  }
  if (season != null) return t.discover.playSeason(season: season.toString());
  if (episode != null) return t.common.episodeNumber(number: episode);
  return '';
}
