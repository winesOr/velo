import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/screens/media_detail/related_items.dart';

void main() {
  test('combines video recommendations in source order without collapsing different servers', () {
    MediaItem item(String id, MediaKind kind, {String server = 'one'}) =>
        MediaItem(id: id, backend: MediaBackend.jellyfin, kind: kind, serverId: server);
    final movie = item('same', MediaKind.movie);
    final show = item('show', MediaKind.show);
    final otherServerMovie = item('same', MediaKind.movie, server: 'two');
    final items = detailRelatedItems([
      MediaHub(
        id: 'similar',
        title: 'Similar',
        type: 'mixed',
        items: [movie, item('collection', MediaKind.collection)],
      ),
      MediaHub(id: 'director', title: 'Director', type: 'mixed', items: [movie, show, otherServerMovie]),
    ]);
    expect(items, [movie, show, otherServerMovie]);
  });

  test('view all expands recommendations beyond the initial preview on each backend', () async {
    for (final backend in MediaBackend.values) {
      final items = [
        for (var index = 0; index < 43; index++)
          MediaItem(id: '$index', backend: backend, kind: MediaKind.movie, serverId: 'server'),
      ];
      final client = _RelatedClient(backend, items);
      final all = await loadDetailRelatedItems(
        client,
        itemId: 'movie',
        preview: [
          MediaHub(
            id: 'similar',
            title: 'Related',
            type: 'movie',
            items: items.take(10).toList(),
            more: backend == MediaBackend.plex,
          ),
        ],
      );
      expect(all, items);
      if (backend != MediaBackend.plex) expect(client.requestedCounts.last, greaterThan(items.length));
    }
  });
}

class _RelatedClient extends Fake implements MediaServerClient {
  _RelatedClient(this.backend, this.items);

  @override
  final MediaBackend backend;
  final List<MediaItem> items;
  final requestedCounts = <int>[];

  @override
  Future<List<MediaHub>> fetchRelatedHubs(String id, {int count = 10}) async {
    requestedCounts.add(count);
    return [MediaHub(id: 'similar', title: 'Related', type: 'movie', items: items.take(count).toList())];
  }

  @override
  Future<List<MediaItem>> fetchMoreHubItems(String hubId, {int? limit}) async => items;
}
