import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/navigation/home_theme.dart';
import 'package:plezy/utils/ambient_palette_extractor.dart';
import 'package:plezy/theme/mono_presentation.dart';

void main() {
  test('drag preview follows position in both directions and commits only when selected', () async {
    final controller = HomeThemeController(
      resolve: (image) async => image == const AssetImage('from') ? Colors.red : Colors.blue,
    );
    addTearDown(controller.dispose);
    await controller.precachePalette(const AssetImage('from'));
    await controller.precachePalette(const AssetImage('to'));
    await controller.select('from', const AssetImage('from'));
    void preview(double progress) => controller.blendPreparedPalettes(
      from: const AssetImage('from'),
      to: const AssetImage('to'),
      progress: progress,
      fallback: Colors.black,
    );
    preview(.6);
    expect(controller.color, Color.lerp(Colors.red, Colors.blue, .6));
    expect(controller.mediaKey, 'from');
    expect(controller.isFollowingArtwork, isTrue);
    preview(.35);
    expect(controller.color, Color.lerp(Colors.red, Colors.blue, .35));
    expect(controller.mediaKey, 'from');
    preview(1);
    await controller.select('to', const AssetImage('to'));
    expect(controller.color, Colors.blue);
    expect(controller.mediaKey, 'to');
    expect(controller.isFollowingArtwork, isFalse);
  });

  test('ending on an unavailable image retires the mixed preview and keeps the committed color', () async {
    final controller = HomeThemeController(
      resolve: (image) async => image == const AssetImage('from') ? Colors.red : Colors.blue,
    );
    addTearDown(controller.dispose);
    await controller.select('from', const AssetImage('from'));
    await controller.precachePalette(const AssetImage('to'));
    controller.blendPreparedPalettes(
      from: const AssetImage('from'),
      to: const AssetImage('to'),
      progress: .6,
      fallback: Colors.black,
    );
    controller.prepare('missing-image');
    expect(controller.mediaKey, 'missing-image');
    expect(controller.color, Colors.red);
    expect(controller.isFollowingArtwork, isFalse);
  });

  testWidgets('holding a drag preview does not run an independent color animation', (tester) async {
    final controller = HomeThemeController(resolve: (_) async => Colors.blue);
    addTearDown(controller.dispose);
    await controller.precachePalette(const AssetImage('to'));
    late Color rendered;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeThemeScope(
          controller: controller,
          child: Builder(
            builder: (context) {
              rendered = HomeThemeScope.colorOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    controller.blendPreparedPalettes(from: null, to: const AssetImage('to'), progress: .6, fallback: Colors.red);
    await tester.pump();
    expect(rendered, Color.lerp(Colors.red, Colors.blue, .6));
    final held = rendered;
    await tester.pump(const Duration(seconds: 1));
    expect(rendered, held);
    controller.blendPreparedPalettes(from: null, to: const AssetImage('to'), progress: .35, fallback: Colors.red);
    await tester.pump();
    expect(rendered, Color.lerp(Colors.red, Colors.blue, .35));
  });

  test('preparing adjacent palettes never changes selection and is reused without another request', () async {
    final pending = Completer<Color>();
    var calls = 0;
    final controller = HomeThemeController(
      resolve: (_) {
        calls++;
        return pending.future;
      },
    );
    addTearDown(controller.dispose);
    final warm = controller.precachePalette(const AssetImage('next'));
    expect(controller.mediaKey, isNull);
    final selected = controller.select('next', const AssetImage('next'));
    expect(calls, 1);
    pending.complete(Colors.blue);
    await Future.wait([warm, selected]);
    expect(controller.color, Colors.blue);
    await controller.select('other', null);
    final reused = controller.select('next', const AssetImage('next'));
    expect(controller.color, Colors.blue, reason: 'a decoded palette is applied synchronously');
    await reused;
    expect(calls, 1);
  });

  testWidgets('missing artwork preserves the selected light page appearance', (tester) async {
    final controller = HomeThemeController();
    addTearDown(controller.dispose);
    late Color renderedColor;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: HomeThemeScope(
          controller: controller,
          child: Builder(
            builder: (context) {
              renderedColor = HomeThemeScope.colorOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(renderedColor, ThemeData.light().scaffoldBackgroundColor);
  });

  test('late palettes cannot overwrite the selected server/media identity', () async {
    final requests = <Completer<Color>>[];
    final controller = HomeThemeController(
      resolve: (_) {
        final request = Completer<Color>();
        requests.add(request);
        return request.future;
      },
    );
    addTearDown(controller.dispose);
    final first = controller.select('server-a:item', const AssetImage('a'));
    final second = controller.select('server-b:item', const AssetImage('b'));
    final third = controller.select('server-c:item', const AssetImage('c'));
    requests[2].complete(Colors.green);
    await third;
    requests[1].complete(Colors.blue);
    requests[0].complete(Colors.red);
    await Future.wait([first, second]);
    expect(controller.mediaKey, 'server-c:item');
    expect(controller.color, Colors.green);
  });

  test('image failure and missing artwork use stable fallback; same selection is cached', () async {
    var calls = 0;
    final controller = HomeThemeController(
      resolve: (_) async {
        calls++;
        throw StateError('fixture image failure');
      },
    );
    addTearDown(controller.dispose);
    await controller.select('a', const AssetImage('a'));
    await controller.select('a', const AssetImage('a'));
    expect(calls, 1);
    expect(controller.color, AmbientPaletteExtractor.defaultFallback);
    await controller.select('b', null);
    expect(controller.mediaKey, 'b');
    expect(controller.color, AmbientPaletteExtractor.defaultFallback);
  });

  test('disposed scope ignores a pending extraction', () async {
    final pending = Completer<Color>();
    final controller = HomeThemeController(resolve: (_) => pending.future);
    final result = controller.select('a', const AssetImage('a'));
    controller.dispose();
    pending.complete(Colors.red);
    await result;
  });

  test('pending artwork preserves the previous color and prepare retires older work', () async {
    final pending = Completer<Color>();
    final controller = HomeThemeController(
      resolve: (image) async => image == const AssetImage('a') ? Colors.red : pending.future,
    );
    addTearDown(controller.dispose);
    await controller.select('a', const AssetImage('a'));
    final second = controller.select('b', const AssetImage('b'));
    expect(controller.color, Colors.red);
    controller.prepare('c');
    pending.complete(Colors.blue);
    await second;
    expect(controller.mediaKey, 'c');
    expect(controller.color, Colors.red);
  });

  testWidgets('scope shares intermediate colors and retargets without a fallback frame', (tester) async {
    final controller = HomeThemeController(
      resolve: (image) async => image == const AssetImage('a') ? Colors.red : Colors.blue,
    );
    addTearDown(controller.dispose);
    final colors = <Color>[];
    Widget app(Brightness brightness, {bool reduced = false}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: HomeThemeScope(
          controller: controller,
          child: Builder(
            builder: (context) {
              colors.add(HomeThemeScope.colorOf(context));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(Brightness.dark));
    await controller.select('a', const AssetImage('a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final intermediate = colors.last;
    expect(intermediate, isNot(MonoPresentation.artworkSurface(Colors.red, Brightness.dark)));
    await controller.select('b', const AssetImage('b'));
    await tester.pump();
    expect(colors.last, intermediate);
    await tester.pumpAndSettle();
    expect(colors.last, MonoPresentation.artworkSurface(Colors.blue, Brightness.dark));
    await tester.pumpWidget(app(Brightness.light, reduced: true));
    await tester.pumpAndSettle();
    expect(colors.last, MonoPresentation.artworkSurface(Colors.blue, Brightness.light));
  });
}
