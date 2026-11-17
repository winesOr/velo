import 'dart:async';
import 'package:plezy/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  // Font loading sends system-font notifications. Load once in the real async
  // zone before any test mounts render objects that subscribe to those events.
  setUpAll(() async {
    await loadTabletFonts();
    await Future<void>.delayed(Duration.zero);
  });
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

  testWidgets('helper undo cancels a deferred write and expiry commits only once', (tester) async {
    final context = await _pumpHost(tester, size: const Size(390, 844), dark: true);
    addTearDown(() => AppToast.dismiss(immediately: true));
    bool? commit;
    unawaited(notifications.confirmUndoableAction(context, 'Removal pending').then((value) => commit = value));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(commit, isNull);
    await tester.tap(find.text(t.common.undo));
    await tester.pumpAndSettle();
    expect(commit, isFalse);

    commit = null;
    unawaited(notifications.confirmUndoableAction(context, 'Removal pending').then((value) => commit = value));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final hold = await tester.startGesture(tester.getCenter(find.text('Removal pending')));
    await tester.pump(const Duration(seconds: 7));
    expect(commit, isNull, reason: 'holding the notice pauses the undo window');
    await hold.cancel();
    await tester.pumpAndSettle();
    expect(commit, isTrue);

    AppToast.show(context, 'Old notice');
    await tester.pump();
    final interrupted = notifications.confirmUndoableAction(context, 'New removal');
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox());
    expect(await interrupted, isFalse, reason: 'overlay disposal cancels even during replacement');
  });

  testWidgets('new notices and pending work wait for the full undo window', (tester) async {
    final context = await _pumpHost(tester, size: const Size(390, 844), dark: true);
    addTearDown(() => AppToast.dismiss(immediately: true));
    bool? commit;
    unawaited(notifications.confirmUndoableAction(context, 'Removal waiting').then((value) => commit = value));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    notifications.showSuccessSnackBar(context, 'Another notice');
    final pending = AppToast.pending(context);
    pending.update('Work finished');
    await tester.pump(const Duration(milliseconds: 250));
    expect(commit, isNull);
    expect(find.text('Removal waiting'), findsOneWidget);
    expect(find.text('Another notice'), findsNothing);
    expect(find.text('Work finished'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(commit, isNull, reason: 'replacement must not shorten five seconds');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(commit, isTrue);
    expect(find.text('Another notice'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(AppToast), findsNothing);
  });

  testWidgets('queued removals each retain their own cancellable undo window', (tester) async {
    final context = await _pumpHost(tester, size: const Size(390, 844), dark: true);
    addTearDown(() => AppToast.dismiss(immediately: true));
    bool? first;
    bool? second;
    unawaited(notifications.confirmUndoableAction(context, 'First removal').then((v) => first = v));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    unawaited(notifications.confirmUndoableAction(context, 'Second removal').then((v) => second = v));
    await tester.pump(const Duration(seconds: 3));
    expect(first, isNull);
    expect(second, isNull);
    await tester.tap(find.text(t.common.undo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(first, isFalse);
    expect(second, isNull);
    expect(find.text('Second removal'), findsOneWidget);
    await tester.tap(find.text(t.common.undo));
    await tester.pumpAndSettle();
    expect(second, isFalse);
  });

  testWidgets('interleaved pending work cannot commit an undo that has not been displayed', (tester) async {
    final context = await _pumpHost(tester, size: const Size(390, 844), dark: true);
    addTearDown(() => AppToast.dismiss(immediately: true));
    bool? first;
    bool? second;
    unawaited(notifications.confirmUndoableAction(context, 'A removal').then((v) => first = v));
    await tester.pump();
    notifications.showSuccessSnackBar(context, 'Ordinary notice');
    unawaited(notifications.confirmUndoableAction(context, 'B removal').then((v) => second = v));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(first, isTrue);
    for (var frame = 0; frame < 20 && find.text('Ordinary notice').evaluate().isEmpty; frame++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(find.text('Ordinary notice'), findsOneWidget);
    final pending = AppToast.pending(context);
    pending.update('Pending complete');
    await tester.pump(const Duration(milliseconds: 300));
    expect(second, isNull);
    expect(find.text('B removal'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    for (var frame = 0; frame < 20 && find.text('B removal').evaluate().isEmpty; frame++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(second, isNull);
    expect(find.text('B removal'), findsOneWidget);
    await tester.tap(find.text(t.common.undo));
    await tester.pumpAndSettle();
    expect(second, isFalse);
  });

  testWidgets('closed routes discard queued retries and invalid undo operations', (tester) async {
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        theme: monoTheme(dark: true),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (context) {
                  source = context;
                  return const Scaffold(body: Text('Source route'));
                },
              ),
            ),
            child: const Text('Open source'),
          ),
        ),
      ),
    );
    addTearDown(() => AppToast.dismiss(immediately: true));
    await tester.tap(find.text('Open source'));
    await tester.pumpAndSettle();
    final first = notifications.confirmUndoableAction(source, 'Valid removal');
    await tester.pump();
    var retried = false;
    notifications.showErrorSnackBar(
      source,
      'Obsolete retry',
      actionLabel: t.common.retry,
      onAction: () => retried = true,
    );
    var valid = true;
    bool? second;
    unawaited(
      notifications
          .confirmUndoableAction(source, 'Invalid removal', canCommit: () => valid)
          .then((value) => second = value),
    );
    valid = false;
    Navigator.of(source).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (var frame = 0; frame < 20 && source.mounted; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(source.mounted, isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(await first, isTrue);
    expect(second, isFalse);
    expect(find.text('Obsolete retry'), findsNothing);
    expect(find.text('Invalid removal'), findsNothing);
    expect(retried, isFalse);
  });

  testWidgets('disposing the overlay cancels active and queued removals', (tester) async {
    final context = await _pumpHost(tester, size: const Size(390, 844), dark: true);
    final first = notifications.confirmUndoableAction(context, 'Active removal');
    await tester.pump();
    final second = notifications.confirmUndoableAction(context, 'Queued removal');
    await tester.pumpWidget(const SizedBox());
    expect(await first, isFalse);
    expect(await second, isFalse);
  });

  testWidgets('toast slot merges, pauses, replaces and keeps page focus', (tester) async {
    final context = await _pumpHost(tester, size: const Size(390, 844), dark: true);
    addTearDown(() => AppToast.dismiss(immediately: true));
    final focus = FocusNode();
    addTearDown(focus.dispose);
    FocusScope.of(context).requestFocus(focus);
    await tester.pump();
    final before = FocusManager.instance.primaryFocus;
    for (var index = 0; index < 3; index++) {
      notifications.showSuccessSnackBar(context, 'Saved');
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(AppToast), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, before);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Saved, Repeated 3 times'), findsOneWidget);
    semantics.dispose();
    final hold = await tester.startGesture(tester.getCenter(find.text('Saved')));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Saved'), findsOneWidget);
    await hold.cancel();
    await tester.pump();
    var actions = 0;
    final handle = AppToast.show(
      context,
      'Try again',
      type: AppToastType.error,
      actionLabel: 'Retry',
      onAction: () => actions++,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump(const Duration(milliseconds: 130));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    expect(actions, 1);
    expect(find.text('Try again'), findsOneWidget);
    handle.update('Done');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    AppToast.dismiss(immediately: true);
    await tester.pump();
    final pending = AppToast.pending(context);
    await tester.pump(const Duration(milliseconds: 299));
    expect(find.byType(AppToast), findsNothing);
    pending.update('Fast completion');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Fast completion'), findsOneWidget);
    expect(find.text(t.common.loading), findsNothing);
    // A close-to-expiry slot cannot retire its delayed successor.
    AppToast.show(context, 'Old', duration: const Duration(milliseconds: 100));
    await tester.pump();
    final delayed = AppToast.pending(context);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text(t.common.loading), findsOneWidget);
    delayed.update('A', type: AppToastType.info);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump(const Duration(milliseconds: 130));
    AppToast.show(context, 'B');
    await tester.pump(const Duration(milliseconds: 40));
    AppToast.show(context, 'A');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('A'), findsOneWidget);
    final fade = find.ancestor(of: find.text('A'), matching: find.byType(Opacity)).first;
    expect(tester.widget<Opacity>(fade).opacity, 1);
    AppToast.dismiss(immediately: true);
    await tester.pump();
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final toolbarContext = await _pumpHost(tester, size: const Size(390, 844), dark: true, toolbar: true);
    notifications.showSuccessSnackBar(toolbarContext, 'Toolbar notice');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Toolbar notice'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(AppToast)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy + 8),
    );
    AppToast.dismiss(immediately: true);
    await tester.pump();
  });

  testWidgets('TV menu consumes only available action and respects modal input', (tester) async {
    TvDetectionService.debugSetAppleTVOverride(true);
    final context = await _pumpHost(tester, size: const Size(960, 540), dark: true);
    addTearDown(() => AppToast.dismiss(immediately: true));
    var actions = 0;
    final handle = AppToast.show(
      context,
      'Failed',
      type: AppToastType.error,
      actionLabel: 'Retry',
      onAction: () => actions++,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final key = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.contextMenu,
      logicalKey: LogicalKeyboardKey.contextMenu,
      timeStamp: Duration.zero,
    );
    expect(AppToast.handleMenuKey(key), isTrue);
    expect(AppToast.handleMenuKey(key), isTrue);
    expect(actions, 1);
    AppToast.handleMenuKey(
      KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.contextMenu,
        logicalKey: LogicalKeyboardKey.contextMenu,
        timeStamp: const Duration(milliseconds: 1),
      ),
    );
    handle.update('Another failure', type: AppToastType.error, actionLabel: 'Retry', onAction: () => actions++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump(const Duration(milliseconds: 130));
    final dialog = showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: TextField(autofocus: true)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(AppToast.handleMenuKey(key), isFalse);
    expect(actions, 1);
    Navigator.of(context).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await dialog;
    handle.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    AppToast.show(context, 'No action');
    await tester.pump();
    expect(AppToast.handleMenuKey(key), isFalse);
    AppToast.dismiss(immediately: true);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('toast keeps separate status and alert roles without duplicate announcements', (tester) async {
    final context = await _pumpHost(tester, size: const Size(390, 844), dark: true);
    addTearDown(() => AppToast.dismiss(immediately: true));
    final semantics = tester.ensureSemantics();
    final announcements = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
      message,
    ) async {
      announcements.add(message);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        SystemChannels.accessibility,
        null,
      ),
    );
    Finder region(SemanticsRole role) =>
        find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.role == role);
    final statusId = tester.getSemantics(region(SemanticsRole.status)).id;
    final alertId = tester.getSemantics(region(SemanticsRole.alert)).id;
    AppToast.show(context, 'Saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getSemantics(region(SemanticsRole.status)).label, 'Saved');
    expect(tester.getSemantics(region(SemanticsRole.alert)).label, isEmpty);
    AppToast.show(context, 'Failed', type: AppToastType.error);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(tester.getSemantics(region(SemanticsRole.status)).label, isEmpty);
    expect(tester.getSemantics(region(SemanticsRole.alert)).label, 'Failed');
    expect(find.bySemanticsLabel('Failed'), findsOneWidget);
    expect(announcements, isEmpty);
    AppToast.dismiss(immediately: true);
    await tester.pump();
    expect(tester.getSemantics(region(SemanticsRole.status)).id, statusId);
    expect(tester.getSemantics(region(SemanticsRole.alert)).id, alertId);
    expect(tester.getSemantics(region(SemanticsRole.alert)).label, isEmpty);
    semantics.dispose();
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull);
        final bounds = tester.getRect(find.byType(AppToast));
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
  bool toolbar = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: tabletFixtureTheme(monoTheme(dark: dark)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: AppToastHost(child: child!),
      ),
      home: Scaffold(
        appBar: toolbar ? AppBar(title: const Text('Toolbar')) : null,
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
