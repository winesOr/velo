import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/video_controls/helpers/mobile_edge_adjustment_tracker.dart';
import 'package:plezy/widgets/video_controls/painters/buffer_range_painter.dart';
import 'package:plezy/widgets/video_controls/widgets/mobile_edge_adjustment_indicator.dart';
import 'package:plezy/widgets/video_controls/widgets/player_hud_surface.dart';
import 'package:plezy/widgets/video_controls/widgets/player_toast_indicator.dart';
import 'package:plezy/widgets/video_controls/widgets/timeline_slider.dart';

const _duration = Duration(minutes: 10);

Finder get _bufferPaint =>
    find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is BufferRangePainter);

BufferRangePainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_bufferPaint).painter! as BufferRangePainter;

SliderThemeData _sliderTheme(WidgetTester tester) => tester.widget<SliderTheme>(find.byType(SliderTheme).last).data;

Future<void> _pumpTimeline(
  WidgetTester tester, {
  bool enabled = true,
  bool reduceMotion = false,
  FocusNode? focusNode,
  ValueChanged<Duration>? onSeekEnd,
  VoidCallback? onScrubEnd,
}) async {
  await tester.pumpWidget(
    InputModeTracker(
      child: MaterialApp(
        theme: monoTheme(dark: true),
        home: MediaQuery(
          data: MediaQueryData(size: const Size(800, 600), disableAnimations: reduceMotion),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 48,
                child: TimelineSlider(
                  position: const Duration(minutes: 2),
                  duration: _duration,
                  chapters: const [],
                  chaptersLoaded: true,
                  enabled: enabled,
                  focusNode: focusNode,
                  onSeek: (_) {},
                  onSeekEnd: onSeekEnd ?? (_) {},
                  onScrubEnd: onScrubEnd,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('idle track is 3dp and retains a 48dp input area', (tester) async {
    await _pumpTimeline(tester);
    expect(_painter(tester).trackHeight, 3);
    expect(_sliderTheme(tester).trackHeight, 3);
    expect(tester.getSize(find.byType(TimelineSlider)), const Size(400, 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag expands both layers, release commits once and collapses', (tester) async {
    final seeks = <Duration>[];
    await _pumpTimeline(tester, onSeekEnd: seeks.add);
    final rect = tester.getRect(find.byType(TimelineSlider));
    final gesture = await tester.startGesture(Offset(rect.left + rect.width * 0.25, rect.center.dy));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(_painter(tester).trackHeight, 8);
    expect(_sliderTheme(tester).trackHeight, 8);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(seeks, [const Duration(minutes: 5)]);
    expect(_painter(tester).trackHeight, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled drag does not seek and ends scrubbing exactly once', (tester) async {
    final seeks = <Duration>[];
    var scrubEnds = 0;
    await _pumpTimeline(tester, onSeekEnd: seeks.add, onScrubEnd: () => scrubEnds++);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(TimelineSlider)));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(scrubEnds, 0);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(seeks, isEmpty);
    expect(scrubEnds, 1);
    expect(_painter(tester).trackHeight, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(seeks, isEmpty);
    expect(scrubEnds, 1, reason: 'disposing after cancellation must not end the same scrub again');
    expect(tester.takeException(), isNull);
  });

  testWidgets('hover expands and exit collapses', (tester) async {
    await _pumpTimeline(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.byType(TimelineSlider)));
    await tester.pumpAndSettle();
    expect(_painter(tester).trackHeight, 8);
    await mouse.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(_painter(tester).trackHeight, 3);
    await mouse.removePointer();
  });

  testWidgets('disabled timeline remains thin and does not seek', (tester) async {
    final seeks = <Duration>[];
    await _pumpTimeline(tester, enabled: false, onSeekEnd: seeks.add);
    await tester.tap(find.byType(TimelineSlider));
    await tester.pumpAndSettle();
    expect(seeks, isEmpty);
    expect(_painter(tester).trackHeight, 3);
  });

  testWidgets('keyboard focus retains expanded TV feedback', (tester) async {
    final focus = FocusNode();
    await _pumpTimeline(tester, focusNode: focus);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(_painter(tester).trackHeight, 8);
    expect(focus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
  });

  testWidgets('reduced motion still expands and closes correctly', (tester) async {
    await _pumpTimeline(tester, reduceMotion: true);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(TimelineSlider)));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(_painter(tester).trackHeight, 8);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_painter(tester).trackHeight, 3);
  });

  test('height changes invalidate the buffer painter', () {
    final thin = BufferRangePainter(ranges: const [], duration: _duration, trackHeight: 3);
    final thick = BufferRangePainter(ranges: const [], duration: _duration, trackHeight: 8);
    expect(thick.shouldRepaint(thin), isTrue);
    expect(thin.shouldRepaint(thin), isFalse);
  });

  testWidgets('edge HUD starts at actual value and stays compact at 200% text scale', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final side in MobileEdgeAdjustmentSide.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 240), textScaler: TextScaler.linear(2)),
            child: SizedBox(width: 320, height: 240, child: MobileEdgeAdjustmentIndicator(side: side, value: 0.65)),
          ),
        ),
      );
      expect(find.text('65%'), findsOneWidget);
      expect(find.bySemanticsLabel('65%'), findsOneWidget);
      expect(tester.getSize(find.byType(PlayerHudSurface)), const Size(42, 128));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('toast keeps live-region semantics and avoids the top safe inset', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 240),
            padding: EdgeInsets.only(top: 24),
            textScaler: TextScaler.linear(2),
          ),
          child: PlayerToastIndicator(icon: Symbols.fast_forward_rounded, text: '2.0x'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('2.0x'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(PlayerHudSurface)).dy, greaterThanOrEqualTo(36));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  // Optional actual Flutter rendering of the production widgets, not an app screenshot.
  testWidgets('renders production control comparison preview', (tester) async {
    const output = String.fromEnvironment('PLEZY_UI_PREVIEW_PATH');
    if (output.isEmpty) return;
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: monoTheme(dark: true),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFF1C2630),
            body: Stack(
              children: [
                const Center(
                  child: Text('Plezy · 播放控件实渲染预览', style: TextStyle(color: Colors.white70, fontSize: 18)),
                ),
                const PlayerToastIndicator(icon: Symbols.fast_forward_rounded, text: '2.0x'),
                const MobileEdgeAdjustmentIndicator(side: MobileEdgeAdjustmentSide.left, value: 0.65),
                const MobileEdgeAdjustmentIndicator(side: MobileEdgeAdjustmentSide.right, value: 0.4),
                Positioned(
                  left: 32,
                  right: 32,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TimelineSlider(
                        position: const Duration(minutes: 3),
                        duration: _duration,
                        chapters: const [],
                        chaptersLoaded: true,
                        onSeek: (_) {},
                        onSeekEnd: (_) {},
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text('03:00'), Text('10:00')],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(output).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
