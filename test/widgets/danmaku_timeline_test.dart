import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/danmaku/danmaku_comment.dart';
import 'package:plezy/danmaku/danmaku_heatmap.dart';
import 'package:plezy/focus/dpad_navigator.dart';
import 'package:plezy/media/media_source_info.dart';
import 'package:plezy/mpv/models.dart';
import 'package:plezy/services/scrub_preview_source.dart';
import 'package:plezy/widgets/video_controls/painters/buffer_range_painter.dart';
import 'package:plezy/widgets/video_controls/widgets/timeline_slider.dart';

DanmakuHeatmap _heat({bool empty = false}) => DanmakuHeatmap.fromComments([
  if (!empty)
    for (var i = 0; i < 30; i++)
      for (var j = 0; j < i * 10; j++) DanmakuComment(timeMs: i * 1000, text: ''),
], durationMs: 30000);

Future<void> _pump(
  WidgetTester tester, {
  required List<Duration> ends,
  List<Duration>? previews,
  FocusNode? focusNode,
  DanmakuHeatmap? heatmap,
  bool heatmapEnabled = true,
  KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
  double width = 400,
  double scale = 1,
  ScrubFrame? Function(Duration)? thumbnailDataBuilder,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SizedBox(
            width: width,
            child: TimelineSlider(
              position: const Duration(seconds: 20),
              duration: const Duration(seconds: 30),
              chapters: const [],
              chaptersLoaded: true,
              heatmap: heatmap,
              heatmapEnabled: heatmapEnabled,
              heatmapCountLabel: (count) => '$count comments here',
              noHeatmapPeakLabel: 'No peaks',
              onSeek: previews?.add ?? (_) {},
              onSeekEnd: ends.add,
              focusNode: focusNode,
              onKeyEvent: onKeyEvent,
              thumbnailDataBuilder: thumbnailDataBuilder,
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(SelectKeyUpSuppressor.clearSuppression);

  testWidgets('curve tap snaps inside fixed window, long hold shows raw count without seek', (tester) async {
    final ends = <Duration>[];
    final heat = _heat();
    await _pump(tester, ends: ends, heatmap: heat);
    final region = find.byKey(const ValueKey('timeline-heatmap-region'));
    final rect = tester.getRect(region);
    final point = Offset(rect.left + rect.width * 20.5 / 30, rect.center.dy);
    await tester.tapAt(point);
    await tester.pump();
    expect(ends, [const Duration(milliseconds: 26500)]);
    ends.clear();
    final gesture = await tester.startGesture(point);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
    expect(find.text('200 comments here'), findsOneWidget);
    expect(ends, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(ends, isEmpty);
    expect(find.text('200 comments here'), findsNothing);
  });

  testWidgets('track retains precise drag, commits once, and cancellation never commits', (tester) async {
    final ends = <Duration>[];
    final previews = <Duration>[];
    await _pump(tester, ends: ends, previews: previews, heatmap: _heat());
    final track = tester.getRect(find.byType(Slider));
    final gesture = await tester.startGesture(Offset(track.left + track.width * .25, track.center.dy));
    await tester.pump();
    await gesture.moveBy(Offset(track.width / 2, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(previews, isNotEmpty);
    expect(ends, [const Duration(milliseconds: 22500)]);
    ends.clear();
    final cancelled = await tester.startGesture(track.center);
    await tester.pump();
    await cancelled.moveBy(const Offset(30, 0));
    await cancelled.cancel();
    await tester.pump();
    expect(ends, isEmpty);
  });

  testWidgets('hover and scrub still request and display thumbnail frames', (tester) async {
    final ends = <Duration>[];
    final requested = <Duration>[];
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await _pump(
      tester,
      ends: ends,
      heatmap: _heat(),
      thumbnailDataBuilder: (time) {
        requested.add(time);
        return BytesScrubFrame(bytes);
      },
    );
    final rect = tester.getRect(find.byType(Slider));
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: rect.topLeft);
    await mouse.moveTo(rect.center);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(requested.last, const Duration(seconds: 15));
    await mouse.removePointer();
    await tester.pump();
    final touch = await tester.startGesture(Offset(rect.left + rect.width * .75, rect.center.dy));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(requested.last, const Duration(milliseconds: 22500));
    await touch.up();
    await tester.pump();
    expect(ends, [const Duration(milliseconds: 22500)]);
  });

  testWidgets('TV hold seeks once and consumes repeat/release, short select forwards once', (tester) async {
    final ends = <Duration>[];
    final node = FocusNode();
    addTearDown(node.dispose);
    var shortSelects = 0;
    await _pump(
      tester,
      ends: ends,
      heatmap: _heat(),
      focusNode: node,
      onKeyEvent: (_, event) {
        if (event.logicalKey == LogicalKeyboardKey.select) shortSelects++;
        return KeyEventResult.handled;
      },
    );
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 550));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(ends, hasLength(1));
    expect(shortSelects, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(shortSelects, 1);
    expect(ends, hasLength(1));
  });

  testWidgets('TV no peak preserves position and gives feedback', (tester) async {
    final ends = <Duration>[];
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pump(tester, ends: ends, heatmap: _heat(empty: true), focusNode: node);
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('No peaks'), findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(ends, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('narrow layout large text hover and heatmap toggle preserve track', (tester) async {
    final ends = <Duration>[];
    await _pump(tester, ends: ends, heatmap: _heat(), width: 120, scale: 3);
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byType(Slider)));
    await mouse.moveTo(tester.getCenter(find.byType(Slider)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
    final painter =
        tester
                .widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BufferRangePainter))
                .painter!
            as BufferRangePainter;
    expect(painter.trackHeight, 8);
    await mouse.removePointer();
    await _pump(tester, ends: ends, heatmap: _heat(), heatmapEnabled: false, width: 120, scale: 3);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(find.byKey(const ValueKey('timeline-heatmap-region'))).height, 0);
    expect(tester.takeException(), isNull);
  });

  test('painter invalidates heatmap and skip range changes', () {
    final base = BufferRangePainter(ranges: [], duration: const Duration(seconds: 30));
    expect(BufferRangePainter(ranges: [], duration: const Duration(seconds: 30)).shouldRepaint(base), isFalse);
    expect(
      BufferRangePainter(ranges: [], duration: const Duration(seconds: 30), heatmap: _heat()).shouldRepaint(base),
      isTrue,
    );
    expect(
      BufferRangePainter(ranges: [], duration: const Duration(seconds: 30), heatmapEnabled: false).shouldRepaint(base),
      isTrue,
    );
    expect(
      BufferRangePainter(
        ranges: [],
        duration: const Duration(seconds: 30),
        skipRanges: [const BufferRange(start: Duration.zero, end: Duration(seconds: 2))],
      ).shouldRepaint(base),
      isTrue,
    );
  });

  test('chapter boundaries are thin ticks on a continuous track', () async {
    final recorder = ui.PictureRecorder();
    final painter = BufferRangePainter(
      ranges: [const BufferRange(start: Duration.zero, end: Duration(seconds: 30))],
      duration: const Duration(seconds: 30),
      chapters: [MediaChapter(id: 1, startTimeOffset: 15000)],
      heatmap: _heat(),
      heatmapHeight: 24,
      trackHeight: 8,
      skipRanges: [const BufferRange(start: Duration(seconds: 14), end: Duration(seconds: 16))],
    );
    painter.paint(Canvas(recorder), const Size(300, 72));
    final picture = recorder.endRecording();
    final image = await picture.toImage(300, 72);
    final data = (await image.toByteData())!;
    int alpha(int x, int y) => data.getUint8((y * 300 + x) * 4 + 3);
    int red(int x, int y) => data.getUint8((y * 300 + x) * 4);
    for (final x in [146, 148, 152, 154]) {
      expect(alpha(x, 48), greaterThan(0), reason: 'track is continuous at x=$x');
    }
    expect(red(150, 48), lessThan(red(146, 48)), reason: 'chapter tick is darker than the track');
    expect(alpha(150, 30), greaterThan(0), reason: 'heat curve is not cut at the chapter');
    expect(alpha(145, 48), greaterThan(0), reason: 'buffer survives');
    expect(alpha(145, 52), greaterThan(0), reason: 'skip marker survives');
    expect(alpha(250, 20), greaterThan(65), reason: 'heat curve retains contrast instead of disappearing over video');
    image.dispose();
    picture.dispose();
  });
}
