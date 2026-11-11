import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/dialogs.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/utils/snackbar_helper.dart' as notifications;
import 'package:plezy/widgets/app_dialog.dart';
import 'package:plezy/widgets/app_menu.dart';
import 'package:plezy/widgets/pending_auth_dialog.dart';
import 'package:plezy/widgets/tv_virtual_keyboard.dart';

import '../test_helpers/tablet_screenshots.dart';

const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  final launchedUrls = <String>[];

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    PlatformDetector.debugSetIsDesktopOSOverride(false);
    TvDetectionService.debugSetAppleTVOverride(false);
    launchedUrls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_urlLauncherChannel, (
      call,
    ) async {
      switch (call.method) {
        case 'launch':
          launchedUrls.add((call.arguments as Map)['url'] as String);
          return true;
        case 'canLaunch':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    PlatformDetector.debugSetIsDesktopOSOverride(null);
    TvDetectionService.debugSetAppleTVOverride(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _urlLauncherChannel,
      null,
    );
  });

  for (final dark in [false, true]) {
    testWidgets('full HD TV keyboard stays within its dialog dark=$dark', (tester) async {
      TvDetectionService.debugSetAppleTVOverride(true);
      final context = await _pumpHost(tester, size: const Size(1920, 1080), dark: dark);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      showTvVirtualKeyboard(context: context, controller: controller);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    });

    testWidgets('wide authorization QR and text fit together dark=$dark', (tester) async {
      final context = await _pumpHost(tester, size: const Size(1280, 720), dark: dark);
      var cancelled = false;
      final result = showScopedDialog<void>(
        context: context,
        builder: (_) => PendingAuthDialog(
          title: 'Connect account',
          body: 'Scan this code with your phone to authorize this device.',
          url: 'https://example.invalid/activate',
          openLabel: 'Open in browser',
          onCancel: () => cancelled = true,
          children: const [],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      await expectLater(result, completes);
    });

    testWidgets('TV authorization stays reachable with D-pad at 200% dark=$dark', (tester) async {
      await TvDetectionService.getInstance();
      TvDetectionService.setForceTVSync(true);
      addTearDown(() => TvDetectionService.setForceTVSync(false));
      final context = await _pumpHost(tester, size: const Size(1280, 720), dark: dark, textScale: 2);
      var cancelled = false;
      final result = showScopedDialog<void>(
        context: context,
        builder: (_) => PendingAuthDialog(
          title: 'Connect account',
          body: 'Scan this code with your phone to authorize this device.',
          url: 'https://example.invalid/activate',
          openLabel: 'Open in browser',
          onCancel: () => cancelled = true,
          children: const [Text('ABCD-EFGH-IJKL-MNOP')],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dialogBounds = tester.getRect(find.byType(AppAlertDialog));
      expect(dialogBounds.left, greaterThanOrEqualTo(0));
      expect(dialogBounds.top, greaterThanOrEqualTo(0));
      expect(dialogBounds.right, lessThanOrEqualTo(1280));
      expect(dialogBounds.bottom, lessThanOrEqualTo(720));
      expect(tester.takeException(), isNull);

      final open = find.text('Open in browser');
      await _focusWithDpad(tester, open);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(launchedUrls, ['https://example.invalid/activate']);

      final cancel = find.text(t.common.cancel);
      await _focusWithDpad(tester, cancel);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
      await expectLater(result, completes);
      expect(tester.takeException(), isNull);
    });

    for (final size in [const Size(360, 640), const Size(844, 390)]) {
      testWidgets('confirmation remains readable at 200% in $size dark=$dark', (tester) async {
        final context = await _pumpHost(tester, size: size, dark: dark, textScale: 2);
        final result = showConfirmDialog(
          context,
          title: 'Remove downloaded media?',
          message: List.filled(8, 'The original files on your media server will remain available.').join(' '),
          confirmText: 'Remove download',
          cancelText: 'Keep download',
          isDestructive: true,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final cancel = find.text('Keep download');
        expect(cancel, findsOneWidget);
        expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(size.height));
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        await expectLater(result, completion(false));
      });
    }

    for (final type in notifications.SnackBarType.values) {
      testWidgets('$type notification wraps at 200% dark=$dark', (tester) async {
        final context = await _pumpHost(tester, size: const Size(320, 568), dark: dark, textScale: 2);
        const message = 'Your library could not be updated. Check the connection and try again.';
        notifications.showSnackBar(context, message, type: type, dismissible: true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final bounds = tester.getRect(find.byType(SnackBar));
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(320));
        expect(bounds.top, greaterThanOrEqualTo(0));
        await tester.tap(find.text(message));
        await tester.pumpAndSettle();
        expect(find.text(message), findsNothing);
      });
    }

    testWidgets('anchored menu keeps long labels in a narrow viewport dark=$dark', (tester) async {
      final context = await _pumpHost(tester, size: const Size(320, 568), dark: dark, textScale: 2);
      final result = showAdaptiveAppMenu<String>(
        context,
        entries: const [
          AppMenuItem(value: 'recent', label: 'Recently added to the media library'),
          AppMenuItem(value: 'title', label: 'Sort by title'),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final choice = find.text('Sort by title');
      expect(tester.getRect(choice).right, lessThanOrEqualTo(320));
      await tester.tap(choice);
      await tester.pumpAndSettle();
      await expectLater(result, completion('title'));
    });
  }
}

Future<void> _focusWithDpad(WidgetTester tester, Finder target) async {
  bool hasFocus() {
    final focusNode = FocusManager.instance.primaryFocus;
    final focusContext = focusNode?.context;
    if (focusNode is FocusScopeNode) return false;
    if (focusContext == null) return false;
    final targetElement = target.evaluate().single;
    var focused = identical(focusContext, targetElement);
    targetElement.visitAncestorElements((ancestor) {
      focused = focused || identical(ancestor, focusContext);
      return !focused;
    });
    return focused;
  }

  for (var step = 0; step < 20 && !hasFocus(); step++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
  }
  expect(hasFocus(), isTrue, reason: 'target must be reachable with the D-pad');
}

Future<BuildContext> _pumpHost(
  WidgetTester tester, {
  required Size size,
  required bool dark,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadTabletFonts();
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: tabletFixtureTheme(monoTheme(dark: dark)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) {
              hostContext = context;
              return const Text('Media library');
            },
          ),
        ),
      ),
    ),
  );
  return hostContext;
}
