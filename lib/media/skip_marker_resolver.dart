import 'media_source_info.dart';

/// Merges skip markers from independent sources into the single list the
/// player consumes. For each marker type only the highest-priority source
/// wins — `server` (Jellyfin segments, Emby IntroTimestamps, Plex markers,
/// chapter fallback) over `aniskip` (community timestamps) over `custom`
/// (user-set skip seconds). Ranges are never unioned: a coarse custom range
/// must not clip a precise server one, and a mis-matched community hit must
/// not override what the server itself computed. A type only one source
/// provides (e.g. `recap` from aniskip) passes straight through.
const List<String> _sourcePriority = ['server', 'aniskip', 'custom'];

List<MediaMarker> resolveSkipMarkers({
  List<MediaMarker> serverMarkers = const [],
  List<MediaMarker> aniskipMarkers = const [],
  int customIntroSeconds = 0,
  int customEndSeconds = 0,
  int? durationMs,
}) {
  if (serverMarkers.isEmpty && aniskipMarkers.isEmpty && customIntroSeconds <= 0 && customEndSeconds <= 0) {
    return serverMarkers;
  }
  final custom = customSkipMarkers(
    introSeconds: customIntroSeconds,
    endSeconds: customEndSeconds,
    durationMs: durationMs,
  );

  final byType = <String, List<MediaMarker>>{};
  for (final marker in [...serverMarkers, ...aniskipMarkers, ...custom]) {
    byType.putIfAbsent(marker.type, () => []).add(marker);
  }

  final resolved = <MediaMarker>[];
  for (final candidates in byType.values) {
    MediaMarker? winner;
    for (final source in _sourcePriority) {
      for (final candidate in candidates) {
        if (candidate.source == source) {
          winner = candidate;
          break;
        }
      }
      if (winner != null) break;
    }
    resolved.add(winner ?? candidates.first);
  }
  resolved.sort((a, b) => a.startTimeOffset.compareTo(b.startTimeOffset));
  return resolved;
}

/// Synthetic markers from the user's skip-seconds fallback. Intro spans
/// `[0, N)`; credits spans `[duration - M, duration)`. Zero seconds — or an
/// unknown [durationMs], for credits — produces no marker on that side.
/// [MediaMarker.id] uses negative ids so synthetic markers can never collide
/// with server-assigned index ids.
List<MediaMarker> customSkipMarkers({int introSeconds = 0, int endSeconds = 0, int? durationMs}) {
  final markers = <MediaMarker>[];
  if (introSeconds > 0) {
    var introEnd = introSeconds * 1000;
    if (durationMs != null && durationMs > 0 && introEnd >= durationMs) introEnd = durationMs;
    if (introEnd > 0) {
      markers.add(MediaMarker(id: -1, type: 'intro', startTimeOffset: 0, endTimeOffset: introEnd, source: 'custom'));
    }
  }
  if (endSeconds > 0 && durationMs != null && durationMs > 0) {
    var creditsStart = durationMs - endSeconds * 1000;
    if (creditsStart < 0) creditsStart = 0;
    if (durationMs > creditsStart) {
      markers.add(
        MediaMarker(
          id: -2,
          type: 'credits',
          startTimeOffset: creditsStart,
          endTimeOffset: durationMs,
          source: 'custom',
        ),
      );
    }
  }
  return markers;
}
