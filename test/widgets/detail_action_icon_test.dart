import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/widgets/detail_action_icon.dart';

void main() {
  for (final glyph in [DetailActionGlyph.favorite, DetailActionGlyph.watched]) {
    testWidgets('$glyph switches between hollow and solid artwork-colored ink', (tester) async {
      for (final ink in [Colors.black, Colors.white]) {
        final paper = ink == Colors.white ? Colors.black : Colors.white;
        for (final selected in [false, true]) {
          final boundary = GlobalKey();
          await tester.pumpWidget(
            Center(
              child: RepaintBoundary(
                key: boundary,
                child: ColoredBox(
                  color: paper,
                  child: IconTheme(
                    data: IconThemeData(color: ink),
                    child: DetailActionIcon(glyph, selected: selected, size: 48),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await render.toImage();
            final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
            // (11, 9) inside both paths in their 24-unit view box, away from edges.
            final offset = 4 * (18 * image.width + 22);
            final channel = (selected ? ink : paper) == Colors.white ? 255 : 0;
            expect(pixels.getUint8(offset), channel);
            expect(pixels.getUint8(offset + 1), channel);
            expect(pixels.getUint8(offset + 2), channel);
            image.dispose();
          });
        }
      }
    });
  }
}
