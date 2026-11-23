import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/theme/overlay_tokens.dart';
import 'package:plezy/widgets/app_glass_surface.dart';
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
                  constraints: const BoxConstraints(maxWidth: 340),
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
    expect(rect.width, 340);

    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(300, 600);
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final drawer = find.ancestor(of: find.text('Drawer body'), matching: find.byType(SizedBox)).first;
    expect(tester.getRect(drawer).right, greaterThan(300));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getRect(drawer).right, 300);
    expect(tester.getSize(drawer).width, 255);
  });

  testWidgets('player hosts use see-through glass for drawers and anchored menus', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: OverlaySheetHost(
          playerGlass: true,
          child: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => OverlaySheetController.of(context).show<void>(
                      presentation: OverlaySheetPresentation.edgeDrawer,
                      builder: (_) => const Text('Drawer body'),
                    ),
                    child: const Text('Drawer'),
                  ),
                  ElevatedButton(
                    onPressed: () => OverlaySheetController.of(context).show<void>(
                      anchor: const Rect.fromLTWH(600, 340, 60, 32),
                      constraints: const BoxConstraints(maxWidth: OverlayTokens.playerMenuWidth),
                      builder: (_) => const SizedBox(height: 120, child: Text('Menu body')),
                    ),
                    child: const Text('Menu'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Drawer'));
    await tester.pumpAndSettle();
    var glass = tester.widget<AppGlassSurface>(
      find.ancestor(of: find.text('Drawer body'), matching: find.byType(AppGlassSurface)),
    );
    expect(glass.surfaceOpacity, OverlayTokens.playerGlassOpacity);
    expect(glass.blurSigma, OverlayTokens.playerGlassBlurSigma);
    expect(glass.saturation, OverlayTokens.playerGlassSaturation);
    final barrier = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((box) => box.color.a > 0 && box.color.r == 0);
    expect(barrier.any((box) => (box.color.a - OverlayTokens.playerBarrierOpacity).abs() < .01), isTrue);

    await tester.tapAt(const Offset(10, 380));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    glass = tester.widget<AppGlassSurface>(
      find.ancestor(of: find.text('Menu body'), matching: find.byType(AppGlassSurface)),
    );
    expect(glass.surfaceOpacity, OverlayTokens.playerGlassOpacity);
    final menu = tester.getRect(find.byType(AppGlassSurface));
    expect(menu.bottom, lessThanOrEqualTo(340), reason: 'the speed menu opens above its chip');
    expect(menu.center.dx, closeTo(630, 1), reason: 'centred on the chip');
  });
}
