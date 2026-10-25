import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/mixins/refreshable.dart';
import 'package:plezy/profiles/active_profile_provider.dart';
import 'package:plezy/profiles/profile.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/watch_together/models/watch_session.dart';
import 'package:plezy/watch_together/providers/watch_together_provider.dart';
import 'package:plezy/watch_together/screens/watch_together_screen.dart';
import 'package:provider/provider.dart';

import '../test_helpers/prefs.dart';
import '../test_helpers/tablet_screenshots.dart';

class _ProfileFixture extends ChangeNotifier implements ActiveProfileProvider {
  @override
  String get activeId => 'fixture-profile';
  @override
  Profile? get active => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// These are UI fixtures, not a claim of two-device playback verification.
class _RoomFixture extends WatchTogetherProvider {
  _RoomFixture({this.guest = false, this.reconnecting = false, this.media = false});
  final bool guest;
  final bool reconnecting;
  final bool media;

  @override
  WatchSession get session => WatchSession(
    sessionId: 'FILM_NIGHT-23',
    role: guest ? SessionRole.guest : SessionRole.host,
    controlMode: ControlMode.hostOnly,
    state: SessionState.connected,
  );

  @override
  bool get isInSession => true;
  @override
  bool get isHost => !guest;
  @override
  bool get isReconnectingRelay => reconnecting;
  @override
  bool get hasCurrentPlayback => media;
  @override
  String? get currentMediaTitle => media ? 'The current episode' : null;
  @override
  String? get currentMediaRatingKey => media ? 'fixture-item' : null;
  @override
  String? get currentMediaServerId => media ? 'disconnected-server' : null;
  @override
  List<Participant> get participants => const [
    Participant(peerId: 'host', displayName: 'Local viewer', isHost: true),
    Participant(peerId: 'guest', displayName: 'Remote viewer', isHost: false, isBuffering: true),
  ];
  @override
  int get participantCount => participants.length;
  @override
  bool canTransferHostTo(Participant participant) => false;
}

void main() {
  setUpAll(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    for (final family in ['FixtureText', 'monospace']) {
      await (FontLoader(family)..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    }
    await (FontLoader(
      'packages/material_symbols_icons/MaterialSymbolsRounded',
    )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
  });

  Future<void> pumpRoom(
    WidgetTester tester,
    _RoomFixture provider, {
    GlobalKey? screenKey,
    VoidCallback? onBack,
    double textScale = 1,
  }) async {
    addTearDown(provider.dispose);
    final theme = monoTheme(dark: true);
    await tester.pumpWidget(
      ChangeNotifierProvider<WatchTogetherProvider>.value(
        value: provider,
        child: InputModeTracker(
          child: MaterialApp(
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'FixtureText'),
              primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'FixtureText'),
              appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'FixtureText'),
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const ValueKey('together-fixture'),
              child: WatchTogetherScreen(key: screenKey, embedded: true, onBack: onBack),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final size in [const Size(390, 844), const Size(960, 540), const Size(820, 1180), const Size(1180, 820)]) {
    testWidgets('responsive real room presentation at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpRoom(tester, _RoomFixture());
      expect(find.text('FILM_NIGHT-23'), findsOneWidget);
      expect(find.text(t.watchTogether.connectedToRelay), findsOneWidget);
      expect(find.text(t.watchTogether.noMediaSelected), findsOneWidget);
      if (size.shortestSide >= 600) {
        await captureTablet(tester, find.byKey(const ValueKey('together-fixture')), 'together-${size.width.toInt()}');
      }
      expect(tester.takeException(), isNull);

      if (const bool.fromEnvironment('CAPTURE_FUSION')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('together-fixture')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final name = size.width < 760 ? 'phone' : 'tv';
          final file = File('docs/qa/fusion/together-$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets('guest without the host server cannot pretend to be ready or open wrong media', (tester) async {
    await pumpRoom(tester, _RoomFixture(guest: true, media: true));
    await tester.pump();
    expect(find.text(t.watchTogether.mediaUnavailable), findsOneWidget);
    expect(find.text(t.watchTogether.retryMedia), findsOneWidget);
    expect(find.text(t.watchTogether.joinCurrentPlayback), findsNothing);
    await tester.ensureVisible(find.text(t.watchTogether.retryMedia));
    await tester.tap(find.text(t.watchTogether.retryMedia));
    await tester.pump();
    expect(find.text(t.watchTogether.mediaUnavailable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('relay reconnect state and TV back route use the real shell callback', (tester) async {
    final key = GlobalKey();
    var backCount = 0;
    await pumpRoom(tester, _RoomFixture(reconnecting: true), screenKey: key, onBack: () => backCount++);
    expect(find.text(t.watchTogether.reconnectingRelay), findsOneWidget);
    (key.currentState! as FocusableTab).focusActiveTabIfReady();
    await tester.pump();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(backCount, 1);
  });

  testWidgets('narrow screen and large text preserve room actions without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpRoom(tester, _RoomFixture(), textScale: 2);
    await tester.ensureVisible(find.text(t.watchTogether.endSession));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty standalone entry exposes actual create and join flows without demo rooms', (tester) async {
    resetSharedPreferencesForTest();
    await SettingsService.getInstance();
    final profile = _ProfileFixture();
    final together = WatchTogetherProvider();
    addTearDown(profile.dispose);
    addTearDown(together.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WatchTogetherProvider>.value(value: together),
          ChangeNotifierProvider<ActiveProfileProvider>.value(value: profile),
        ],
        child: MaterialApp(home: const WatchTogetherScreen(embedded: true)),
      ),
    );
    await tester.pump();
    expect(find.text(t.watchTogether.noRecentRooms), findsOneWidget);
    expect(find.text('246810'), findsNothing);
    await tester.tap(find.text(t.watchTogether.createSession));
    await tester.pumpAndSettle();
    expect(find.text(t.watchTogether.controlModeQuestion), findsOneWidget);
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(together.isInSession, isFalse);
    await tester.tap(find.text(t.watchTogether.joinSession));
    await tester.pumpAndSettle();
    expect(find.text(t.watchTogether.joinInstructions), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
