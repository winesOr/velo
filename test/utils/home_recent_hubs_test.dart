import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/utils/home_recent_hubs.dart';

import '../test_helpers/media_items.dart';

void main() {
  test('recent rows merge by media type, retain server identities and use real added dates', () {
    final old = testMediaItem(id: 'movie', serverId: 'a', addedAt: 1);
    final recent = old.copyWith(serverId: 'b', addedAt: 3);
    final show = testMediaItem(id: 'show', kind: MediaKind.show, serverId: 'a', addedAt: 2);
    final rows = homeRecentHubs(
      [
        MediaHub(id: 'recentlyAdded', title: 'A', type: 'mixed', items: [old, show]),
        MediaHub(id: 'latest', title: 'B', type: 'movie', items: [recent, old]),
        MediaHub(
          id: 'recommended',
          title: 'Picks',
          type: 'movie',
          items: [old.copyWith(id: 'pick', addedAt: 9)],
        ),
      ],
      movieTitle: 'Movies',
      showTitle: 'Shows',
    );
    expect(rows.map((row) => row.type), ['movie', 'show']);
    expect(rows.first.items, [recent, old]);
    expect(rows.last.items, [show]);
    expect(homeRecentHubs([], movieTitle: 'Movies', showTitle: 'Shows'), isEmpty);
  });
}
