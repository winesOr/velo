import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:plezy/connection/connection.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/screens/plex_match_screen.dart';
import 'package:plezy/screens/settings/add_plex_account_screen.dart';
import 'package:plezy/screens/settings/edit_jellyfin_connection_screen.dart';
import 'package:plezy/screens/settings/licenses_screen.dart';
import 'package:plezy/screens/sync/sync_scan_screen.dart';
import 'package:plezy/services/plex_api_cache.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:provider/provider.dart';

import '../test_helpers/backend_client_fixtures.dart';
import '../test_helpers/media_items.dart';
import '../test_helpers/multi_server_fixtures.dart';
import '../test_helpers/tablet_screenshots.dart';

void main() {
  setUpAll(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    LicenseRegistry.reset();
    LicenseRegistry.addLicense(
      () => Stream.value(LicenseEntryWithLineBreaks(['Fixture package'], 'Fixture license text.\n' * 30)),
    );
  });

  setUp(() {
    PlatformDetector.debugSetIsDesktopOSOverride(false);
    TvDetectionService.debugSetAppleTVOverride(false);
  });
  tearDown(() {
    PlatformDetector.debugSetIsDesktopOSOverride(null);
    TvDetectionService.debugSetAppleTVOverride(null);
  });

  for (final dark in [true, false]) {
    testWidgets('Plex matching empty result stays readable at 200% dark=$dark', (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      PlexApiCache.initialize(database);
      addTearDown(database.close);
      final clients = testMultiServer(
        clients: [
          testPlexClient(
            serverId: ServerId('fixture-server'),
            handler: (_) async => http.Response('{"MediaContainer":{"SearchResult":[]}}', 200),
          ),
        ],
      );
      await _pump(
        tester,
        ChangeNotifierProvider<MultiServerProvider>.value(
          value: clients.provider,
          child: PlexMatchScreen(
            metadata: testMediaItem(id: 'fixture-media', serverId: 'fixture-server', title: 'A long film title'),
          ),
        ),
        dark: dark,
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Plex sign-in choices remain reachable at 200% dark=$dark', (tester) async {
      await _pump(tester, const AddPlexAccountScreen(), dark: dark);
      expect(find.text(t.auth.signInWithPlex), findsWidgets);
      await tester.ensureVisible(find.text(t.auth.showQRCode));
      expect(tester.takeException(), isNull);
    });

    testWidgets('connection editor handles a long server name at 200% dark=$dark', (tester) async {
      await _pump(
        tester,
        EditJellyfinConnectionScreen(
          connection: JellyfinConnection(
            id: 'fixture',
            baseUrl: 'https://media.example.invalid',
            serverName: 'A long media server name for layout verification',
            serverMachineId: 'fixture-server',
            userId: 'fixture-user',
            userName: 'Fixture',
            accessToken: '',
            deviceId: 'fixture-device',
            createdAt: DateTime(2026),
          ),
        ),
        dark: dark,
      );
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.ensureVisible(find.text(t.common.save));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('license list and detail remain scrollable at 200% in both themes', (tester) async {
    for (final dark in [true, false]) {
      await _pump(tester, const LicensesScreen(), dark: dark);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fixture package'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fixture license text.'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('TV sync scanner offers a readable phone-only fallback', (tester) async {
    TvDetectionService.debugSetAppleTVOverride(true);
    await _pump(tester, const SyncScanScreen(), dark: true, size: const Size(1920, 1080));
    expect(find.text(t.auth.syncPhoneOnly), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, Widget screen, {required bool dark, Size size = const Size(360, 640)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadTabletFonts();
  await tester.pumpWidget(
    MaterialApp(
      theme: tabletFixtureTheme(monoTheme(dark: dark)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: screen,
    ),
  );
  await tester.pump();
}
