import '../../media/media_item.dart';

/// Uses server lifecycle metadata, rather than watched/downloaded counts, to
/// distinguish a finished season from one that is still being released.
bool detailSeasonHasEnded(
  MediaItem season, {
  required MediaItem show,
  required Iterable<MediaItem> seasons,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  bool ended(MediaItem item) {
    final raw = item.raw;
    final status = (raw?['Status'] ?? raw?['status'])?.toString().toLowerCase();
    if (status == 'ended' || status == 'completed') return true;
    final endDate = DateTime.tryParse((raw?['EndDate'] ?? raw?['endDate'])?.toString() ?? '');
    return endDate != null && !endDate.isAfter(today);
  }

  if (ended(season) || ended(show)) return true;
  final number = season.index;
  if (number == null || number == 0) return false;
  // A later regular season that has actually premiered also establishes that
  // this earlier season ended. Merely having a future season in the library
  // does not, and specials never establish a regular season's lifecycle.
  return seasons.any((other) {
    if ((other.index ?? 0) <= number) return false;
    final premiere = DateTime.tryParse(other.originallyAvailableAt ?? '');
    return premiere != null && !premiere.isAfter(today);
  });
}
