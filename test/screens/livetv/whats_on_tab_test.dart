import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/server_capabilities.dart';
import 'package:plezy/models/livetv_hub_result.dart';
import 'package:plezy/models/livetv_program.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/screens/livetv/tabs/whats_on_tab.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/services/plex_client.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/active_client_scope.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/media_items.dart';
import '../../test_helpers/multi_server_fixtures.dart';
import '../../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    resetSharedPreferencesForTest();
    await SettingsService.getInstance();
  });

  testWidgets('all failed servers show safe retry and keyboard retry restores content', (tester) async {
    final client = _HubClient('a');
    final key = await _pumpTab(tester, [client]);
    client.fail(0);
    await tester.pumpAndSettle();
    expect(find.text(t.errors.unableToLoad(context: t.liveTv.whatsOn)), findsOneWidget);
    expect(find.text(t.liveTv.noPrograms), findsNothing);
    expect(find.textContaining('private-server'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    key.currentState!.focusFirstHub();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'whats_on_retry');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(client.requests, hasLength(2));
    client.complete(1, 'Recovered show');
    await tester.pumpAndSettle();
    expect(find.text('Recovered show'), findsOneWidget);
    expect(find.text(t.common.retry), findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('whats_on_retry'));
  });

  testWidgets('successful empty data and no eligible servers remain empty rather than errors', (tester) async {
    final client = _HubClient('a');
    await _pumpTab(tester, [client]);
    client.completeEmpty(0);
    await tester.pumpAndSettle();
    expect(find.text(t.liveTv.noPrograms), findsOneWidget);
    expect(find.text(t.common.retry), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpTab(tester, []);
    await tester.pumpAndSettle();
    expect(find.text(t.liveTv.noPrograms), findsOneWidget);
    expect(find.text(t.common.retry), findsNothing);
  });

  testWidgets('partial failure keeps successful hubs with retry instead of discarding them', (tester) async {
    final a = _HubClient('a');
    final b = _HubClient('b');
    await _pumpTab(tester, [a, b]);
    a.fail(0);
    await tester.pump();
    b.complete(0, 'Available show');
    await tester.pumpAndSettle();
    expect(find.text('Available show'), findsOneWidget);
    expect(find.byTooltip(t.common.retry), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('failed refresh preserves old hubs and a successful empty retry clears them', (tester) async {
    final client = _HubClient('a');
    final key = await _pumpTab(tester, [client]);
    client.complete(0, 'Existing show');
    await tester.pumpAndSettle();

    final refresh = key.currentState!.reload();
    client.fail(1);
    await refresh;
    await tester.pumpAndSettle();
    expect(find.text('Existing show'), findsOneWidget);
    expect(find.byTooltip(t.common.retry), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byTooltip(t.common.retry));
    await tester.pump();
    client.completeEmpty(2);
    await tester.pumpAndSettle();
    expect(find.text('Existing show'), findsNothing);
    expect(find.text(t.liveTv.noPrograms), findsOneWidget);
  });

  testWidgets('concurrent refresh requests coalesce into one trailing load', (tester) async {
    final client = _HubClient('a');
    final key = await _pumpTab(tester, [client]);
    final refresh = key.currentState!.reload();
    expect(identical(refresh, key.currentState!.reload()), isTrue);
    expect(client.requests, hasLength(1));
    client.completeEmpty(0);
    await tester.pump();
    expect(client.requests, hasLength(2));
    client.complete(1, 'Latest show');
    await refresh;
    await tester.pumpAndSettle();
    expect(client.requests, hasLength(2));
    expect(find.text('Latest show'), findsOneWidget);
  });

  testWidgets('hidden in-flight results are ignored and resume fetches fresh hubs', (tester) async {
    final client = _HubClient('a');
    final key = await _pumpTab(tester, [client]);
    key.currentState!.pauseRefresh();
    client.complete(0, 'Obsolete hidden show');
    await tester.pump();
    expect(find.text('Obsolete hidden show'), findsNothing);
    key.currentState!.resumeRefresh();
    await tester.pump();
    expect(client.requests, hasLength(2));
    client.complete(1, 'Visible show');
    await tester.pumpAndSettle();
    expect(find.text('Visible show'), findsOneWidget);
    expect(find.text('Obsolete hidden show'), findsNothing);
  });

  testWidgets('disposal ignores late hub errors and cancels refresh work', (tester) async {
    final client = _HubClient('a');
    await _pumpTab(tester, [client]);
    await tester.pumpWidget(const SizedBox.shrink());
    client.fail(0);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(client.requests, hasLength(1));
  });
}

Future<GlobalKey<WhatsOnTabState>> _pumpTab(WidgetTester tester, List<_HubClient> clients) async {
  final manager = MultiServerManager();
  for (final client in clients) {
    manager.debugRegisterClientForTesting(client);
  }
  final provider = testMultiServerProvider(manager)
    ..debugSetLiveTvServersForTesting([
      for (final client in clients) LiveTvServerInfo(serverId: client.serverId.value, dvrKey: 'dvr'),
    ]);
  addTearDown(() {
    provider.dispose();
    manager.dispose();
  });
  final key = GlobalKey<WhatsOnTabState>();
  await tester.pumpWidget(
    TranslationProvider(
      child: InputModeTracker(
        child: ChangeNotifierProvider<MultiServerProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: monoTheme(dark: true),
            home: Scaffold(
              body: WhatsOnTab(key: key, channels: const []),
            ),
          ),
        ),
      ),
    ),
  );
  return key;
}

final class _HubClient implements PlexClient {
  _HubClient(String id) : serverId = ServerId(id) {
    profileScopeId = buildPlexProfileScopeId(serverId: serverId, profileId: 'test-profile');
  }

  @override
  final ServerId serverId;
  @override
  late PlexProfileScopeId profileScopeId;
  @override
  final Object authenticationSessionId = Object();
  @override
  String get serverName => serverId.value;
  @override
  MediaBackend get backend => MediaBackend.plex;
  @override
  ServerCapabilities get capabilities => const ServerCapabilities(liveTv: true);
  final List<Completer<List<LiveTvHubResult>>> requests = [];

  @override
  Future<List<LiveTvHubResult>> getLiveTvHubs({int count = 12}) {
    final request = Completer<List<LiveTvHubResult>>();
    requests.add(request);
    return request.future;
  }

  void complete(int index, String title) => requests[index].complete([
    LiveTvHubResult(
      title: 'Live shows',
      hubKey: 'on-now',
      entries: [
        LiveTvHubEntry(
          metadata: testMediaItem(id: '${serverId.value}-$title', title: title),
          program: LiveTvProgram(title: title, serverId: serverId.value),
        ),
      ],
    ),
  ]);

  void completeEmpty(int index) => requests[index].complete(const []);
  void fail(int index) => requests[index].completeError(StateError('private-server/secret'));

  @override
  void close() {
    // The fake owns no transport resources.
  }

  @override
  Future<void> closeGracefully({Duration drainTimeout = const Duration(seconds: 2)}) async {
    close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
