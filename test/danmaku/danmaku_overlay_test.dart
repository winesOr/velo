import 'dart:async';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/danmaku/danmaku_comment.dart';
import 'package:plezy/danmaku/danmaku_overlay.dart';
import 'package:plezy/danmaku/danmaku_session.dart';
import 'package:plezy/danmaku/danmaku_settings_repository.dart';
import 'package:plezy/mpv/mpv.dart';

import '../test_helpers/player_streams.dart';

class _ClockPlayer implements Player {
  final positions = StreamController<Duration>.broadcast(sync: true);
  final playing = StreamController<bool>.broadcast(sync: true);
  final jumps = StreamController<Duration?>.broadcast(sync: true);
  final buffering = StreamController<bool>.broadcast(sync: true);
  final rates = StreamController<double>.broadcast(sync: true);
  PlayerState _state;
  _ClockPlayer({bool initiallyPlaying = true}) : _state = PlayerState(playing: initiallyPlaying);

  @override
  PlayerState get state => _state;
  @override
  Duration get currentPosition => _state.position;
  @override
  late final PlayerStreams streams = emptyPlayerStreams(
    position: positions.stream,
    playing: playing.stream,
    playheadJump: jumps.stream,
    buffering: buffering.stream,
    rate: rates.stream,
  );

  void tick(int milliseconds) {
    _state = _state.copyWith(position: Duration(milliseconds: milliseconds));
    positions.add(currentPosition);
  }

  void setPlaying(bool value) {
    _state = _state.copyWith(playing: value);
    playing.add(value);
  }

  void jump(int milliseconds) {
    _state = _state.copyWith(position: Duration(milliseconds: milliseconds));
    jumps.add(currentPosition);
  }

  void setBuffering(bool value) {
    _state = _state.copyWith(buffering: value);
    buffering.add(value);
  }

  void publishRate(double value) {
    _state = _state.copyWith(rate: value);
    rates.add(value);
  }

