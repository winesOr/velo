import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/media_progress_bar.dart';
import 'package:plezy/widgets/unwatched_count_badge.dart';
import 'package:plezy/widgets/watched_indicator.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
  });

  Future<void> pump(WidgetTester tester, WatchedIndicator indicator) => tester.pumpWidget(
    MaterialApp(
      theme: monoTheme(dark: true),
      home: SizedBox(width: 200, height: 300, child: indicator),
    ),
  );

  final watchedMovie = testMediaItem(id: 'movie', kind: MediaKind.movie, viewCount: 1);

  testWidgets('shows the watched checkmark by default', (tester) async {
    await pump(tester, WatchedIndicator(item: watchedMovie));

    expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
  });

  testWidgets('the check is legible over a translucent disc on light and dark thumbnails', (tester) async {
    await tester.runAsync(() async {
      await (FontLoader(
        'packages/material_symbols_icons/MaterialSymbolsRounded',
      )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
    });
    for (final size in WatchedIndicatorSize.values) {
      for (final background in [Colors.black, Colors.white]) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: monoTheme(dark: background == Colors.white),
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: background,
                  child: SizedBox.square(
                    dimension: 48,
                    child: WatchedIndicator(item: watchedMovie, size: size),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 3);
          try {
            final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
            final radius = (size.checkPadding + size.checkIconSize / 2) * 3;
            final cx = image.width - size.checkInset * 3 - radius;
            final cy = size.checkInset * 3 + radius;
            int redAt(double x, double y) => pixels.getUint8((y.floor() * image.width + x.floor()) * 4);
            final disc = redAt(cx, cy - radius * .72);
            expect(disc, background == Colors.black ? inInclusiveRange(200, 218) : 255);
            int darkPixels = 0;
            for (var dy = -radius ~/ 2; dy <= radius ~/ 2; dy++) {
              for (var dx = -radius ~/ 2; dx <= radius ~/ 2; dx++) {
                if (redAt(cx + dx, cy + dy) < disc - 100) darkPixels++;
              }
            }
            expect(darkPixels, greaterThan(30), reason: 'the check itself must remain visible inside the disc');
          } finally {
            image.dispose();
          }
        });
      }
    }
  });

  testWidgets('hides only the checkmark when watched indicators are off (#1998)', (tester) async {
    await SettingsService.instance.write(SettingsService.showWatchedIndicators, false);
    final partiallyWatchedShow = testMediaItem(id: 'show', kind: MediaKind.show, leafCount: 10, viewedLeafCount: 4);
    final inProgressMovie = testMediaItem(
      id: 'movie-2',
      kind: MediaKind.movie,
      durationMs: 100000,
      viewOffsetMs: 50000,
    );

    await pump(tester, WatchedIndicator(item: watchedMovie));
    expect(find.byIcon(Symbols.check_rounded), findsNothing);

    await pump(tester, WatchedIndicator(item: partiallyWatchedShow));
    expect(find.byType(UnwatchedCountBadge), findsOneWidget, reason: 'unwatched counts are a separate pref');

    await pump(tester, WatchedIndicator(item: inProgressMovie));
    expect(find.byType(MediaProgressBar), findsOneWidget, reason: 'progress bars are not indicators');
  });
}
