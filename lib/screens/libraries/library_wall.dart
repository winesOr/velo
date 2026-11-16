import '../../media/media_item.dart';
import '../../media/ids.dart';
import '../../utils/global_key_utils.dart';
import '../../media/media_kind.dart';
import '../../media/media_library.dart';
import '../../media/media_playlist.dart';

/// The additional categories are derived from returned metadata, never a
/// library's display name. A server without genre metadata cannot classify it.
enum LibraryWallType { all, series, movies, anime, variety, concert, documentary, music, collections, playlists }

class LibraryWallEntry {
  const LibraryWallEntry(this.library, this.item);

  final MediaLibrary library;
  final Object item;

  MediaItem? get media => item is MediaItem ? item as MediaItem : null;
  MediaPlaylist? get playlist => item is MediaPlaylist ? item as MediaPlaylist : null;
  String get globalKey {
    final server = media?.serverId ?? playlist?.serverId ?? library.serverId;
    final id = media?.id ?? playlist!.id;
    return server == null ? '${library.globalKey}/$id' : buildGlobalKey(ServerId(server), id);
  }

  String get title => media?.displayTitle ?? playlist!.displayTitle;
  int? get updatedAt => media?.updatedAt ?? playlist?.updatedAt ?? media?.addedAt ?? playlist?.addedAt;
  int? get releasedAt =>
      DateTime.tryParse(media?.originallyAvailableAt ?? '')?.millisecondsSinceEpoch ??
      (media?.year == null ? null : DateTime(media!.year!).millisecondsSinceEpoch);
  double? get rating => media?.rating ?? media?.ratings?.firstOrNull?.value;
}

bool libraryWallTypeMatches(LibraryWallType type, MediaItem item) {
  final genres = (item.genres ?? const <String>[]).map((value) => value.trim().toLowerCase()).toSet();
  bool tagged(Set<String> values) => genres.any(values.contains);
  return switch (type) {
    LibraryWallType.all => true,
    LibraryWallType.series => item.kind == MediaKind.show,
    LibraryWallType.movies => item.kind == MediaKind.movie,
    LibraryWallType.music => item.kind.isMusic,
    LibraryWallType.collections => item.kind == MediaKind.collection,
    LibraryWallType.playlists => item.kind == MediaKind.playlist,
    LibraryWallType.anime => tagged({'animation', 'anime', '动画', '動畫', '动漫', '動漫'}),
    LibraryWallType.variety => tagged({'reality', 'reality-tv', 'talk show', 'talk-show', 'variety', '综艺', '綜藝'}),
    LibraryWallType.concert => tagged({'concert', 'concerts', 'music concert', '演唱会', '演唱會', '音乐会', '音樂會'}),
    LibraryWallType.documentary => tagged({'documentary', 'documentaries', '纪录', '紀錄', '纪录片', '紀錄片'}),
  };
}
