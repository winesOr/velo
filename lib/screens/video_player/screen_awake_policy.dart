import '../../mpv/player/player_playback_activity.dart';
import '../../mpv/player/player_state.dart';

/// Screen-awake policy, independent of progress reporting and playback chrome.
bool shouldKeepPlaybackScreenAwake({
  required PlayerState state,
  required bool hasCurrentPlayback,
  required bool visible,
  required bool pipActive,
  required bool fatalError,
  required bool automotiveAllowed,
  required bool tvBackgroundSuspended,
  bool openingWithPlayIntent = false,
}) {
  if (!hasCurrentPlayback || fatalError || !automotiveAllowed || tvBackgroundSuspended || state.completed) {
    return false;
  }
  if (!visible && !pipActive) return false;

  final activity = state.playbackActivity;
  if (activity == null) return openingWithPlayIntent || state.isActive;
  return switch (activity.phase) {
    PlayerPlaybackPhase.idle => openingWithPlayIntent,
    PlayerPlaybackPhase.buffering || PlayerPlaybackPhase.ready => activity.playWhenReady,
    PlayerPlaybackPhase.ended => false,
  };
}
