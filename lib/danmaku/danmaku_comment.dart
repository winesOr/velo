/// One timed comment, independent of which file or API it came from.
class DanmakuComment {
  final int timeMs;
  final String text;
  final int color;
  final int mode;

  const DanmakuComment({required this.timeMs, required this.text, this.color = 0xFFFFFF, this.mode = 1});
}
