import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/media/media_version.dart';
import 'package:plezy/utils/dialogs.dart';
import 'package:plezy/utils/download_version_utils.dart';
import 'package:plezy/widgets/app_dialog.dart';

void main() {
  testWidgets('play version picker truncates a long release name and selects the correct file', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    final longVersion = MediaVersion(id: 'a', name: List.filled(30, 'Extended.Remaster.2160p').join('.'));
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showVersionPickerDialog(context, [
                  longVersion,
                  const MediaVersion(id: 'b', height: 720),
                ], 'Versions');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final release = find.text(longVersion.displayLabel);
    final paragraph = tester.renderObject<RenderParagraph>(release);
    expect(paragraph.maxLines, 2);
    expect(paragraph.didExceedMaxLines, isTrue);
    expect(release.hitTestable(), findsOneWidget);
    await tester.tap(release);
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggle label stays on one line in narrow option picker dialog', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    bool includeSpecials = true;
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showOptionPickerDialog<String>(
                    context,
                    title: 'Download',
                    toggle: (
                      label: 'Include Specials',
                      icon: Symbols.star_rounded,
                      value: includeSpecials,
                      onChanged: (value) => includeSpecials = value,
                    ),
                    options: [
                      (icon: Symbols.download_rounded, label: 'All Episodes', value: 'all'),
                      (icon: Symbols.visibility_off_rounded, label: 'Unwatched Only', value: 'unwatched'),
                    ],
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final includeSpecialsLabel = find.text('Include Specials');
    expect(includeSpecialsLabel, findsOneWidget);

    final paragraph = tester.renderObject<RenderParagraph>(includeSpecialsLabel);
    final lineBoxes = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 'Include Specials'.length),
    );
    expect(lineBoxes, hasLength(1));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(includeSpecials, isFalse);
    expect(selected, isNull);
    expect(find.byType(AppAlertDialog), findsOneWidget);
    expect(includeSpecialsLabel, findsOneWidget);

    await tester.tap(find.text('All Episodes'));
    await tester.pumpAndSettle();

    expect(selected, 'all');
    expect(find.byType(AppAlertDialog), findsNothing);
  });
}
