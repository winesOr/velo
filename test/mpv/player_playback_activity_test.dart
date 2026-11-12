import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/mpv/mpv.dart';
import 'package:plezy/mpv/player/platform/player_android.dart';
import 'package:plezy/services/settings_service.dart';

import '../test_helpers/mock_player_channels.dart';
import '../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
  });

  Future<void> withPlayer(Future<void> Function(_ActivityPlayer player) body) async {
    await withMockPlayerChannels(
      methodChannelName: 'com.plezy/exo_player',
      eventChannelName: 'com.plezy/exo_player/events',
      methodHandler: (call) async {
        if (call.method == 'open') throw PlatformException(code: 'rejected_open');
        return call.method == 'initialize' ? true : null;
      },
      testBody: () async {
        final player = _ActivityPlayer();
        try {
          await body(player);
        } finally {
          await player.dispose();
        }
      },
    );
  }

  test('buffering intent snapshots do not change legacy playback streams', () async {
    await withPlayer((player) async {
      final playing = <bool>[];
      final buffering = <bool>[];
      final completed = <bool>[];
      final activities = <PlayerPlaybackActivity?>[];
      final subscriptions = [
        player.streams.playing.listen(playing.add),
        player.streams.buffering.listen(buffering.add),
        player.streams.completed.listen(completed.add),
        player.streams.playbackActivity.listen(activities.add),
      ];
      player.handlePlayerEvent('start-file', const {'sourceId': 7});
      player.handlePropertyChange('pause', true, sourceId: 7);
      player.handlePropertyChange('paused-for-cache', true, sourceId: 7);
      player.handlePlayerEvent('playback-activity', _activity(7));
      player.handlePlayerEvent('playback-activity', _activity(7, requested: false));
      await Future<void>.delayed(Duration.zero);
      expect(playing, [false]);
      expect(buffering, [true]);
      expect(completed, isEmpty);
      expect(activities.map((activity) => activity?.playWhenReady), [true, false]);
      expect(player.state.playing, isFalse);
      expect(player.state.buffering, isTrue);
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    });
  });

  test('only well-formed snapshots for the active generation are accepted', () async {
    await withPlayer((player) async {
      player.handlePlayerEvent('start-file', const {'sourceId': 9});
      for (final payload in [
        _activity(8),
        {..._activity(9)}..remove('sourceId'),
        {..._activity(9), 'sourceId': 9.5},
        {..._activity(9), 'phase': 'unknown'},
        {..._activity(9), 'playWhenReady': 'true'},
      ]) {
        player.handlePlayerEvent('playback-activity', payload);
        expect(player.state.playbackActivity, isNull);
      }
      player.handlePlayerEvent('playback-activity', _activity(9));
      expect(player.state.playbackActivity?.phase, PlayerPlaybackPhase.buffering);
      player.handlePlayerEvent('end-file', const {'sourceId': 9, 'reason': 'stop'});
      player.handlePlayerEvent('playback-activity', _activity(9, requested: false));
      expect(player.state.playbackActivity?.playWhenReady, isTrue, reason: 'a retired source cannot mutate state');
    });
  });

  test('open reset clears a snapshot and a rejected replacement restores it', () async {
    await withPlayer((player) async {
      player.handlePlayerEvent('start-file', const {'sourceId': 3});
      player.handlePlayerEvent('playback-activity', _activity(3));
      final snapshot = player.state;
      player.resetForTest();
      expect(player.state.playbackActivity, isNull);
      player.handlePlayerEvent('playback-activity', _activity(3, requested: false));
      expect(player.state.playbackActivity, isNull);
      player.restoreForTest(snapshot);
      expect(player.state.playbackActivity, snapshot.playbackActivity);
      await expectLater(player.open(Media('https://example.invalid/replacement')), throwsA(isA<PlatformException>()));
      expect(player.state.playbackActivity, snapshot.playbackActivity);
    });
  });

  test('mpv fallback clears the Exo snapshot and ignores late Exo activity', () async {
    await withPlayer((player) async {
      player.handlePlayerEvent('start-file', const {'sourceId': 5});
      player.handlePlayerEvent('playback-activity', _activity(5));
      player.handlePlayerEvent('backend-switched', null);
      expect(player.state.playbackActivity, isNull);
      player.handlePlayerEvent('playback-activity', _activity(5));
      expect(player.state.playbackActivity, isNull);
      player.handlePropertyChange('pause', false, sourceId: 5);
      expect(player.state.isActive, isTrue);
    });
  });

  test('an EOF seek can resume activity within the same MediaItem generation', () async {
    await withPlayer((player) async {
      player.handlePlayerEvent('start-file', const {'sourceId': 6});
      player.handlePlayerEvent('file-loaded', const {'sourceId': 6});
      player.handlePlayerEvent('playback-activity', {..._activity(6), 'phase': 'ended'});
      player.handlePlayerEvent('end-file', const {'sourceId': 6, 'reason': 'eof'});
      expect(player.state.completed, isTrue);
      player.handlePlayerEvent('playback-activity', _activity(6));
      expect(player.state.playbackActivity?.phase, PlayerPlaybackPhase.buffering);
      expect(player.state.completed, isTrue, reason: 'activity never changes the existing completion contract');
      player.resetForTest();
      player.handlePlayerEvent('playback-activity', _activity(6));
      expect(player.state.playbackActivity, isNull, reason: 'a replacement retires the old activity identity');
    });
  });

  test('copyWith can preserve or explicitly clear optional activity', () {
    const state = PlayerState(
      playbackActivity: PlayerPlaybackActivity(phase: PlayerPlaybackPhase.ready, playWhenReady: true),
    );
    expect(state.copyWith(volume: 50).playbackActivity, state.playbackActivity);
    expect(state.copyWith(clearPlaybackActivity: true).playbackActivity, isNull);
    expect(const PlayerState().playbackActivity, isNull);
  });
}

Map<String, Object> _activity(int sourceId, {bool requested = true}) => {
  'sourceId': sourceId,
  'phase': 'buffering',
  'playWhenReady': requested,
};

class _ActivityPlayer extends PlayerAndroid {
  void resetForTest() => resetPlaybackProgress(Duration.zero);
  void restoreForTest(PlayerState state) => restorePlaybackProgress(state);
}
