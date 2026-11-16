import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/focusable_button.dart';
import 'package:plezy/widgets/press_feedback.dart';

void main() {
  Widget page(Widget child, {bool reducedMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  double scale(WidgetTester tester) => tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale;

  testWidgets('ordinary ink control releases on scroll without activating', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      page(
        SizedBox(
          width: 200,
          height: 100,
          child: PressFeedbackInkWell(onTap: () => taps++, child: const Text('Control')),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.text('Control')));
    await tester.pump();
    expect(scale(tester), .97);
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(scale(tester), 1);
    await gesture.cancel();
    expect(taps, 0);

    await tester.tap(find.text('Control'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('disabled and reduced motion controls never scale', (tester) async {
    await tester.pumpWidget(page(const PressFeedbackListTile(title: Text('Disabled'))));
    final disabled = await tester.startGesture(tester.getCenter(find.text('Disabled')));
    await tester.pump();
    expect(find.byType(AnimatedScale), findsNothing);
    await disabled.up();

    await tester.pumpWidget(
      page(PressFeedbackListTile(title: const Text('Reduced'), onTap: () {}), reducedMotion: true),
    );
    final reduced = await tester.startGesture(tester.getCenter(find.text('Reduced')));
    await tester.pump();
    final animation = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(animation.scale, 1);
    expect(animation.duration, Duration.zero);
    await reduced.up();
  });

  testWidgets('nested controls keep one feedback layer and activate once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      page(
        PressFeedbackRegion(
          child: PressFeedbackListTile(title: const Text('Nested'), onTap: () => taps++),
        ),
      ),
    );
    expect(find.byType(AnimatedScale), findsOneWidget);
    await tester.tap(find.text('Nested'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('custom focused buttons observe select without changing activation', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var taps = 0;
    await tester.pumpWidget(
      page(FocusableButton(focusNode: focusNode, onPressed: () => taps++, child: const Text('Select'))),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(scale(tester), .97);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(scale(tester), 1);
    expect(taps, 1);
  });
}
