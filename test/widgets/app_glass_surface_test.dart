import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/services/device_performance.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/dialogs.dart';
import 'package:plezy/utils/snackbar_helper.dart';
import 'package:plezy/widgets/app_glass_surface.dart';

import '../test_helpers/tablet_screenshots.dart';

void main() {
  tearDown(DevicePerformance.debugReset);

  for (final mode in ['full', 'contrast', 'motion', 'reduced']) {
    testWidgets('glass uses one clipped blur or an opaque $mode fallback', (tester) async {
      if (mode == 'reduced') DevicePerformance.debugReset(autoReduced: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: monoTheme(dark: true),
          home: MediaQuery(
            data: MediaQueryData(highContrast: mode == 'contrast', disableAnimations: mode == 'motion'),
            child: const Center(child: AppGlassSurface(child: SizedBox(width: 200, height: 100))),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), mode == 'full' ? findsOneWidget : findsNothing);
      final glassMaterial = tester.widget<Material>(
        find.descendant(of: find.byType(AppGlassSurface), matching: find.byType(Material)),
      );
      expect(glassMaterial.color!.a, mode == 'full' ? lessThan(1) : 1);
      if (mode == 'full') {
        expect(find.ancestor(of: find.byType(BackdropFilter), matching: find.byType(ClipPath)), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('transparent legacy surfaces use the light theme tint instead of black', (tester) async {
    final theme = monoTheme(dark: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Center(
          child: AppGlassSurface(backgroundColor: Colors.transparent, child: SizedBox(width: 200, height: 100)),
        ),
      ),
    );
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppGlassSurface), matching: find.byType(Material)),
    );
    expect(material.color!.withValues(alpha: 1), theme.colorScheme.surface.withValues(alpha: 1));
  });

  for (final dark in [true, false]) {
    testWidgets('dialog and notification visual fixture dark=$dark', (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await loadTabletFonts(loadDefaultFont: true);
      final artworkImages = <String, ui.Image>{};
      await tester.runAsync(() async {
        for (final name in ['dune', 'interstellar', 'blade', 'spirited']) {
          final codec = await ui
              .instantiateImageCodec(File('test/fixtures/artwork/$name.png').readAsBytesSync())
              .timeout(const Duration(seconds: 5));
          final frame = await codec.getNextFrame().timeout(const Duration(seconds: 5));
          artworkImages[name] = frame.image;
          codec.dispose();
        }
      });
      addTearDown(() {
        for (final picture in artworkImages.values) {
          picture.dispose();
        }
      });
      final boundary = GlobalKey();
      late BuildContext host;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: tabletFixtureTheme(monoTheme(dark: dark)),
            home: Builder(
              builder: (context) {
                host = context;
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Velo'),
                    actions: const [Padding(padding: EdgeInsets.all(16), child: Icon(Icons.search))],
                  ),
                  body: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your library', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 24),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final artwork in ['dune', 'interstellar', 'blade', 'spirited'])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: RawImage(image: artworkImages[artwork], fit: BoxFit.cover),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 56),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      showSuccessSnackBar(host, 'Your library is up to date.');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, 'notification-${dark ? 'dark' : 'light'}');
      ScaffoldMessenger.of(host).removeCurrentSnackBar();
      final result = showConfirmDialog(
        host,
        title: 'Remove download?',
        message: 'This clears the local copy from this device. The original media stays in your library.',
        confirmText: 'Remove download',
        cancelText: 'Keep download',
        isDestructive: true,
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, 'dialog-${dark ? 'dark' : 'light'}');
      await tester.tap(find.text('Keep download'));
      await tester.pumpAndSettle();
      await expectLater(result, completion(false));
    });
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final picture = await boundary.toImage();
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/tmp/velo-ui-screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}
