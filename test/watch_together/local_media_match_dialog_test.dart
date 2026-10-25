import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_part.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/media/media_version.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/utils/media_server_http_client.dart';
import 'package:plezy/watch_together/widgets/local_media_match_dialog.dart';
import 'package:provider/provider.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/multi_server_fixtures.dart';

class _MatchClient implements MediaServerClient {
  _MatchClient(this.id, {this.versions = const [], this.search});
  final String id;
  final List<MediaVersion> versions;
  final Future<List<MediaItem>> Function(String)? search;
  final List<String> queries = [];
  int fetches = 0;
  @override
  ServerId get serverId => ServerId(id);
  @override
  String get serverName => 'Server $id';
  @override
  MediaBackend get backend => MediaBackend.plex;
  @override
  Future<List<MediaItem>> searchItems(
    String query, {
    int limit = 100,
    AbortController? abort,
    Set<String> excludedLibraryIds = const {},
  }) async {
    queries.add(query);
    return search == null ? [testMediaItem(id: 'shared-id', title: 'Local episode')] : await search!(query);
  }

  @override
  Future<MediaItem?> fetchItem(String itemId) async {
    fetches++;
    return testMediaItem(
      id: itemId,
      title: 'Local episode',
      kind: MediaKind.episode,
      parentIndex: 2,
      index: 3,
      mediaVersions: versions,
    );
  }

  @override
  void close() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.en));

  Future<void> pumpDialog(
    WidgetTester tester,
    List<_MatchClient> clients,
    ValueChanged<LocalMediaSelection?> result, {
    double textScale = 1,
  }) async {
    final servers = testMultiServer(clients: clients).provider;
    await tester.pumpWidget(
      ChangeNotifierProvider<MultiServerProvider>.value(
        value: servers,
        child: InputModeTracker(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async => result(
                    await showDialog<LocalMediaSelection>(
                      context: context,
                      builder: (_) => const LocalMediaMatchDialog(hostTitle: 'Room episode'),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, t.common.search));
    await tester.pumpAndSettle();
  }

  testWidgets('searches online sources but never assigns a result without explicit confirmation', (tester) async {
    final client = _MatchClient('one');
    LocalMediaSelection? selected;
    await pumpDialog(tester, [client], (result) => selected = result);
    expect(client.queries, isEmpty);
    await search(tester);
    expect(client.queries, ['Room episode']);
    expect(selected, isNull);
    await tester.tap(find.text('Local episode'));
    await tester.pumpAndSettle();
    expect(find.text(t.watchTogether.confirmMatch), findsOneWidget);
    expect(selected, isNull);
    expect(find.textContaining('S2 · E3'), findsOneWidget);
    await tester.tap(find.text(t.watchTogether.useMatch));
    await tester.pumpAndSettle();
    expect(selected?.item.serverId, 'one');
    expect(selected?.item.id, 'shared-id');
  });

  testWidgets('same item IDs on different servers remain separate explicit choices', (tester) async {
    final first = _MatchClient('one');
    final second = _MatchClient('two');
    LocalMediaSelection? selected;
    await pumpDialog(tester, [first, second], (result) => selected = result);
    await search(tester);
    expect(find.text('Server one'), findsOneWidget);
    expect(find.text('Server two'), findsOneWidget);
    await tester.tap(find.text('Server two'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.watchTogether.useMatch));
    await tester.pumpAndSettle();
    expect(first.fetches, 0);
    expect(second.fetches, 1);
    expect(selected?.item.serverId, 'two');
  });

  testWidgets('requires a deliberate version choice before confirming matching cut', (tester) async {
    const theatrical = MediaVersion(id: 'theatrical', name: 'Theatrical');
    const directors = MediaVersion(id: 'directors', name: 'Director cut');
    LocalMediaSelection? selected;
    await pumpDialog(tester, [
      _MatchClient('one', versions: [theatrical, directors]),
    ], (value) => selected = value);
    await search(tester);
    await tester.tap(find.text('Local episode'));
    await tester.pumpAndSettle();
    expect(find.text('Theatrical'), findsOneWidget);
    expect(find.text(t.watchTogether.confirmMatch), findsNothing);
    await tester.tap(find.text('Director cut'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.textContaining('Director cut'), findsOneWidget);
    await tester.tap(find.text(t.watchTogether.useMatch));
    await tester.pumpAndSettle();
    expect(selected?.version?.id, 'directors');
  });

  testWidgets('cancelling confirmation never returns a match', (tester) async {
    LocalMediaSelection? selected;
    await pumpDialog(tester, [_MatchClient('one')], (value) => selected = value);
    await search(tester);
    await tester.tap(find.text('Local episode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.cancel).last);
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.byType(LocalMediaMatchDialog), findsOneWidget);
  });

  testWidgets('typing invalidates an older search even if server ignores abort', (tester) async {
    final old = Completer<List<MediaItem>>();
    final client = _MatchClient(
      'one',
      search: (query) => query == 'Room episode' ? old.future : Future.value([testMediaItem(title: 'New result')]),
    );
    await pumpDialog(tester, [client], (_) {});
    await tester.tap(find.widgetWithText(TextButton, t.common.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'New query');
    await search(tester);
    expect(find.text('New result'), findsOneWidget);
    old.complete([testMediaItem(title: 'Stale result')]);
    await tester.pumpAndSettle();
    expect(find.text('Stale result'), findsNothing);
  });

  testWidgets('inaccessible versions cannot be confirmed or silently defaulted', (tester) async {
    const unavailable = MediaVersion(
      id: 'offline',
      parts: [MediaPart(id: 'part', exists: false)],
    );
    await pumpDialog(tester, [
      _MatchClient('one', versions: [unavailable]),
    ], (_) {});
    await search(tester);
    await tester.tap(find.text('Local episode'));
    await tester.pumpAndSettle();
    expect(find.text(t.watchTogether.matchSearchFailed), findsOneWidget);
    expect(find.text(t.watchTogether.confirmMatch), findsNothing);
  });

  testWidgets('small viewport and large text remain scrollable without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpDialog(tester, [_MatchClient('one')], (_) {}, textScale: 2);
    await tester.ensureVisible(find.widgetWithText(TextButton, t.common.search));
    await search(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Local episode'), findsOneWidget);
  });

  testWidgets('D-pad down reaches Search and Select executes search', (tester) async {
    final client = _MatchClient('one');
    await pumpDialog(tester, [client], (_) {});
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TogetherMatchSearch');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(client.queries, ['Room episode']);
  });
}
