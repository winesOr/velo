import 'dart:async';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:canvas_danmaku/scroll_danmaku_painter.dart';
import 'package:canvas_danmaku/static_danmaku_painter.dart';
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
  PlayerState _state = const PlayerState(playing: true);

  @override
  PlayerState get state => _state;
  @override
  Duration get currentPosition => _state.position;
  @override
  late final streams = emptyPlayerStreams(
    position: positions.stream,
    playing: playing.stream,
    playheadJump: jumps.stream,
  );

  void tick(int ms) {
    _state = _state.copyWith(position: Duration(milliseconds: ms));
    positions.add(currentPosition);
  }

  void setPaused(bool paused) {
    _state = _state.copyWith(playing: !paused);
    playing.add(!paused);
  }

  Future<void> close() async {
    await positions.close();
    await playing.close();
    await jumps.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DanmakuItem> _scroll(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<ScrollDanmakuPainter>()
    .single
    .danmakuItems;

List<DanmakuItem> _fixed(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<StaticDanmakuPainter>()
    .single
    .danmakuItems;

void _expectDisjoint(WidgetTester tester, double height) {
  final rectangles = [..._scroll(tester), ..._fixed(tester)]
      .map(
        (item) => Rect.fromLTWH(
          0,
          item.content.type == DanmakuItemType.bottom ? height - item.yPosition - item.height : item.yPosition,
          800,
          item.height,
        ),
      )
      .toList();
  for (var i = 0; i < rectangles.length; i++) {
    expect(rectangles[i].top, greaterThanOrEqualTo(0));
    expect(rectangles[i].bottom, lessThan(height));
    for (var j = i + 1; j < rectangles.length; j++) {
      expect(rectangles[i].overlaps(rectangles[j]), isFalse);
    }
  }
}

void main() {
  Future<({DanmakuSession session, _ClockPlayer player})> mount(WidgetTester tester) async {
    final session = DanmakuSession.forTesting(
      repository: DanmakuSettingsRepository(
        read: () async => null,
        write: (_) async {},
        protect: (v) async => v,
        reveal: (v) async => v,
      ),
    );
    await session.initialize();
    await session.updateStyle(scrollLines: 3, topLines: 2, bottomLines: 2, maxOnScreen: 7, speed: 2);
    session.load([
      for (var i = 0; i < 200; i++) DanmakuComment(timeMs: 1000, text: 'scroll $i'),
      for (var i = 0; i < 200; i++) DanmakuComment(timeMs: 1000, text: 'top $i', mode: 5),
      for (var i = 0; i < 200; i++) DanmakuComment(timeMs: 1000, text: 'bottom $i', mode: 4),
    ], sourceLabel: 'local');
    final player = _ClockPlayer();
    addTearDown(player.close);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // Mount production directly: no substituted controller or second canvas.
    await tester.pumpWidget(
      MaterialApp(
        home: DanmakuOverlay(player: player, session: session),
      ),
    );
    await tester.pump();
    return (session: session, player: player);
  }

  testWidgets('one top lane admits following comments while its previous comments remain visible', (tester) async {
    final fixture = await mount(tester);
    await fixture.session.updateStyle(scrollLines: 1, topLines: 0, bottomLines: 0, maxOnScreen: 10);
    fixture.session.load(const [
      DanmakuComment(timeMs: 1000, text: 'a'),
      DanmakuComment(timeMs: 1400, text: 'b'),
      DanmakuComment(timeMs: 1800, text: 'c'),
    ], sourceLabel: 'local');
    fixture.player.tick(1000);
    await tester.pump();
    expect(_scroll(tester).map((item) => item.content.text), ['a']);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final items = _scroll(tester);
    expect(items.map((item) => item.content.text), ['a', 'b', 'c']);
    expect(items.map((item) => item.yPosition).toSet(), {0.0});
    expect(
      items.first.expired,
      isFalse,
      reason: 'the lane must not wait for a full traversal before admitting another comment',
    );
    for (var index = 0; index < items.length - 1; index++) {
      expect(items[index].xPosition + items[index].width, lessThan(items[index + 1].xPosition));
    }
    expect(fixture.session.comments, hasLength(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a wider follower cannot catch the previous comment in the same lane', (tester) async {
    final fixture = await mount(tester);
    await fixture.session.updateStyle(scrollLines: 1, topLines: 0, bottomLines: 0, maxOnScreen: 10);
    final wide = List.filled(20, 'wide follower ').join();
    fixture.session.load([
      const DanmakuComment(timeMs: 1000, text: 'a'),
      DanmakuComment(timeMs: 1200, text: wide),
      const DanmakuComment(timeMs: 1800, text: 'b'),
    ], sourceLabel: 'local');
    fixture.player.tick(1000);
    await tester.pump();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_scroll(tester).map((item) => item.content.text), ['a', 'b']);
    expect(_scroll(tester).map((item) => item.yPosition).toSet(), {0.0});
    expect(
      fixture.session.comments,
      hasLength(3),
      reason: 'collision policy must not remove the raw comment from statistics',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('production canvas honors dense caps, disjoint occupancy and pause/resume', (tester) async {
    final fixture = await mount(tester);
    fixture.player.tick(1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_scroll(tester), hasLength(3));
    expect(_fixed(tester).where((item) => item.content.type == DanmakuItemType.top), hasLength(2));
    expect(_fixed(tester).where((item) => item.content.type == DanmakuItemType.bottom), hasLength(2));
    _expectDisjoint(tester, 600);
    expect(_scroll(tester).every((item) => item.image != null), isTrue);
    final oldX = _scroll(tester).first.xPosition;
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scroll(tester).first.xPosition, lessThan(oldX));
    fixture.player.setPaused(true);
    final pausedX = _scroll(tester).first.xPosition;
    await tester.pump(const Duration(seconds: 1));
    expect(_scroll(tester).first.xPosition, pausedX);
    fixture.player.setPaused(false);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scroll(tester).first.xPosition, lessThan(pausedX));
    expect(fixture.session.comments, hasLength(600));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('production canvas style update clears geometry without changing statistics', (tester) async {
    final fixture = await mount(tester);
    fixture.player.tick(1000);
    await tester.pump();
    expect(_scroll(tester), isNotEmpty);
    await fixture.session.updateStyle(maxOnScreen: 1, fontSize: 36);
    expect(_scroll(tester), isEmpty);
    expect(_fixed(tester), isEmpty);
    fixture.player.jumps.add(const Duration(milliseconds: 1000));
    fixture.player.tick(1000);
    await tester.pump();
    expect(_scroll(tester).length + _fixed(tester).length, 1);
    expect(fixture.session.comments, hasLength(600));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('production resize recreates engine before replaying lanes at the new height', (tester) async {
    final fixture = await mount(tester);
    fixture.player.tick(1000);
    await tester.pump();
    _expectDisjoint(tester, 600);
    final oldState = tester.state(find.byWidgetPredicate((widget) => widget is DanmakuScreen));
    tester.view.physicalSize = const Size(800, 180);
    await tester.pump();
    expect(tester.state(find.byWidgetPredicate((widget) => widget is DanmakuScreen)), isNot(same(oldState)));
    expect(_scroll(tester), isEmpty);
    expect(_fixed(tester), isEmpty);
    fixture.player.tick(1000);
    await tester.pump();
    expect([..._scroll(tester), ..._fixed(tester)], isNotEmpty);
    _expectDisjoint(tester, 180);
    expect(fixture.session.comments, hasLength(600));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
