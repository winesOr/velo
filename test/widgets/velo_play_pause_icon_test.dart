import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/video_controls/video_control_button.dart';
import 'package:plezy/widgets/video_controls/widgets/velo_play_pause_icon.dart';

void main() {
  testWidgets('fold morphs in both directions and honors reduced motion', (tester) async {
    const boundary = ValueKey('fold-frame');
    var playing = false;
    var reduced = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Center(
                child: RepaintBoundary(
                  key: boundary,
                  child: VeloPlayPauseIcon(isPlaying: playing, color: Colors.white, size: 80),
                ),
              ),
            );
          },
        ),
      ),
    );
    final play = await _pixels(tester, boundary);
    update(() => playing = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final middle = await _pixels(tester, boundary);
    await tester.pumpAndSettle();
    final pause = await _pixels(tester, boundary);
    expect(middle, isNot(orderedEquals(play)));
    expect(middle, isNot(orderedEquals(pause)));
    expect(pause, isNot(orderedEquals(play)));
    update(() => playing = false);
    await tester.pumpAndSettle();
    expect(await _pixels(tester, boundary), orderedEquals(play));

    update(() {
      reduced = true;
      playing = true;
    });
    await tester.pump();
    expect(await _pixels(tester, boundary), orderedEquals(pause));
    expect(tester.binding.hasScheduledFrame, isFalse);

    update(() => reduced = false);
    await tester.pump();
    update(() => playing = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    update(() => playing = true);
    await tester.pumpAndSettle();
    expect(await _pixels(tester, boundary), orderedEquals(pause));
    expect(tester.takeException(), isNull);
  });

  testWidgets('branded transport retains button semantics, tap and keyboard activation', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var taps = 0;
    await tester.pumpWidget(
      InputModeTracker(
        child: MaterialApp(
          theme: monoTheme(dark: true),
          home: Scaffold(
            body: Center(
              child: VideoControlButton(
                focusNode: focus,
                icon: Symbols.play_arrow_rounded,
                iconBuilder: (color) => VeloPlayPauseIcon(isPlaying: false, color: color),
                semanticLabel: 'Play',
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(taps, 1);
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 2);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<Uint8List> _pixels(WidgetTester tester, Key key) async {
  return (await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    image.dispose();
    return bytes;
  }))!;
}
