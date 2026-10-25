import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/utils/ambient_palette_extractor.dart';

Future<ui.Image> _solid(Color color) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = color);
  return recorder.endRecording().toImage(4, 4);
}

Future<ImageProvider> _solidProvider(Color color) async {
  final png = await (await _solid(color)).toByteData(format: ui.ImageByteFormat.png);
  return MemoryImage(Uint8List.view(png!.buffer));
}

void main() {
  tearDown(AmbientPaletteExtractor.clearCache);

  test('empty, transparent and neutral artwork keep a stable fallback', () {
    for (final bytes in [
      <int>[],
      [200, 80, 80, 0],
      [255, 255, 255, 255],
      [5, 5, 5, 255],
    ]) {
      expect(
        AmbientPaletteExtractor.extractFromRgbaBytes(Uint8List.fromList(bytes), 1, 1),
        AmbientPaletteExtractor.defaultFallback,
      );
    }
  });

  test('different artwork retains its hue and useful luminance before appearance mapping', () {
    Color sample(int red, int green, int blue) =>
        AmbientPaletteExtractor.extractFromRgbaBytes(Uint8List.fromList([red, green, blue, 255]), 1, 1);
    final warm = sample(200, 130, 110);
    final cool = sample(100, 140, 200);
    expect(warm.r, greaterThan(warm.b));
    expect(cool.b, greaterThan(cool.r));
    expect(sample(200, 140, 120).computeLuminance(), greaterThan(sample(100, 70, 60).computeLuminance()));
    expect(warm, isNot(cool));
  });

  test('hero surface palette follows the colored lower edge instead of averaging the whole poster', () {
    const width = 20;
    const height = 20;
    final bytes = <int>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        bytes.addAll(y >= 15 ? [82, 12, 10, 255] : [20, 70, 150, 255]);
      }
    }

    final color = AmbientPaletteExtractor.extractFromRgbaBytes(
      Uint8List.fromList(bytes),
      width,
      height,
      matchLowerEdge: true,
    );
    expect(color, const Color.fromARGB(255, 82, 12, 10));
  });

  test('dark low-saturation artwork keeps its tint instead of the neutral fallback', () {
    // Mostly near-black with a dim, muted teal: the strict pass finds nothing.
    final bytes = <int>[];
    for (var i = 0; i < 400; i++) {
      bytes.addAll(i.isEven ? [10, 10, 12, 255] : [24, 30, 32, 255]);
    }
    final color = AmbientPaletteExtractor.extractFromRgbaBytes(Uint8List.fromList(bytes), 20, 20);
    expect(color, isNot(AmbientPaletteExtractor.defaultFallback));
    expect(color.b, greaterThan(color.r));
  });

  test('truncated pixel buffers are safe', () {
    expect(
      AmbientPaletteExtractor.extractFromRgbaBytes(Uint8List.fromList([190, 100, 80, 255, 30]), 20, 20),
      isA<Color>(),
    );
  });

  testWidgets('resized providers of different artwork do not share a cached color', (tester) async {
    await tester.runAsync(() async {
      final red = ResizeImage.resizeIfNeeded(32, 32, await _solidProvider(const Color(0xFFC04030)));
      final blue = ResizeImage.resizeIfNeeded(32, 32, await _solidProvider(const Color(0xFF3050C0)));
      final redColor = await AmbientPaletteExtractor.extractFromImageProvider(red);
      final blueColor = await AmbientPaletteExtractor.extractFromImageProvider(blue);
      expect(redColor.r, greaterThan(redColor.b));
      expect(blueColor.b, greaterThan(blueColor.r));
    });
  });

  testWidgets('a cache hit survives eviction while the least recently used entry goes', (tester) async {
    await tester.runAsync(() async {
      final red = await _solid(const Color(0xFFC04030));
      final blue = await _solid(const Color(0xFF3050C0));
      final redColor = await AmbientPaletteExtractor.extractFromImage(red, cacheKey: 0);
      for (var key = 1; key < 128; key++) {
        await AmbientPaletteExtractor.extractFromImage(red, cacheKey: key);
      }
      // Touch the oldest entry, then overflow the 128-entry cache by one.
      expect(await AmbientPaletteExtractor.extractFromImage(blue, cacheKey: 0), redColor);
      await AmbientPaletteExtractor.extractFromImage(red, cacheKey: 128);

      expect(await AmbientPaletteExtractor.extractFromImage(blue, cacheKey: 0), redColor);
      expect(await AmbientPaletteExtractor.extractFromImage(blue, cacheKey: 1), isNot(redColor));
    });
  });

  testWidgets('sampling an already-resized artwork provider still yields its color', (tester) async {
    await tester.runAsync(() async {
      final artwork = ResizeImage(await _solidProvider(const Color(0xFFCC3322)), width: 48, height: 48);
      final color = await AmbientPaletteExtractor.extractFromImageProvider(
        AmbientPaletteExtractor.samplingProvider(artwork),
      );
      expect(color, isNot(AmbientPaletteExtractor.defaultFallback));
    });
  });
}
