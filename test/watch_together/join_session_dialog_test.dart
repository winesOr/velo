import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/watch_together/widgets/join_session_dialog.dart';

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.en));

  Future<void> pumpDialog(WidgetTester tester, ValueChanged<String?> result) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result(await showJoinSessionDialog(context));
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final code in ['A', 'L6RNU', 'FILM_NIGHT-23', 'A' * 64]) {
    testWidgets('joins protocol room identifier $code without a demo length restriction', (tester) async {
      String? joined;
      await pumpDialog(tester, (value) => joined = value);
      await tester.enterText(find.byType(TextFormField), code.toLowerCase());
      await tester.tap(find.text(t.watchTogether.joinSession));
      await tester.pumpAndSettle();
      expect(joined, code);
    });
  }

  testWidgets('invalid invitation remains in form with an actionable validation message', (tester) async {
    String? joined;
    await pumpDialog(tester, (value) => joined = value);
    await tester.enterText(find.byType(TextFormField), 'wrong/invitation');
    await tester.tap(find.text(t.watchTogether.joinSession));
    await tester.pumpAndSettle();
    expect(joined, isNull);
    expect(find.text(t.watchTogether.sessionCodeInvalid), findsOneWidget);
  });

  testWidgets('clipboard preserves hyphens and underscores and does not silently truncate', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': ' film_night-23 '};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    String? joined;
    await pumpDialog(tester, (value) => joined = value);
    await tester.tap(find.byTooltip(t.watchTogether.pasteFromClipboard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.watchTogether.joinSession));
    await tester.pumpAndSettle();
    expect(joined, 'FILM_NIGHT-23');
  });
}
