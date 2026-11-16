import '../media/media_hub.dart';
import '../media/media_item.dart';
import '../media/media_item_types.dart';

/// Combine real recently-added rows without turning recommendations into recency data.
List<MediaHub> homeRecentHubs(List<MediaHub> hubs, {required String movieTitle, required String showTitle}) {
  final movies = <String, MediaItem>{};
  final shows = <String, MediaItem>{};
  void keepLatest(Map<String, MediaItem> items, String key, MediaItem item) {
    final previous = items[key];
    if (previous == null || (item.addedAt ?? 0) > (previous.addedAt ?? 0)) items[key] = item;
  }

  for (final hub in hubs) {
    final key = '${hub.id} ${hub.identifier ?? ''}'.toLowerCase();
    if (!RegExp(r'(^|[^a-z])recent([^a-z]|$)|recentlyadded|latest').hasMatch(key)) continue;
    for (final item in hub.items) {
      if (item.isMovie) keepLatest(movies, item.globalKey, item);
      if (item.isShow || item.isEpisode || item.isSeason) {
        keepLatest(shows, item.seriesGlobalKey ?? item.globalKey, item);
      }
    }
  }
  List<MediaItem> ordered(Map<String, MediaItem> items) {
    final indexed = items.values.indexed.toList();
    indexed.sort((a, b) {
      final recency = (b.$2.addedAt ?? 0).compareTo(a.$2.addedAt ?? 0);
      return recency == 0 ? a.$1.compareTo(b.$1) : recency;
    });
    return indexed.map((entry) => entry.$2).toList(growable: false);
  }

  return [
    if (movies.isNotEmpty)
      MediaHub(id: 'home.recent.movies', title: movieTitle, type: 'movie', items: ordered(movies), more: true),
    if (shows.isNotEmpty)
      MediaHub(id: 'home.recent.shows', title: showTitle, type: 'show', items: ordered(shows), more: true),
  ];
}
