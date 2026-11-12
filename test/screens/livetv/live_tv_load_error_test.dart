import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/screens/livetv/live_tv_load_error.dart';
import 'package:plezy/theme/mono_theme.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets('initial failure scrolls at 200 percent text size and retains the retry action', (tester) async {
    await _pumpError(
      tester,
      LiveTvLoadError(
        message: t.errors.unableToLoad(context: t.liveTv.whatsOn),
        onRetry: () {},
      ),
      largeText: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(find.text(t.common.retry));
    expect(find.text(t.common.retry), findsOneWidget);
  });

  testWidgets('refresh notice grows naturally and preserves mounted content when it appears', (tester) async {
    var mounts = 0;
    Widget notice(String? message) => LiveTvLoadError(
      message: message,
      onRetry: () {},
      content: _MountCounter(onMount: () => mounts++),
    );
    await _pumpError(tester, notice(null), largeText: true);
    await _pumpError(tester, notice(t.errors.unableToLoad(context: t.liveTv.whatsOn)), largeText: true);
    expect(tester.takeException(), isNull);
    expect(mounts, 1);
    expect(find.text('retained'), findsOneWidget);
    expect(find.byTooltip(t.common.retry), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)).height, greaterThanOrEqualTo(48));
    await _pumpError(tester, notice(null), largeText: true);
    expect(mounts, 1);
  });

  testWidgets('compact retry and TV up/back actions each fire once', (tester) async {
    var retries = 0;
    var up = 0;
    var back = 0;
    final focus = FocusNode(debugLabel: 'test_retry');
    addTearDown(focus.dispose);
    await _pumpError(
      tester,
      LiveTvLoadError(
        message: t.errors.unableToLoad(context: t.liveTv.guide),
        onRetry: () => retries++,
        focusNode: focus,
        autofocus: true,
        onNavigateUp: () => up++,
        onBack: () => back++,
        content: const Text('retained'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(retries, 1);
    expect(up, 1);
    expect(back, 1);
  });
}

Future<void> _pumpError(WidgetTester tester, Widget child, {bool largeText = false}) => tester.pumpWidget(
  TranslationProvider(
    child: InputModeTracker(
      child: MaterialApp(
        theme: monoTheme(dark: true),
        home: MediaQuery(
          data: MediaQueryData(size: const Size(320, 240), textScaler: TextScaler.linear(largeText ? 2 : 1)),
          child: Scaffold(body: SizedBox(width: 320, height: 240, child: child)),
        ),
      ),
    ),
  ),
);

class _MountCounter extends StatefulWidget {
  const _MountCounter({required this.onMount});
  final VoidCallback onMount;
  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const Text('retained');
}
