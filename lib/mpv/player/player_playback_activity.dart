/// An optional backend snapshot for policies that need playback intent.
///
/// This does not replace the existing playing, buffering, or completion streams.
enum PlayerPlaybackPhase { idle, buffering, ready, ended }

class PlayerPlaybackActivity {
  final PlayerPlaybackPhase phase;
  final bool playWhenReady;

  const PlayerPlaybackActivity({required this.phase, required this.playWhenReady});

  @override
  bool operator ==(Object other) =>
      other is PlayerPlaybackActivity && other.phase == phase && other.playWhenReady == playWhenReady;

  @override
  int get hashCode => Object.hash(phase, playWhenReady);
}
