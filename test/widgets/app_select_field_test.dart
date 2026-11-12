import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/widgets/app_menu.dart';
import 'package:plezy/widgets/app_select_field.dart';
import 'package:plezy/widgets/overlay_sheet.dart';
import 'package:plezy/widgets/press_feedback.dart';
import 'package:plezy/theme/interaction_tokens.dart';

import '../test_helpers/theme.dart';

Future<void> _pumpField(WidgetTester tester, Widget child, {bool reduceMotion = false, double textScale = 1}) async {
  await tester.pumpWidget(
    InputModeTracker(
      child: MaterialApp(
        theme: ThemeData(extensions: const [testMonoTokens]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion, textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: OverlaySheetHost(
          child: Scaffold(
            body: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('selection delay shows the choice and ignores a second click', (tester) async {
    final selected = <String>[];
    await _pumpField(
      tester,
      AppSelectField<String>(
        label: 'Audio',
        value: 'one',
        options: const [
          AppSelectOption(value: 'one', label: 'One'),
          AppSelectOption(value: 'two', label: 'Two'),
        ],
        onChanged: selected.add,
      ),
    );
    await tester.tap(find.byType(AppSelectField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two'));
    await tester.pump();
    expect(selected, isEmpty);
    final chosen = tester.widget<AppMenuItemTile<String>>(
      find.byWidgetPredicate((widget) => widget is AppMenuItemTile<String> && widget.item.value == 'two'),
    );
    expect(chosen.selectionOverride, isTrue);
    await tester.tap(find.text('Two'));
    await tester.pump(InteractionTokens.menuSelectionDuration + const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(selected, ['two']);
  });

  testWidgets('back during selection feedback cancels the pending commit', (tester) async {
    final selected = <String>[];
    await _pumpField(
      tester,
      AppSelectField<String>(
        label: 'Audio',
        value: 'one',
        options: const [
          AppSelectOption(value: 'one', label: 'One'),
          AppSelectOption(value: 'two', label: 'Two'),
        ],
        onChanged: selected.add,
      ),
    );
    await tester.tap(find.byType(AppSelectField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two'));
    await tester.pump();
    Navigator.of(tester.element(find.byType(AppMenuList<String>))).pop();
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.byType(AppMenuList<String>), findsNothing);
  });

  testWidgets('disposing a selector during delayed selection never calls its callback', (tester) async {
    var calls = 0;
    await _pumpField(
      tester,
      AppSelectField<String>(
        label: 'Audio',
        options: const [AppSelectOption(value: 'one', label: 'One')],
        onChanged: (_) => calls++,
      ),
    );
    await tester.tap(find.byType(AppSelectField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(InteractionTokens.menuSelectionDuration + const Duration(milliseconds: 1));
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long labels remain readable in the menu at 200 percent text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const longTitle = 'English Director and Cast Commentary with additional discussion of the extended edition';
    const longSubtitle = 'DTS-HD Master Audio · 7.1 · Commentary recorded for this edition';
    await _pumpField(
      tester,
      AppSelectField<String>(
        label: 'Audio',
        value: 'commentary',
        options: const [
          AppSelectOption(value: 'commentary', label: longTitle, subtitle: longSubtitle),
          AppSelectOption(value: 'plain', label: 'English'),
        ],
        onChanged: (_) {},
      ),
      textScale: 2,
    );
    final trigger = find.text(longTitle);
    expect(tester.renderObject<RenderParagraph>(trigger).maxLines, 1);
    await tester.tap(find.byType(AppSelectField<String>));
    await tester.pumpAndSettle();
    final menuTitle = find.descendant(of: find.byType(AppMenuItemTile<String>), matching: find.text(longTitle));
    final paragraph = tester.renderObject<RenderParagraph>(menuTitle);
    expect(paragraph.maxLines, isNull);
    expect(paragraph.didExceedMaxLines, isFalse);
    final menuSubtitle = find.descendant(of: find.byType(AppMenuItemTile<String>), matching: find.text(longSubtitle));
    expect(tester.renderObject<RenderParagraph>(menuSubtitle).maxLines, isNull);
    expect(find.bySemanticsLabel(RegExp(RegExp.escape(longTitle))), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same-language options keep their subtitles and dispatch only once', (tester) async {
    final selected = <String>[];
    await _pumpField(
      tester,
      AppSelectField<String>(
        label: 'Audio',
        value: 'stereo',
        options: const [
          AppSelectOption(value: 'stereo', label: 'English', subtitle: 'AAC · Stereo'),
          AppSelectOption(value: 'surround', label: 'English', subtitle: 'DTS-HD MA · 5.1'),
          AppSelectOption(value: 'commentary', label: 'English', subtitle: 'Director commentary'),
        ],
        onChanged: selected.add,
      ),
    );
    await tester.tap(find.byType(AppSelectField<String>));
    await tester.pumpAndSettle();
    expect(find.text('AAC · Stereo'), findsWidgets);
    expect(find.text('DTS-HD MA · 5.1'), findsOneWidget);
    await tester.tap(find.text('Director commentary'));
    await tester.pumpAndSettle();
    expect(selected, ['commentary']);
  });

  testWidgets('empty and disabled selectors cannot open a menu', (tester) async {
    await _pumpField(
      tester,
      Column(
        children: [
          AppSelectField<String>(label: 'Empty', options: const [], onChanged: (_) => fail('Empty selection')),
          AppSelectField<String>(
            label: 'Disabled',
            enabled: false,
            options: const [AppSelectOption(value: 'one', label: 'One')],
            onChanged: (_) => fail('Disabled selection'),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Empty'));
    await tester.tap(find.text('Disabled'));
    await tester.pumpAndSettle();
    expect(find.byType(AppMenuList<String>), findsNothing);
  });

  testWidgets('keyboard opens at the current item, scrolls it into view and restores focus on back', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await _pumpField(
      tester,
      AppSelectField<int>(
        label: 'Audio',
        value: 17,
        focusNode: focusNode,
        options: [for (var index = 0; index < 20; index++) AppSelectOption(value: index, label: 'Track $index')],
        onChanged: (_) => fail('Back must not select'),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final currentTile = find.byWidgetPredicate((widget) => widget is AppMenuItemTile<int> && widget.item.value == 17);
    final currentFocus = find.descendant(of: currentTile, matching: find.byType(Focus)).first;
    expect(tester.widget<Focus>(currentFocus).focusNode!.hasFocus, isTrue);
    final currentLabel = find.descendant(of: currentTile, matching: find.text('Track 17'));
    expect(tester.getCenter(currentLabel).dy, inInclusiveRange(8, 592));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AppMenuList<int>), findsNothing);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('dragging cancels press feedback without opening the selector', (tester) async {
    await _pumpField(
      tester,
      SingleChildScrollView(
        child: Column(
          children: [
            AppSelectField<String>(
              label: 'Audio',
              value: 'one',
              options: const [AppSelectOption(value: 'one', label: 'One')],
              onChanged: (_) => fail('Scrolling must not select'),
            ),
            const SizedBox(height: 1200),
          ],
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AppSelectField<String>)));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<PressFeedback>(find.byType(PressFeedback)).pressed, isTrue);
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<PressFeedback>(find.byType(PressFeedback)).pressed, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(AppMenuList<String>), findsNothing);
  });

  testWidgets('reduced motion keeps visible press color without scaling and pointer cancellation releases it', (
    tester,
  ) async {
    await _pumpField(
      tester,
      AppSelectField<String>(
        label: 'Audio',
        options: const [AppSelectOption(value: 'one', label: 'One')],
        onChanged: (_) => fail('Cancellation must not select'),
      ),
      reduceMotion: true,
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AppSelectField<String>)));
    await tester.pump(const Duration(milliseconds: 150));
    final feedback = find.byType(PressFeedback);
    expect(tester.widget<PressFeedback>(feedback).pressed, isTrue);
    final scale = tester.widget<AnimatedScale>(find.descendant(of: feedback, matching: find.byType(AnimatedScale)));
    expect(scale.scale, 1);
    final decoration =
        tester
                .widget<AnimatedContainer>(find.descendant(of: feedback, matching: find.byType(AnimatedContainer)))
                .foregroundDecoration!
            as BoxDecoration;
    expect(decoration.color!.a, greaterThan(0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.widget<PressFeedback>(feedback).pressed, isFalse);
    expect(find.byType(AppMenuList<String>), findsNothing);
  });
}
