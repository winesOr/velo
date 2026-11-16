import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/widgets/app_menu.dart';
import 'package:plezy/widgets/app_glass_surface.dart';
import 'package:plezy/widgets/overlay_sheet.dart';

import '../test_helpers/theme.dart';

void main() {
  testWidgets('home options has one title and opens below the right edge of its trigger', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final triggerKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testMonoTokens]),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 60, right: 24),
              child: Builder(
                builder: (context) => IconButton(
                  key: triggerKey,
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {
                    final box = triggerKey.currentContext!.findRenderObject()! as RenderBox;
                    showAppMenu<String>(
                      context,
                      title: 'Home options',
                      anchorRect: box.localToGlobal(Offset.zero) & box.size,
                      anchorAlignment: AppMenuAnchorAlignment.end,
                      entries: const [AppMenuItem(value: 'libraries', label: 'Browse all media')],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final trigger = tester.getRect(find.byKey(triggerKey));
    await tester.tap(find.byKey(triggerKey));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byType(AppGlassSurface).last);
    expect(panel.top, trigger.bottom + 9);
    expect(panel.right, trigger.right);
    expect(find.text('Home options'), findsOneWidget);
    expect(find.text('Options'), findsNothing);
    expect(find.text('Browse all media'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
