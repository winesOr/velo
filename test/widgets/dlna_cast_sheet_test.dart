import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/services/casting/dlna_device.dart';
import 'package:plezy/services/casting/dlna_http.dart';
import 'package:plezy/services/casting/dlna_sender.dart';
import 'package:plezy/widgets/overlay_sheet.dart';
import 'package:plezy/widgets/video_controls/sheets/dlna_cast_sheet.dart';

import '../test_helpers/theme.dart';

void main() {
  final tv = DlnaDevice(
    id: 'tv',
    name: 'Living room TV',
    controlUrl: Uri.parse('http://tv.test/control'),
    serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
  );
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  Future<void> pump(
    WidgetTester tester, {
    required Stream<List<DlnaDevice>> Function() discover,
    required Future<DlnaHandoffResult> Function(DlnaDevice) send,
    String? unavailable,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testMonoTokens]),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 560,
              child: DlnaCastSheet(discover: discover, onSend: send, unavailableReason: unavailable, onClose: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows real scan results, sends only once, and cancels discovery', (tester) async {
    var cancelled = 0;
    final scan = StreamController<List<DlnaDevice>>(
      onCancel: () {
        cancelled++;
      },
    );
    var sends = 0;
    final result = Completer<DlnaHandoffResult>();
    await pump(
      tester,
      discover: () => scan.stream,
      send: (_) {
        sends++;
        return result.future;
      },
    );
    expect(find.text(t.casting.searching), findsOneWidget);
    scan.add([tv]);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tv.name));
    await tester.tap(find.text(tv.name));
    await tester.pump();
    expect(sends, 1);
    expect(cancelled, 1);
    expect(find.text(t.casting.sending), findsOneWidget);
    result.complete(const DlnaHandoffResult(resumeAccepted: true));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(scan.close);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty scan can refresh and unavailable playback never scans', (tester) async {
    var scans = 0;
    Stream<List<DlnaDevice>> discover() {
      scans++;
      return Stream.value([]);
    }

    Future<DlnaHandoffResult> send(DlnaDevice _) async => const DlnaHandoffResult(resumeAccepted: true);
    await pump(tester, discover: discover, send: send);
    await tester.pumpAndSettle();
    expect(find.text(t.casting.noDevices), findsOneWidget);
    await tester.tap(find.text(t.casting.refresh));
    await tester.pumpAndSettle();
    expect(scans, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester, discover: discover, send: send, unavailable: t.casting.offlineUnavailable);
    expect(scans, 2);
    expect(find.text(t.casting.offlineUnavailable), findsOneWidget);
    expect(find.text(t.casting.refresh), findsNothing);
  });

  for (final uncertain in [false, true]) {
    testWidgets('send failure explains whether to check the TV ($uncertain)', (tester) async {
      await pump(
        tester,
        discover: () => Stream.value([tv]),
        send: (_) async => throw DlnaException(DlnaFailure.unconfirmed, mayBePlaying: uncertain),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(tv.name));
      await tester.pumpAndSettle();
      expect(find.text(uncertain ? t.casting.checkTv : t.casting.sendFailed), findsOneWidget);
      expect(find.text(tv.name), findsOneWidget);
    });
  }

  testWidgets('disposing panel cancels an active scan', (tester) async {
    var cancelled = false;
    final scan = StreamController<List<DlnaDevice>>(
      onCancel: () {
        cancelled = true;
      },
    );
    await pump(tester, discover: () => scan.stream, send: (_) async => const DlnaHandoffResult(resumeAccepted: true));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(cancelled, isTrue);
    await tester.runAsync(scan.close);
  });

  testWidgets('in-flight handoff prevents barrier and back dismissal', (tester) async {
    var canDismiss = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OverlaySheetHost(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => OverlaySheetController.of(context).show<void>(
                  canDismiss: () => canDismiss,
                  constraints: const BoxConstraints(maxWidth: 300),
                  builder: (_) => const Text('Handoff in progress'),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1, 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Handoff in progress'), findsOneWidget);
    canDismiss = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Handoff in progress'), findsNothing);
  });
}
