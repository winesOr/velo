import 'danmaku_comment.dart';

/// Filters sorted raw data without destroying it. A suppressed duplicate still
/// extends the rolling window, so a continuous repeated burst keeps its first item.
List<DanmakuComment> filterDanmaku(
  List<DanmakuComment> comments, {
  required List<String> blockedKeywords,
  required bool mergeDuplicates,
}) {
  final previous = <(int, String), int>{};
  return comments
      .where((comment) {
        if (blockedKeywords.any(comment.text.contains)) return false;
        if (!mergeDuplicates) return true;
        final key = (comment.mode, comment.text.trim());
        final last = previous[key];
        previous[key] = comment.timeMs;
        return last == null || comment.timeMs - last > 1000;
      })
      .toList(growable: false);
}
