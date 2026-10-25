import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadTabletFonts({bool loadDefaultFont = false}) async {
  if (loadDefaultFont) {
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    }
  }
  await (FontLoader('TabletFixture')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
  await (FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
}

ThemeData tabletFixtureTheme(ThemeData theme) => theme.copyWith(
  platform: TargetPlatform.android,
  textTheme: theme.textTheme.apply(fontFamily: 'TabletFixture'),
  primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'TabletFixture'),
  appBarTheme: theme.appBarTheme.copyWith(
    titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'TabletFixture'),
  ),
);

/// Opt-in captures of production widgets with fixture data, not device photos.
Future<void> captureTablet(WidgetTester tester, Finder finder, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_TABLET')) return;
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/fixtures/tablet/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}
