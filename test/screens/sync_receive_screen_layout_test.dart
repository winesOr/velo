import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/screens/sync/sync_receive_screen.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:provider/provider.dart';

import '../test_helpers/prefs.dart';
import '../test_helpers/profile_stack.dart';
import '../test_helpers/tablet_screenshots.dart';

void main() {
  for (final dark in [true, false]) {
    testWidgets('TV pairing startup failure remains readable at 200% dark=$dark', (tester) async {
      resetSharedPreferencesForTest();
      LocaleSettings.setLocaleSync(AppLocale.en);
      TvDetectionService.debugSetAppleTVOverride(true);
      addTearDown(() => TvDetectionService.debugSetAppleTVOverride(null));
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await loadTabletFonts();
      final stack = await ProfileStack.create();
      addTearDown(stack.dispose);

      // The production screen owns the receiver. Force a deterministic socket
      // failure so this render test never opens a pairing port on the host.
      await IOOverrides.runZoned(
        () async {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                Provider.value(value: stack.storage),
                Provider.value(value: stack.connections),
                Provider.value(value: stack.profiles),
                Provider.value(value: stack.profileConnections),
                Provider.value(value: stack.plexHome),
              ],
              child: MaterialApp(
                theme: tabletFixtureTheme(monoTheme(dark: dark)),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const SyncReceiveScreen(),
              ),
            ),
          );
          for (var attempt = 0; attempt < 20; attempt++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
            await tester.pump(const Duration(milliseconds: 20));
            if (find.textContaining('SocketException').evaluate().isNotEmpty) break;
          }
          expect(find.byType(SyncReceiveScreen), findsOneWidget);
          expect(find.textContaining('SocketException'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        serverSocketBind: (address, port, {backlog = 0, v6Only = false, shared = false}) async =>
            throw const SocketException('Pairing fixture is offline'),
      );
    });
  }
}
