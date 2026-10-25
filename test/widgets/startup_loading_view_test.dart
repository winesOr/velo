import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/app_icon.dart';
import 'package:plezy/widgets/startup_loading_view.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('StartupFixture')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    await (FontLoader(
      'packages/material_symbols_icons/MaterialSymbolsRounded',
    )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
  });

  tearDown(() => TvDetectionService.debugSetAppleTVOverride(null));

  for (final fixture in [
    (name: 'light', dark: false, size: const Size(390, 844), scale: 1.0, tv: false),
    (name: 'dark', dark: true, size: const Size(390, 844), scale: 1.0, tv: false),
    (name: 'narrow-large', dark: true, size: const Size(320, 568), scale: 2.0, tv: false),
    (name: 'landscape', dark: false, size: const Size(844, 390), scale: 1.0, tv: false),
    (name: 'tv', dark: true, size: const Size(960, 540), scale: 1.0, tv: true),
  ]) {
    testWidgets('compact startup presentation fits ${fixture.name}', (tester) async {
      await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.zh));
      TvDetectionService.debugSetAppleTVOverride(fixture.tv);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = fixture.size;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      final theme = monoTheme(dark: fixture.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'StartupFixture')),
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(
              size: fixture.size,
              textScaler: TextScaler.linear(fixture.scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: StartupLoadingView(
              status: Builder(
                builder: (context) => Text(
                  t.common.connectingToServers,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              servers: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(Symbols.check_circle_rounded, size: 12, color: Color(0xff4caf50)),
                  SizedBox(width: 8),
                  Flexible(child: Text('家庭媒体服务器', style: TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.app.title), findsOneWidget);
      expect(tester.getSize(find.byType(StartupBrandMark)).width, lessThan(180));
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, .4);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('UPDATE_STARTUP_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final picture = await render.toImage(pixelRatio: 1);
          final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/fixtures/startup-${fixture.name}.png').writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
    });
  }

  testWidgets('a long connection list remains scrollable on a short screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 300), disableAnimations: true),
          child: StartupLoadingView(
            servers: Column(
              children: [
                for (var i = 0; i < 18; i++) Padding(padding: const EdgeInsets.all(8), child: Text('Server $i')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(find.text('Server 17').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
