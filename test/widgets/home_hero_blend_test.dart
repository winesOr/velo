import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/theme/home_typography.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/fusion_home_hero.dart';

import '../test_helpers/media_items.dart';

Future<ByteData> _paintHero(
  WidgetTester tester, {
  required Color surface,
  required Color artwork,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 650);
  addTearDown(tester.view.reset);
  const boundaryKey = ValueKey('home-blend-pixels');
  await tester.pumpWidget(
    MaterialApp(
      theme: HomeTypography.apply(monoTheme(dark: dark).copyWith(scaffoldBackgroundColor: surface), tv: false),
      home: RepaintBoundary(
        key: boundaryKey,
        child: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 548,
                child: FusionHomeHero(
                  item: testMediaItem(title: ''),
                  backdrop: ColoredBox(color: artwork),
                  onPlay: () {},
                ),
              ),
              Expanded(child: ColoredBox(color: surface)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
  late ByteData bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
  });
  return bytes;
}

List<int> _pixel(ByteData bytes, int y) => [for (var c = 0; c < 3; c++) bytes.getUint8((y * 390 + 4) * 4 + c)];

void main() {
  for (final fixture in [
    (surface: const Color(0xffd9bfb4), dark: false),
    (surface: const Color(0xff796254), dark: true),
  ]) {
    testWidgets('matching artwork and page share the same ${fixture.dark ? 'dark' : 'light'} surface', (tester) async {
      final bytes = await _paintHero(tester, surface: fixture.surface, artwork: fixture.surface, dark: fixture.dark);
      final page = _pixel(bytes, 600);
      for (var y = 230; y < 548; y++) {
        final sample = _pixel(bytes, y);
        for (var c = 0; c < 3; c++) {
          expect(
            (sample[c] - page[c]).abs(),
            lessThanOrEqualTo(2),
            reason: 'matching artwork must not gain a dark band at row $y, channel $c',
          );
        }
      }
    });
  }

  for (final dark in [false, true]) {
    testWidgets('long blend joins a black poster to the colored page without whitening in ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      const surface = Color(0xff56110c);
      final bytes = await _paintHero(tester, surface: surface, artwork: Colors.black, dark: dark);
      final page = _pixel(bytes, 600);
      expect(page, [86, 17, 12]);
      expect(_pixel(bytes, 140), [0, 0, 0], reason: 'the upper artwork is untouched by the bottom blend');
      expect(_pixel(bytes, 240).first, greaterThan(5), reason: 'the blend starts well before the hero bottom');
      expect(_pixel(bytes, 400).first, lessThan(page.first), reason: 'the blend extends through the lower artwork');
      for (var y = 141; y <= 548; y++) {
        final previous = _pixel(bytes, y - 1);
        final sample = _pixel(bytes, y);
        for (var c = 0; c < 3; c++) {
          // The renderer dithers gradients by a single channel value.
          expect(sample[c], inInclusiveRange(0, page[c]), reason: 'only the page tint is added at row $y');
          expect(sample[c], greaterThanOrEqualTo(previous[c] - 1));
          expect((sample[c] - previous[c]).abs(), lessThanOrEqualTo(2), reason: 'no sharp band at row $y, channel $c');
        }
      }
      expect(_pixel(bytes, 538), page, reason: 'the last strip already matches the page before the image ends');
    });
  }

  testWidgets('bright artwork gently settles into the page color before the hero ends', (tester) async {
    final bytes = await _paintHero(tester, surface: const Color(0xff56110c), artwork: Colors.white);
    expect(_pixel(bytes, 140), [255, 255, 255]);
    final page = _pixel(bytes, 600);
    for (var y = 141; y <= 548; y++) {
      final previous = _pixel(bytes, y - 1);
      final sample = _pixel(bytes, y);
      for (var c = 0; c < 3; c++) {
        expect(sample[c], inInclusiveRange(page[c], 255));
        expect(sample[c], lessThanOrEqualTo(previous[c] + 1));
        expect((sample[c] - previous[c]).abs(), lessThanOrEqualTo(3), reason: 'long blend stays smooth at row $y');
      }
    }
    expect(_pixel(bytes, 538), page);
  });
}
