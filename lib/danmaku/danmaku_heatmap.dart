import 'dart:math' as math;

import 'danmaku_comment.dart';

/// Immutable density data for effective comments in [0, durationMs).
///
/// Raw counts supply long-press labels. Only display values use the nine-bucket
/// mean, divided by the raw-count P95 (floor index, denominator at least one).
/// Aggregation and percentile sorting cost O(n + b log b), with about 600 bins.
class DanmakuHeatmap {
  final int durationMs;
  final int bucketMs;
  final int p95;
  final List<int> counts;
  final List<double> displayValues;
  final List<int> peakIndices;

  DanmakuHeatmap._({
    required this.durationMs,
    required this.bucketMs,
    required this.p95,
    required List<int> counts,
    required List<double> displayValues,
  }) : counts = List.unmodifiable(counts),
       displayValues = List.unmodifiable(displayValues),
       peakIndices = List.unmodifiable(_peaks(displayValues));

  /// Positive offsets delay comments. Already shifted session data uses zero.
  factory DanmakuHeatmap.fromComments(
    Iterable<DanmakuComment> comments, {
    required int durationMs,
    int offsetMs = 0,
    bool isLive = false,
  }) {
    final bucketMs = math.max(1000, durationMs ~/ 600);
    if (durationMs <= 0 || isLive) {
      return DanmakuHeatmap._(durationMs: durationMs, bucketMs: bucketMs, p95: 1, counts: [], displayValues: []);
    }
    final counts = List<int>.filled((durationMs + bucketMs - 1) ~/ bucketMs, 0);
    for (final comment in comments) {
      final time = comment.timeMs + offsetMs;
      if (time >= 0 && time < durationMs) counts[time ~/ bucketMs]++;
    }
    final sorted = [...counts]..sort();
    final p95 = math.max(1, sorted[((sorted.length - 1) * .95).floor()]);
    final display = List<double>.generate(counts.length, (i) {
      final start = math.max(0, i - 4);
      final end = math.min(counts.length - 1, i + 4);
      var sum = 0;
      for (var k = start; k <= end; k++) {
        sum += counts[k];
      }
      return (sum / (end - start + 1) / p95).clamp(0.0, 1.0);
    });
    return DanmakuHeatmap._(
      durationMs: durationMs,
      bucketMs: bucketMs,
      p95: p95,
      counts: counts,
      displayValues: display,
    );
  }

  bool get hasData => peakIndices.isNotEmpty;

  int bucketAt(int timeMs) => counts.isEmpty ? 0 : (timeMs ~/ bucketMs).clamp(0, counts.length - 1);

  int bucketCenterMs(int index) => math.min(durationMs - 1, index * bucketMs + bucketMs ~/ 2);

  /// Search around the original click; never move the window while searching.
  int? peakNear(int timeMs) {
    if (counts.isEmpty) return null;
    final origin = bucketAt(timeMs);
    if (displayValues[origin] <= .6) return null;
    var best = origin;
    final end = math.min(counts.length - 1, origin + 6);
    for (var i = math.max(0, origin - 6); i <= end; i++) {
      if (displayValues[i] > displayValues[best] ||
          (displayValues[i] == displayValues[best] &&
              ((i - origin).abs() < (best - origin).abs() ||
                  ((i - origin).abs() == (best - origin).abs() && i < best)))) {
        best = i;
      }
    }
    return best;
  }

  int? nearestPeak(int timeMs) {
    int? best;
    for (final index in peakIndices) {
      if (best == null || (bucketCenterMs(index) - timeMs).abs() < (bucketCenterMs(best) - timeMs).abs()) {
        best = index;
      }
    }
    return best;
  }

  static List<int> _peaks(List<double> values) {
    final peaks = <int>[];
    for (var start = 0; start < values.length;) {
      var end = start;
      while (end + 1 < values.length && values[end + 1] == values[start]) {
        end++;
      }
      if (values[start] > 0 &&
          (start == 0 || values[start] > values[start - 1]) &&
          (end == values.length - 1 || values[end] > values[end + 1])) {
        peaks.add((start + end) ~/ 2);
      }
      start = end + 1;
    }
    return peaks;
  }
}

/// Keyed by data inputs only: playback position never invalidates aggregation.
class DanmakuHeatmapCache {
  (Object?, int, int, Object?, int, bool)? _key;
  DanmakuHeatmap? _value;

  DanmakuHeatmap resolve({
    required Iterable<DanmakuComment> comments,
    required Object? itemKey,
    required int dataVersion,
    required int durationMs,
    Object? filterKey,
    int offsetMs = 0,
    bool isLive = false,
  }) {
    final key = (itemKey, dataVersion, durationMs, filterKey, offsetMs, isLive);
    if (_key == key && _value != null) return _value!;
    final value = DanmakuHeatmap.fromComments(comments, durationMs: durationMs, offsetMs: offsetMs, isLive: isLive);
    _key = key;
    return _value = value;
  }
}
