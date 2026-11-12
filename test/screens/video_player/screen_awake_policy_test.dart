import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/mpv/mpv.dart';
import 'package:plezy/screens/video_player/screen_awake_policy.dart';

void main() {
  for (final phase in PlayerPlaybackPhase.values) {
    for (final requested in [false, true]) {
      for (final visibility in ['foreground', 'background', 'pip']) {
        for (final fatal in [false, true]) {
          test('$phase requested=$requested $visibility fatal=$fatal', () {
            final state = PlayerState(
              // A stale legacy true must not overrule an authoritative snapshot.
              playing: true,
              playbackActivity: PlayerPlaybackActivity(phase: phase, playWhenReady: requested),
            );
            final expected =
                !fatal &&
                visibility != 'background' &&
                requested &&
                (phase == PlayerPlaybackPhase.buffering || phase == PlayerPlaybackPhase.ready);
            expect(
              shouldKeepPlaybackScreenAwake(
                state: state,
                hasCurrentPlayback: true,
                visible: visibility == 'foreground',
                pipActive: visibility == 'pip',
                fatalError: fatal,
                automotiveAllowed: true,
                tvBackgroundSuspended: false,
              ),
              expected,
            );
          });
        }
      }
    }
  }

  test('invalid session, completion, automotive, and TV suspension override PiP and opening', () {
    for (final blocker in ['session', 'completed', 'automotive', 'tv', 'fatal']) {
      expect(
        shouldKeepPlaybackScreenAwake(
          state: PlayerState(playing: true, completed: blocker == 'completed'),
          hasCurrentPlayback: blocker != 'session',
          visible: true,
          pipActive: true,
          fatalError: blocker == 'fatal',
          automotiveAllowed: blocker != 'automotive',
          tvBackgroundSuspended: blocker == 'tv',
          openingWithPlayIntent: true,
        ),
        isFalse,
        reason: blocker,
      );
    }
  });

  test('legacy mpv buffering retains playing intent and paused buffering does not', () {
    expect(_visible(const PlayerState(playing: true, buffering: true)), isTrue);
    expect(_visible(const PlayerState(playing: false, buffering: true)), isFalse);
    expect(_visible(const PlayerState(playing: true, completed: true)), isFalse);
  });

  test('the existing bounded opening hold ends when the caller settles its attempt', () {
    const state = PlayerState(
      playbackActivity: PlayerPlaybackActivity(phase: PlayerPlaybackPhase.idle, playWhenReady: true),
    );
    expect(_visible(state, opening: true), isTrue);
    expect(_visible(state), isFalse);
    expect(
      _visible(
        const PlayerState(
          playbackActivity: PlayerPlaybackActivity(phase: PlayerPlaybackPhase.ended, playWhenReady: true),
        ),
        opening: true,
      ),
      isFalse,
    );
  });

  test('ready playback intent survives temporary output suppression', () {
    expect(
      _visible(
        const PlayerState(
          playing: false,
          playbackActivity: PlayerPlaybackActivity(phase: PlayerPlaybackPhase.ready, playWhenReady: true),
        ),
      ),
      isTrue,
    );
  });
}

bool _visible(PlayerState state, {bool opening = false}) => shouldKeepPlaybackScreenAwake(
  state: state,
  hasCurrentPlayback: true,
  visible: true,
  pipActive: false,
  fatalError: false,
  automotiveAllowed: true,
  tvBackgroundSuspended: false,
  openingWithPlayIntent: opening,
);
