import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/widgets/app_menu.dart';
import 'package:plezy/widgets/overlay_sheet.dart';

import '../test_helpers/theme.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform adaptive menu opens beside the trigger and returns its real choice', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform, extensions: const [testMonoTokens]),
          home: OverlaySheetHost(
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 60, left: 16),
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        selected = await showAdaptiveAppMenu<String>(
                          context,
                          entries: const [
                            AppMenuItem(value: 'emby', label: 'Emby'),
                            AppMenuItem(value: 'plex', label: 'Plex'),
                          ],
                        );
                      },
                      child: const Text('Sources'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sources'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Emby')).dy, lessThan(200));
      expect(find.byType(AppMenuSheet<String>), findsNothing);
      await tester.tap(find.text('Plex'));
      await tester.pumpAndSettle();
      expect(selected, 'plex');
      expect(find.text('Emby'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
