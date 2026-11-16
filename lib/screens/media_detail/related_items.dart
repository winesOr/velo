import '../../media/media_hub.dart';
import '../../media/media_item.dart';
import '../../media/media_item_types.dart';
import '../../media/media_backend.dart';
import '../../media/media_server_client.dart';

/// Keeps the server's recommendation order while combining overlapping rows.
List<MediaItem> detailRelatedItems(Iterable<MediaHub> hubs) {
  final seen = <String>{};
  return [
    for (final hub in hubs)
      for (final item in hub.items)
        if ((item.isMovie || item.isShow) && seen.add(item.globalKey)) item,
  ];
}

Future<List<MediaItem>> loadDetailRelatedItems(
  MediaServerClient client, {
  required String itemId,
  required List<MediaHub> preview,
}) async {
  if (client.backend != MediaBackend.plex) {
    // Similar has a count parameter but no offset in the neutral API.
    // Grow the requested window until the server returns its complete list.
    var count = preview.fold(0, (total, hub) => total + hub.items.length) + 1;
    while (true) {
      final hubs = await client.fetchRelatedHubs(itemId, count: count);
      final returned = hubs.fold(0, (total, hub) => total + hub.items.length);
      if (returned < count) return detailRelatedItems(hubs);
      count *= 2;
    }
  }
  final expanded = await Future.wait([
    for (final hub in preview)
      if (hub.more)
        client.fetchMoreHubItems(hub.id).then((items) => hub.copyWith(items: [...hub.items, ...items]))
      else
        Future.value(hub),
  ]);
  return detailRelatedItems(expanded);
}
