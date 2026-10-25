import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/mpv/mpv.dart';
import 'package:plezy/watch_together/providers/watch_together_provider.dart';
import 'package:plezy/widgets/video_controls/widgets/player_track_summary.dart';
import 'package:provider/provider.dart';

import '../test_helpers/watch_together_fakes.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets('summaries follow actual track changes and playback rate', (tester) async {
    final player = _SummaryPlayer();
    addTearDown(player.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlayerTrackSummary(player: player)),
      ),
    );
    expect(find.textContaining('English'), findsOneWidget);
    expect(find.text(t.common.off), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    player.select(
      const TrackSelection(
        audio: AudioTrack(id: '2', language: 'jpn'),
        subtitle: SubtitleTrack(id: '3', title: 'Commentary'),
      ),
    );
    player.emitRate(1.5);
    await tester.pump();
    expect(find.textContaining('Japanese'), findsOneWidget);
    expect(find.textContaining('Commentary'), findsOneWidget);
    expect(find.text(t.common.off), findsNothing);
    expect(find.text('1.5x'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('room speed remains stable during synchronization nudges on a narrow large-text HUD', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = _SummaryPlayer();
    final room = _RoomRate();
    addTearDown(player.dispose);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<WatchTogetherProvider>.value(
        value: room,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(body: PlayerTrackSummary(player: player)),
        ),
      ),
    );
    player.emitRate(1.537);
    await tester.pump();
    expect(find.text('1.5x'), findsOneWidget);
    expect(find.textContaining('1.54'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _RoomRate extends WatchTogetherProvider {
  @override
  bool get syncOwnsRate => true;
  @override
  double? get roomRate => 1.5;
}

class _SummaryPlayer extends FakeSyncPlayer {
  final _selectionEvents = StreamController<TrackSelection>.broadcast();
  var _selection = const TrackSelection(
    audio: AudioTrack(id: '1', language: 'eng'),
    subtitle: SubtitleTrack.off,
  );
  static const _tracks = Tracks(
    audio: [
      AudioTrack(id: '1', language: 'eng'),
      AudioTrack(id: '2', language: 'jpn'),
    ],
    subtitle: [SubtitleTrack(id: '3', title: 'Commentary')],
  );

  void select(TrackSelection selection) {
    _selection = selection;
    _selectionEvents.add(selection);
  }

  @override
  PlayerState get state => super.state.copyWith(track: _selection, tracks: _tracks);

  @override
  PlayerStreams get streams {
    final base = super.streams;
    return PlayerStreams(
      playing: base.playing,
      completed: base.completed,
      buffering: base.buffering,
      position: base.position,
      duration: base.duration,
      seekable: base.seekable,
      buffer: base.buffer,
      volume: base.volume,
      rate: base.rate,
      tracks: base.tracks,
      track: _selectionEvents.stream,
      log: base.log,
      error: base.error,
      audioDevice: base.audioDevice,
      audioDevices: base.audioDevices,
      bufferRanges: base.bufferRanges,
      playbackRestart: base.playbackRestart,
      backendSwitched: base.backendSwitched,
    );
  }

  @override
  Future<void> dispose({bool preserveDisplayMode = false}) async {
    await _selectionEvents.close();
    await super.dispose();
  }
}
