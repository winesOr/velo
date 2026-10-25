import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/utils/home_hero_selection.dart';

import '../test_helpers/media_items.dart';

void main() {
  test('banner randomizes once per series, keeps server identities, and excludes non-video media', () {
    final episode = testMediaItem(id: 'e1', kind: MediaKind.episode, grandparentId: 'series', serverId: 'a');
    final sameSeries = episode.copyWith(id: 'e2');
    final otherServer = episode.copyWith(serverId: 'b');
    final movies = List.generate(8, (i) => testMediaItem(id: 'movie-$i', serverId: 'a'));
    final selected = selectHomeHeroItems([
      episode,
      sameSeries,
      otherServer,
      ...movies.take(4),
      testMediaItem(id: 'music', kind: MediaKind.track),
      testMediaItem(id: 'folder', kind: MediaKind.folder),
    ], random: Random(9));
    expect(
      selected.map((item) => item.globalKey),
      unorderedEquals([episode.globalKey, otherServer.globalKey, ...movies.take(4).map((item) => item.globalKey)]),
    );
    expect(selectHomeHeroItems([]), isEmpty);
    expect(selectHomeHeroItems([movies.first, movies.first]), [movies.first]);
  });

  test('new samples vary with the seed and prefer works outside the previous batch', () {
    final pool = List.generate(24, (i) => testMediaItem(id: 'movie-$i'));
    final first = selectHomeHeroItems(pool, random: Random(1));
    final different = selectHomeHeroItems(pool, random: Random(2));
    expect(first.map((item) => item.id), isNot(orderedEquals(different.map((item) => item.id))));
    final next = selectHomeHeroItems(
      pool,
      random: Random(3),
      previousKeys: first.map((item) => item.globalKey).toList(),
    );
    expect(next.length, 6);
    expect(next.any((item) => first.any((old) => old.globalKey == item.globalKey)), isFalse);
    expect(pool.first.id, 'movie-0', reason: 'sampling must not reorder the source rail');
  });

  test('one visit stays stable through progress updates and incoming recommendations; reroll replaces it', () {
    final selection = HomeHeroSelection(random: Random(4));
    final pool = List.generate(18, (i) => testMediaItem(id: 'movie-$i'));
    final first = selection.update(pool.take(12));
    final current = selection.update(pool.map((item) => item.copyWith(viewOffsetMs: 100)));
    expect(current.map((item) => item.id), orderedEquals(first.map((item) => item.id)));
    expect(current.every((item) => item.viewOffsetMs == 100), isTrue);
    selection.reroll();
    final next = selection.update(pool);
    expect(next.any((item) => first.any((old) => old.id == item.id)), isFalse);
    final otherSource = List.generate(8, (i) => testMediaItem(id: 'other-$i', serverId: 'other'));
    expect(selection.update(otherSource).every((item) => item.serverId == 'other'), isTrue);
  });

  test('late content tops up a small sample, and a small library still changes order', () {
    final selection = HomeHeroSelection(random: Random(5));
    final pool = List.generate(10, (i) => testMediaItem(id: 'movie-$i'));
    expect(selection.update([]), isEmpty);
    final first = selection.update(pool.take(2));
    expect(selection.update(pool).take(2), orderedEquals(first));
    expect(selection.update(pool).length, 6);
    final pair = selectHomeHeroItems(pool.take(2), random: Random(6));
    final next = selectHomeHeroItems(
      pool.take(2),
      random: Random(6),
      previousKeys: pair.map((item) => item.globalKey).toList(),
    );
    expect(next, isNot(orderedEquals(pair)));
  });
}
