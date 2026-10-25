import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/danmaku/danmaku_comment.dart';
import 'package:plezy/danmaku/danmaku_heatmap.dart';

List<DanmakuComment> _comments(List<int> counts) => [
  for (var i = 0; i < counts.length; i++)
    for (var j = 0; j < counts[i]; j++) DanmakuComment(timeMs: i * 1000, text: '$i-$j'),
];

void main() {
  test('unknown duration and live streams have no buckets', () {
    for (final duration in [-1, 0]) {
      expect(DanmakuHeatmap.fromComments([], durationMs: duration).counts, isEmpty);
    }
    expect(DanmakuHeatmap.fromComments(_comments([1]), durationMs: 1000, isLive: true).counts, isEmpty);
  });

  test('empty data remains zero and a sub-second single bucket is safe', () {
    final empty = DanmakuHeatmap.fromComments([], durationMs: 2100);
    expect(empty.counts, [0, 0, 0]);
    expect(empty.displayValues, [0, 0, 0]);
    expect(empty.p95, 1);
    expect(empty.hasData, isFalse);
    final single = DanmakuHeatmap.fromComments(_comments([3]), durationMs: 400);
    expect(single.counts, [3]);
    expect(single.displayValues, [1]);
    expect(single.peakIndices, [0]);
    expect(single.bucketCenterMs(0), 399);
  });

  test('counts use half-open duration and bucket boundaries', () {
    final heat = DanmakuHeatmap.fromComments([
      for (final t in [-1, 0, 999, 1000, 1999, 2000, 2499, 2500, 3000]) DanmakuComment(timeMs: t, text: ''),
    ], durationMs: 2500);
    expect(heat.bucketMs, 1000);
    expect(heat.counts, [2, 2, 2]);
    expect(heat.bucketAt(2500), 2);
    expect(heat.bucketCenterMs(2), 2499);
    expect(() => heat.counts[0] = 4, throwsUnsupportedError);
    expect(() => heat.displayValues[0] = .5, throwsUnsupportedError);
  });

  test('long videos choose integer duration divided by 600', () {
    final heat = DanmakuHeatmap.fromComments([], durationMs: 3600001);
    expect(heat.bucketMs, 6000);
    expect(heat.counts.length, 601);
  });

  test('sparse P95 has denominator one while raw spike count is retained', () {
    final heat = DanmakuHeatmap.fromComments(_comments([90, ...List.filled(99, 0)]), durationMs: 100000);
    expect(heat.p95, 1);
    expect(heat.counts.first, 90);
    expect(heat.displayValues.first, 1);
    expect(heat.displayValues[4], 1);
    expect(heat.displayValues[5], 0);
  });

  test('P95 uses floor index and nine-bucket mean with shortened edges', () {
    final heat = DanmakuHeatmap.fromComments(_comments(List.generate(21, (i) => i)), durationMs: 21000);
    expect(heat.p95, 19);
    expect(heat.displayValues[0], closeTo(2 / 19, 1e-12));
    expect(heat.displayValues[10], closeTo(10 / 19, 1e-12));
    expect(heat.displayValues[20], closeTo(18 / 19, 1e-12));
  });

  test('offsets delay or advance before clipping exactly once', () {
    final source = [const DanmakuComment(timeMs: 1000, text: ''), const DanmakuComment(timeMs: 2000, text: '')];
    expect(DanmakuHeatmap.fromComments(source, durationMs: 3000, offsetMs: 1000).counts, [0, 0, 1]);
    expect(DanmakuHeatmap.fromComments(source, durationMs: 3000, offsetMs: -2000).counts, [1, 0, 0]);
  });

  test('click window stays fixed and threshold is strict', () {
    final heat = DanmakuHeatmap.fromComments(_comments(List.generate(30, (i) => i * 10)), durationMs: 30000);
    expect(heat.peakNear(20500), 26);
    expect(heat.peakNear(1000), isNull);
    final flat = DanmakuHeatmap.fromComments(_comments(List.filled(20, 2)), durationMs: 20000);
    expect(flat.peakNear(10500), 10, reason: 'equal highest values choose nearest to the click');
    expect(flat.peakIndices, [9], reason: 'a continuous plateau selects its earlier middle bucket');
    final threshold = DanmakuHeatmap.fromComments(_comments([1, 1, 1, 0, 0]), durationMs: 5000);
    expect(threshold.displayValues[2], .6);
    expect(threshold.peakNear(2500), isNull);
    final ties = DanmakuHeatmap.fromComments(
      _comments([0, 0, 0, 0, 0, 0, 1, 2, 1, 2, 2, 2, 1, 1, 0, 2, 1, 2, 2, 2, 0, 0, 0, 1, 2]),
      durationMs: 25000,
    );
    expect(ties.peakNear(12500), 11, reason: 'equal height and distance chooses the earlier bucket');
  });

  test('nearest positive peak ties choose earlier and no-data has no peak', () {
    final counts = List<int>.filled(40, 0);
    counts[8] = counts[30] = 1;
    final heat = DanmakuHeatmap.fromComments(_comments(counts), durationMs: 40000);
    expect(heat.peakIndices, [8, 30]);
    expect(heat.nearestPeak(19500), 8);
    expect(heat.nearestPeak(30000), 30);
    expect(DanmakuHeatmap.fromComments([], durationMs: 1000).nearestPeak(0), isNull);
  });

  test('cache identity excludes position and tracks every aggregation input', () {
    final cache = DanmakuHeatmapCache();
    final source = _comments([1, 2]);
    DanmakuHeatmap read({Object item = 'a', int version = 1, int duration = 2000, Object? filter, int offset = 0}) =>
        cache.resolve(
          comments: source,
          itemKey: item,
          dataVersion: version,
          durationMs: duration,
          filterKey: filter,
          offsetMs: offset,
        );
    var previous = read();
    for (var position = 0; position < 100; position++) {
      expect(identical(read(), previous), isTrue);
    }
    for (final next in [read(version: 2), read(duration: 3000), read(item: 'b'), read(filter: 'c'), read(offset: 10)]) {
      expect(identical(previous, next), isFalse);
      previous = next;
    }
  });
}