  Future<void> close() async {
    await positions.close();
    await playing.close();
    await jumps.close();
    await buffering.close();
    await rates.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CanvasRecorder {
  final bool trackItems;
  _CanvasRecorder({this.trackItems = false});
  final scroll = <DanmakuItem<dynamic>>[];
  final fixed = <DanmakuItem<dynamic>>[];
  DanmakuOption option = const DanmakuOption();
  final added = <String>[];
  var clears = 0;
  var paused = false;
  late final controller = DanmakuController<dynamic>(
    addDanmaku: (item) {
      added.add(item.text);
      if (trackItems) {
        (item.type == DanmakuItemType.scroll ? scroll : fixed).add(
          DanmakuItem(content: item, width: 80, height: 22, xPosition: 800),
        );
      }
    },
    updateOption: (value) => option = value,
    pause: () => paused = true,
    resume: () => paused = false,
    clear: () {
      clears++;
      scroll.clear();
      fixed.clear();
    },
    getOption: () => option,
    isRunning: () => !paused,
    findDanmaku: (_) => [],
    findSingleDanmaku: (_) => null,
    getViewWidth: () => 800,
    getViewHeight: () => 600,
    scrollDanmaku: scroll,
    staticDanmaku: fixed,
    specialDanmaku: [],
  );
}

void main() {
  DanmakuSession makeSession() => DanmakuSession.forTesting(
    repository: DanmakuSettingsRepository(
      read: () async => null,
      write: (_) async {},
      protect: (value) async => value,
      reveal: (value) async => value,
    ),
  );

  Future<_CanvasRecorder> mount(WidgetTester tester, _ClockPlayer player, DanmakuSession session) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DanmakuOverlay(player: player, session: session),
      ),
    );
    final recorder = _CanvasRecorder();
    // Exercise the overlay's real canvas-controller contract without depending
    // on the package's randomized lane assignment or animated pixel output.
    tester
        .widget<DanmakuScreen>(find.byWidgetPredicate((widget) => widget is DanmakuScreen))
        .createdController(recorder.controller);
    addTearDown(player.close);
    return recorder;
  }

  testWidgets('coarse native updates emit comments on their frames without early batches', (tester) async {
    final session = makeSession();
    await session.initialize();
    session.load(const [
      DanmakuComment(timeMs: 1000, text: 'one'),
      DanmakuComment(timeMs: 1200, text: 'two'),
      DanmakuComment(timeMs: 1400, text: 'three'),
      DanmakuComment(timeMs: 1600, text: 'four'),
      DanmakuComment(timeMs: 4000, text: 'late'),
    ], sourceLabel: 'local');
    final player = _ClockPlayer();
    final canvas = await mount(tester, player, session);
    player.tick(1000);
    expect(canvas.added, ['one']);
    await tester.pump(const Duration(milliseconds: 100));
    player.tick(1000);
    expect(canvas.added, ['one']);
    await tester.pump(const Duration(milliseconds: 100));
    expect(canvas.added, ['one', 'two']);
    player.setPlaying(false);
    await tester.pump(const Duration(seconds: 1));
    expect(canvas.added, ['one', 'two']);
    player.setPlaying(true);
    await tester.pump();
    player.publishRate(2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(canvas.added, ['one', 'two', 'three']);
    player.setBuffering(true);
    await tester.pump(const Duration(seconds: 1));
    expect(canvas.added, ['one', 'two', 'three']);
    player.setBuffering(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(canvas.added, ['one', 'two', 'three', 'four']);
    await tester.pump(const Duration(seconds: 3));
    expect(canvas.added, isNot(contains('late')), reason: 'a stalled native clock cannot extrapolate indefinitely');
    player.jump(4000);
    player.tick(4000);
    expect(canvas.added.last, 'late');
    expect(canvas.added.where((value) => value == 'late'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dense data obeys kind and total caps, with disjoint rows and unchanged statistics', (tester) async {
    final session = makeSession();
    await session.initialize();
    await session.updateStyle(scrollLines: 2, topLines: 1, bottomLines: 1, maxOnScreen: 4, speed: 2);
    session.load([
      for (var i = 0; i < 20; i++) DanmakuComment(timeMs: 1000, text: 'scroll$i'),
      for (var i = 0; i < 20; i++) DanmakuComment(timeMs: 1000, text: 'top$i', mode: 5),
      for (var i = 0; i < 20; i++) DanmakuComment(timeMs: 1000, text: 'bottom$i', mode: 4),
    ], sourceLabel: 'local');
    final player = _ClockPlayer();
    await mount(tester, player, session);
    final canvas = _CanvasRecorder(trackItems: true);
    tester
        .widget<DanmakuScreen>(find.byWidgetPredicate((w) => w is DanmakuScreen))
        .createdController(canvas.controller);
    player.tick(1000);
    expect(canvas.scroll, hasLength(2));
    expect(canvas.fixed.where((item) => item.content.type == DanmakuItemType.top), hasLength(1));
    expect(canvas.fixed.where((item) => item.content.type == DanmakuItemType.bottom), hasLength(1));
    expect(canvas.option.duration, 4);
    expect(canvas.option.massiveMode, isFalse);
    expect(session.comments, hasLength(60));
    final rects = [...canvas.scroll, ...canvas.fixed]
        .map(
          (item) => Rect.fromLTWH(
            0,
            item.content.type == DanmakuItemType.bottom ? 600 - item.yPosition - item.height : item.yPosition,
            800,
            item.height,
          ),
        )
        .toList();
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }
    await session.updateStyle(maxOnScreen: 1);
    expect(canvas.scroll, isEmpty);
    expect(canvas.fixed, isEmpty);
    player.jump(1000);
    player.tick(1000);
    expect(canvas.scroll.length + canvas.fixed.length, 1);
    expect(session.comments, hasLength(60));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('overlay consumes positive delay once, and offset updates rebuild its clock cursor', (tester) async {
    final session = makeSession();
    await session.initialize();
    session.load(const [DanmakuComment(timeMs: 1000, text: 'delayed')], sourceLabel: 'local');
    await session.updateStyle(offsetMs: 1500);
    final player = _ClockPlayer();
    final canvas = await mount(tester, player, session);
    player.tick(1000);
    expect(canvas.added, isEmpty);
    player.tick(2000);
    expect(canvas.added, isEmpty);
    player.tick(2500);
    player.tick(2500);
    expect(canvas.added, ['delayed']);
    final clears = canvas.clears;
    await session.updateStyle(offsetMs: -500);
    expect(canvas.clears, greaterThan(clears));
    player.jump(500);
    player.tick(500);
    player.tick(500);
    expect(canvas.added, ['delayed', 'delayed']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('paused stream and resume do not duplicate an already emitted comment', (tester) async {
    final session = makeSession();
    await session.initialize();
    session.load(const [
      DanmakuComment(timeMs: 1000, text: 'one'),
      DanmakuComment(timeMs: 2000, text: 'two'),
    ], sourceLabel: 'local');
    final player = _ClockPlayer(initiallyPlaying: false);
    final canvas = await mount(tester, player, session);
    expect(canvas.paused, isTrue);
    player.tick(1000);
    expect(canvas.added, isEmpty);
    player.setPlaying(true);
    player.tick(1000);
    expect(canvas.added, ['one']);
    player.setPlaying(false);
    player.tick(1000);
    player.setPlaying(true);
    player.tick(1000);
    expect(canvas.added, ['one']);
    player.tick(2000);
    expect(canvas.added, ['one', 'two']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('short backward and forward seeks clear old canvas and replay only the target window', (tester) async {
    final session = makeSession();
    await session.initialize();
    session.load(const [
      DanmakuComment(timeMs: 1000, text: 'one'),
      DanmakuComment(timeMs: 2000, text: 'two'),
      DanmakuComment(timeMs: 3000, text: 'three'),
    ], sourceLabel: 'local');
    final player = _ClockPlayer();
    final canvas = await mount(tester, player, session);
    player.tick(1000);
    player.tick(2000);
    expect(canvas.added, ['one', 'two']);
    final clears = canvas.clears;
    player.jump(1000);
    expect(canvas.clears, greaterThan(clears));
    player.tick(1000);
    player.tick(1000);
    expect(canvas.added, ['one', 'two', 'one']);
    player.jump(3000);
    player.tick(3000);
    player.tick(3000);
    expect(canvas.added, ['one', 'two', 'one', 'three']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
