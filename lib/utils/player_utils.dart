import '../mpv/mpv.dart';

const restartBeforePreviousItemThreshold = Duration(seconds: 3);
const userSeekEndGuard = Duration(seconds: 1);

bool shouldRestartBeforePreviousItem(Duration position) {
  return position > restartBeforePreviousItemThreshold;
}

Duration clampSeekPosition(Player player, Duration position) {
  final duration = player.state.duration;
  if (position.isNegative) return Duration.zero;
  if (duration > Duration.zero && position > duration) return duration;
  return position;
}

Duration clampUserSeekPosition(Player player, Duration position) {
  final duration = player.state.duration;
  if (position.isNegative) return Duration.zero;
  if (duration <= Duration.zero) return position;

  final maxTarget = duration - userSeekEndGuard;
  if (maxTarget <= Duration.zero) return Duration.zero;
  if (position > maxTarget) return maxTarget;
  return position;
}
