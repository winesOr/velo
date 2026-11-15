import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_source_info.dart';
import 'package:plezy/mpv/mpv.dart';
import 'package:plezy/services/playback_subtitle_resolver.dart';
import 'package:plezy/widgets/video_controls/sheets/player_settings_controls.dart';
import 'package:plezy/widgets/overlay_sheet.dart';
import 'package:plezy/widgets/video_controls/models/track_controls_state.dart';
import 'package:plezy/widgets/video_controls/sheets/base_video_control_sheet.dart';
import 'package:plezy/widgets/video_controls/sheets/track_sheet.dart';

import '../test_helpers/theme.dart';

Future<void> _pumpDrawer(
  WidgetTester tester,
  _SelectorPlayer player,
  TrackControlsState state,
  TrackSheetKind kind, {
  ValueListenable<TrackControlsState>? stateUpdates,
}) async {
  LocaleSettings.setLocaleSync(AppLocale.en);
  addTearDown(player.closeTestStreams);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [testMonoTokens]),
      home: OverlaySheetHost(
        child: Scaffold(
          body: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: EmbeddedVideoControlSheet(
                child: stateUpdates == null
                    ? TrackSheet(player: player, trackControlsState: state, only: kind)
                    : ValueListenableBuilder<TrackControlsState>(
                        valueListenable: stateUpdates,
                        builder: (context, state, _) =>
                            TrackSheet(player: player, trackControlsState: state, only: kind),
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('source subtitle zero and Off remain separate menu choices', (tester) async {
    final player = _SelectorPlayer();
    final changes = <PlaybackSourceSubtitleChoice>[];
    await _pumpDrawer(
      tester,
      player,
      TrackControlsState(
        isTranscoding: true,
        sourceSubtitleTracks: [MediaSubtitleTrack(id: 0, title: 'Stream zero', selected: false, forced: false)],
        selectedSubtitleChoice: const PlaybackSourceSubtitleChoice.off(),
        onSwitchSubtitle: (choice) async => changes.add(choice),
        subtitleSearchSupported: false,
      ),
      TrackSheetKind.subtitles,
    );
    await tester.tap(find.text('Stream zero'));
    await tester.pumpAndSettle();
    expect(changes, [const PlaybackSourceSubtitleChoice.source(0)]);
    await tester.tap(find.text(t.common.off).first);
    await tester.pumpAndSettle();
    expect(changes.last, const PlaybackSourceSubtitleChoice.off());
  });

  testWidgets('source audio selection keeps server IDs and recovers after a failed request', (tester) async {
    final player = _SelectorPlayer();
    final first = Completer<void>();
    final changes = <int>[];
    await _pumpDrawer(
      tester,
      player,
      TrackControlsState(
        isTranscoding: true,
        sourceAudioTracks: [
          MediaAudioTrack(id: 0, title: 'Stereo', selected: true),
          MediaAudioTrack(id: 42, title: 'Commentary', selected: false),
        ],
        selectedAudioStreamId: 0,
        onSwitchAudioStreamId: (id) {
          changes.add(id);
          return changes.length == 1 ? first.future : Future.value();
        },
        subtitleSearchSupported: false,
      ),
      TrackSheetKind.audio,
    );
    await tester.tap(find.text('Commentary'));
    await tester.pump();
    expect(changes, [42]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Commentary'));
    await tester.pump();
    expect(changes, [42]);
    first.completeError(StateError('test request failure'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Commentary'));
    await tester.pumpAndSettle();
    expect(changes, [42, 42]);
    expect(player.audioChanges, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native audio menu uses player track IDs and not source indexes', (tester) async {
    final player = _SelectorPlayer(
      tracks: const Tracks(
        audio: [
          AudioTrack(id: 'native-7', title: 'Stereo'),
          AudioTrack(id: 'native-19', title: 'Surround'),
        ],
      ),
      selection: const TrackSelection(audio: AudioTrack(id: 'native-7')),
    );
    await _pumpDrawer(tester, player, const TrackControlsState(subtitleSearchSupported: false), TrackSheetKind.audio);
    await tester.tap(find.text('Surround'));
    await tester.pumpAndSettle();
    expect(player.audioChanges, ['native-19']);
  });

  testWidgets('native subtitle menu retains the chosen ID when discovery reorders tracks', (tester) async {
    const english = SubtitleTrack(id: 's1', title: 'English');
    const french = SubtitleTrack(id: 's2', title: 'French');
    final player = _SelectorPlayer(tracks: const Tracks(subtitle: [english, french]));
    await _pumpDrawer(
      tester,
      player,
      const TrackControlsState(subtitleSearchSupported: false),
      TrackSheetKind.subtitles,
    );
    player.updateTracks(const Tracks(subtitle: [french, english]));
    await tester.pump();
    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();
    expect(player.subtitleChanges, ['primary:s2']);
  });

  testWidgets('a removed native subtitle option is ignored instead of selecting its replacement', (tester) async {
    const english = SubtitleTrack(id: 's1', title: 'English');
    const french = SubtitleTrack(id: 's2', title: 'French');
    const spanish = SubtitleTrack(id: 's3', title: 'Spanish');
    final player = _SelectorPlayer(tracks: const Tracks(subtitle: [english, french]));
    await _pumpDrawer(
      tester,
      player,
      const TrackControlsState(subtitleSearchSupported: false),
      TrackSheetKind.subtitles,
    );
    player.updateTracks(const Tracks(subtitle: [english, spanish]));
    await tester.pump();
    expect(find.text('French'), findsNothing);
    expect(player.subtitleChanges, isEmpty);
  });

  testWidgets('source subtitle menu keeps stream IDs across reorder and ignores removed choices', (tester) async {
    final player = _SelectorPlayer();
    final changes = <PlaybackSourceSubtitleChoice>[];
    final first = MediaSubtitleTrack(id: 0, title: 'First', selected: false, forced: false);
    final second = MediaSubtitleTrack(id: 42, title: 'Second', selected: false, forced: false);
    TrackControlsState stateFor(List<MediaSubtitleTrack> tracks) => TrackControlsState(
      isTranscoding: true,
      sourceSubtitleTracks: tracks,
      selectedSubtitleChoice: const PlaybackSourceSubtitleChoice.off(),
      onSwitchSubtitle: (choice) async => changes.add(choice),
      subtitleSearchSupported: false,
    );
    final states = ValueNotifier(stateFor([first, second]));
    addTearDown(states.dispose);
    await _pumpDrawer(tester, player, states.value, TrackSheetKind.subtitles, stateUpdates: states);
    states.value = stateFor([second, first]);
    await tester.pump();
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(changes, [const PlaybackSourceSubtitleChoice.source(42)]);
    states.value = stateFor([first]);
    await tester.pump();
    expect(find.text('Second'), findsNothing);
    expect(changes, [const PlaybackSourceSubtitleChoice.source(42)]);
  });

  testWidgets('primary and secondary selectors remain mutually exclusive and primary Off clears both', (tester) async {
    const primary = SubtitleTrack(id: 's1', title: 'English');
    const secondary = SubtitleTrack(id: 's2', title: 'French');
    final player = _SelectorPlayer(
      tracks: const Tracks(subtitle: [primary, secondary]),
      selection: const TrackSelection(subtitle: primary, secondarySubtitle: secondary),
      supportsSecondarySubtitles: true,
    );
    await _pumpDrawer(
      tester,
      player,
      const TrackControlsState(subtitleSearchSupported: false),
      TrackSheetKind.subtitles,
    );
    final rows = tester.widgetList<PlayerDrawerChoice>(find.byType(PlayerDrawerChoice)).toList();
    expect(rows.where((row) => row.label == 'English').length, 1);
    expect(rows.where((row) => row.label == 'French').length, 2);
    player.failPrimary = true;
    await tester.tap(find.text(t.common.off).first);
    await tester.pumpAndSettle();
    expect(player.subtitleChanges, ['secondary:no', 'primary:no', 'secondary:s2']);
    player.failPrimary = false;
    player.subtitleChanges.clear();
    await tester.tap(find.text(t.common.off).first);
    await tester.pumpAndSettle();
    expect(player.subtitleChanges, ['secondary:no', 'primary:no']);
  });
}

class _SelectorPlayer implements Player {
  _SelectorPlayer({
    Tracks tracks = const Tracks(),
    TrackSelection selection = const TrackSelection(),
    this.supportsSecondarySubtitles = false,
  }) : state = PlayerState(tracks: tracks, track: selection);

  bool failPrimary = false;
  final List<String> audioChanges = [];
  final List<String> subtitleChanges = [];
  final _trackUpdates = StreamController<Tracks>.broadcast(sync: true);

  void updateTracks(Tracks tracks) => _trackUpdates.add(tracks);
  Future<void> closeTestStreams() => _trackUpdates.close();

  @override
  final PlayerState state;
  @override
  final bool supportsSecondarySubtitles;
  @override
  late final streams = PlayerStreams(
    playing: const Stream.empty(),
    completed: const Stream.empty(),
    buffering: const Stream.empty(),
    position: const Stream.empty(),
    duration: const Stream.empty(),
    seekable: const Stream.empty(),
    buffer: const Stream.empty(),
    volume: const Stream.empty(),
    rate: const Stream.empty(),
    tracks: _trackUpdates.stream,
    track: const Stream.empty(),
    log: const Stream.empty(),
    error: const Stream.empty(),
    audioDevice: const Stream.empty(),
    audioDevices: const Stream.empty(),
    bufferRanges: const Stream.empty(),
    playbackRestart: const Stream.empty(),
    backendSwitched: const Stream.empty(),
  );

  @override
  Future<void> selectAudioTrack(AudioTrack track) async => audioChanges.add(track.id);
  @override
  Future<void> selectSubtitleTrack(SubtitleTrack track) async {
    subtitleChanges.add('primary:${track.id}');
    if (failPrimary) throw StateError('primary failed');
  }

  @override
  Future<void> selectSecondarySubtitleTrack(SubtitleTrack track) async => subtitleChanges.add('secondary:${track.id}');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
