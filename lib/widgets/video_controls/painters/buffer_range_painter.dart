import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../danmaku/danmaku_heatmap.dart';
import '../../../media/media_source_info.dart';
import '../../../mpv/models.dart';
import '../../../theme/velo_brand.dart';

/// Custom painter that draws the continuous background track, chapter ticks,
/// buffered ranges, skip markers and the danmaku heat curve on the timeline.
class BufferRangePainter extends CustomPainter {
  final List<BufferRange> ranges;
  final Duration duration;
  final List<MediaChapter> chapters;
  final double trackHeight;
  final DanmakuHeatmap? heatmap;
  final bool heatmapEnabled;
  final double heatmapHeight;
  final List<BufferRange> skipRanges;

  BufferRangePainter({
    required this.ranges,
    required this.duration,
    this.chapters = const [],
    this.trackHeight = 8.0,
    this.heatmap,
    this.heatmapEnabled = true,
    this.heatmapHeight = 0,
    this.skipRanges = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    const tickWidth = 1.0;
    final radius = trackHeight / 2;
    final y = heatmapHeight + (size.height - heatmapHeight - trackHeight) / 2;
    final track = RRect.fromRectAndRadius(Rect.fromLTWH(0, y, size.width, trackHeight), Radius.circular(radius));

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final durationMs = duration.inMilliseconds.toDouble();

    final values = heatmap?.displayValues;
    if (durationMs > 0 && heatmapEnabled && heatmap?.hasData == true && values != null && y > 5) {
      final baseline = y - 3;
      final height = baseline - 2;
      final path = Path()..moveTo(0, baseline);
      Offset point(int i) =>
          Offset((heatmap!.bucketCenterMs(i) / durationMs) * size.width, baseline - values[i] * height);
      var previous = point(0);
      path.lineTo(previous.dx, previous.dy);
      for (var i = 1; i < values.length; i++) {
        final current = point(i);
        path.quadraticBezierTo(
          previous.dx,
          previous.dy,
          (previous.dx + current.dx) / 2,
          (previous.dy + current.dy) / 2,
        );
        previous = current;
      }
      path
        ..lineTo(previous.dx, previous.dy)
        ..lineTo(size.width, baseline)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [VeloBrand.heatmapPeak, VeloBrand.heatmapBase],
          ).createShader(Rect.fromLTRB(0, 2, size.width, baseline)),
      );
    }

    canvas.drawRRect(track, bgPaint);

    if (durationMs <= 0) return;

    // Buffer and chapter marks stay inside the rounded track.
    canvas.save();
    canvas.clipRRect(track);

    final bufPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    for (final range in ranges) {
      final bufLeft = (range.start.inMilliseconds / durationMs).clamp(0.0, 1.0) * size.width;
      final bufRight = (range.end.inMilliseconds / durationMs).clamp(0.0, 1.0) * size.width;
      if (bufRight <= bufLeft) continue;
      canvas.drawRect(Rect.fromLTRB(bufLeft, y, bufRight, y + trackHeight), bufPaint);
    }
    // Chapter boundaries are thin ticks on a continuous track, not gaps.
    final tickPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    for (final chapter in chapters) {
      final ms = chapter.startTimeOffset ?? 0;
      if (ms <= 0 || ms >= durationMs) continue;
      final x = ms / durationMs * size.width;
      canvas.drawRect(Rect.fromLTWH(x - tickWidth / 2, y, tickWidth, trackHeight), tickPaint);
    }
    canvas.restore();

    final skipPaint = Paint()..color = const Color(0xD9FFC454);
    for (final range in skipRanges) {
      final left = (range.start.inMilliseconds / durationMs).clamp(0.0, 1.0) * size.width;
      final right = (range.end.inMilliseconds / durationMs).clamp(0.0, 1.0) * size.width;
      if (right <= left) continue;
      // Bottom edge remains visible beneath the Slider's played track.
      canvas.drawRect(Rect.fromLTWH(left, y + trackHeight - 1, right - left, 2), skipPaint);
    }
  }

  @override
  bool shouldRepaint(BufferRangePainter oldDelegate) {
    return oldDelegate.trackHeight != trackHeight ||
        oldDelegate.heatmapHeight != heatmapHeight ||
        oldDelegate.heatmapEnabled != heatmapEnabled ||
        oldDelegate.heatmap != heatmap ||
        !listEquals(oldDelegate.skipRanges, skipRanges) ||
        oldDelegate.duration != duration ||
        !listEquals(oldDelegate.ranges, ranges) ||
        !_chapterSplitsEqual(oldDelegate.chapters, chapters);
  }

  static bool _chapterSplitsEqual(List<MediaChapter> previous, List<MediaChapter> current) {
    if (identical(previous, current)) return true;
    if (previous.length != current.length) return false;
    for (var i = 0; i < previous.length; i++) {
      if (previous[i].startTimeOffset != current[i].startTimeOffset) return false;
    }
    return true;
  }
}
