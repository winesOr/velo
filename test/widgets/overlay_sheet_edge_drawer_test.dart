import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/widgets/overlay_sheet.dart';

void main() {
  testWidgets('edgeDrawer sits flush right at full height', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: OverlaySheetHost(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => OverlaySheetController.of(context).show<void>(
                  presentation: OverlaySheetPresentation.edgeDrawer,
                  constraints: const BoxConstraints(maxWidth: 350),
                  builder: (_) => const Text('Drawer body'),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.ancestor(of: find.text('Drawer body'), matching: find.byType(SizedBox)).first);
    expect(rect.right, 800);
    expect(rect.top, 0);
    expect(rect.height, 600);
    expect(rect.width, 350);
  });
}
