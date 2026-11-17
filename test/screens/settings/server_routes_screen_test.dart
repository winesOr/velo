import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/connection/connection.dart';
import 'package:plezy/connection/server_routes.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/profiles/active_profile_provider.dart';
import 'package:plezy/profiles/profile.dart';
import 'package:plezy/profiles/profile_connection.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/screens/settings/server_routes_screen.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/services/plex_auth_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/app_icon.dart';
import 'package:plezy/widgets/focusable_list_tile.dart';
import 'package:plezy/widgets/setting_tile.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/multi_server_fixtures.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets('R2-16 a removed Plex server replaces its open routes page with an empty state', (tester) async {
    final profile = await _openServer(tester, _connection());
    expect(find.text(t.routes.empty), findsOneWidget);

    profile.replace(_connection().copyWith(servers: []));
    await tester.pumpAndSettle();

    expect(find.text(t.routes.noServers), findsOneWidget);
    expect(find.text(t.routes.empty), findsNothing);
    expect(find.widgetWithText(SettingNavigationTile, t.routes.add), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R2-18 manual selection checks only the currently selected route', (tester) async {
    final profile = await _openServer(tester, _connection(selectedUrl: _routeTwo.url));
    void expectSelected(String selected, String other) {
      final chosen = find.widgetWithText(FocusableListTile, selected);
      final unchosen = find.widgetWithText(FocusableListTile, other);
      expect(tester.widget<FocusableListTile>(chosen).selected, isTrue);
      expect(tester.widget<FocusableListTile>(unchosen).selected, isFalse);
      expect(find.descendant(of: chosen, matching: _checkIcon), findsOneWidget);
      expect(find.descendant(of: unchosen, matching: _checkIcon), findsNothing);
    }

    expectSelected(_routeTwo.name, _routeOne.name);
    profile.replace(_connection(selectedUrl: _routeOne.url));
    await tester.pumpAndSettle();
    expectSelected(_routeOne.name, _routeTwo.name);
    expect(tester.takeException(), isNull);
  });

  for (final response in [
    (status: 401, body: '<MediaContainer machineIdentifier="server"/>', error: () => t.routes.authenticationFailed),
    (status: 403, body: '<MediaContainer machineIdentifier="server"/>', error: () => t.routes.authenticationFailed),
    (status: 500, body: '<MediaContainer machineIdentifier="server"/>', error: () => t.routes.unreachable),
    (status: 200, body: '<MediaContainer machineIdentifier="other"/>', error: () => t.routes.identityMismatch),
    (status: 200, body: 'invalid XML', error: () => t.routes.unreachable),
  ]) {
    testWidgets(
      'R2-17/19 real identity ${response.status} ${response.body} disables Add and reports the precise failure',
      (tester) async {
        final previousOverrides = HttpOverrides.current;
        HttpOverrides.global = null;
        addTearDown(() => HttpOverrides.global = previousOverrides);
        final received = Completer<HttpRequest>();
        final server = (await tester.runAsync(() async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          server.listen(received.complete);
          return server;
        }))!;
        addTearDown(() => server.close(force: true));
        await _openServer(tester, _connection());

        final add = find.widgetWithText(SettingNavigationTile, t.routes.add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(3));
        await tester.enterText(fields.at(0), 'Verified candidate');
        await tester.enterText(fields.at(1), 'http://127.0.0.1');
        await tester.enterText(fields.at(2), '${server.port}');
        await tester.tap(find.widgetWithText(FilledButton, t.common.save));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(TextFormField), findsNothing, reason: 'the valid form must close before probing');
        await _pumpNetworkUntil(
          tester,
          () => received.isCompleted,
          reason: 'the anonymous identity request must reach loopback',
        );
        final request = await received.future;
        expect(request.uri.path, '/identity');
        expect(request.headers.value('X-Plex-Token'), isNull);
        final busyAdd = tester.widget<SettingNavigationTile>(add);
        expect(busyAdd.enabled, isFalse);
        expect(busyAdd.onTap, isNull);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        await tester.tap(add, warnIfMissed: false);
        await tester.pump();
        expect(find.byType(TextFormField), findsNothing, reason: 'busy Add cannot reopen the form');

        await tester.runAsync(() async {
          request.response.statusCode = response.status;
          request.response.headers.contentType = ContentType('application', 'xml');
          request.response.write(response.body);
          await request.response.close();
        });
        await _pumpNetworkUntil(
          tester,
          () => find.text(response.error()).evaluate().isNotEmpty,
          reason: 'the exact HTTP or identity failure must be displayed',
        );
        expect(find.text(response.error()), findsOneWidget);
        expect(find.text(t.routes.saveFailed), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.widget<SettingNavigationTile>(add).enabled, isTrue);
        expect(tester.widget<SettingNavigationTile>(add).onTap, isNotNull);
        expect(find.text('Verified candidate'), findsNothing, reason: 'a failed probe cannot persist the route');
        expect(tester.takeException(), isNull);
      },
    );
  }
}

/// Network completions run on the real event loop, but the continuation that
/// resumes after closing the form is registered in the widget's FakeAsync zone.
/// Both queues must advance; waiting only in runAsync deadlocks that handoff.
Future<void> _pumpNetworkUntil(WidgetTester tester, bool Function() ready, {required String reason}) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(ready(), isTrue, reason: reason);
}

final _checkIcon = find.byWidgetPredicate((widget) => widget is AppIcon && widget.icon == Symbols.check_rounded);
const _routeOne = ServerRoute(name: 'Home', url: 'http://home.test:32400');
const _routeTwo = ServerRoute(name: 'Away', url: 'https://away.test:443');

PlexAccountConnection _connection({String? selectedUrl}) => PlexAccountConnection(
  id: 'account',
  accountToken: 'fixture-account-token',
  clientIdentifier: 'fixture-client',
  accountLabel: 'Fixture account',
  servers: [
    PlexServer(
      name: 'Fixture server',
      clientIdentifier: 'server',
      accessToken: 'fixture-server-token',
      connections: [],
      owned: true,
    ),
  ],
  serverRoutes: selectedUrl == null
      ? {}
      : {
          'server': ServerRouteSettings(routes: [_routeOne, _routeTwo], selectedUrl: selectedUrl),
        },
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);

Future<_Profile> _openServer(WidgetTester tester, PlexAccountConnection connection) async {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final profile = _Profile(connection);
  final manager = _AuthorizedManager();
  final servers = testMultiServerProvider(manager);
  addTearDown(() {
    profile.dispose();
    servers.dispose();
    manager.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveProfileProvider>.value(value: profile),
        ChangeNotifierProvider<MultiServerProvider>.value(value: servers),
      ],
      child: MaterialApp(
        theme: monoTheme(dark: true),
        home: const InputModeTracker(child: ServerRoutesScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Fixture server · Fixture account'));
  await tester.pumpAndSettle();
  return profile;
}

class _AuthorizedManager extends MultiServerManager {
  @override
  bool hasPlexServerAuthorization(ServerId serverId, {required String accountId, required String profileId}) =>
      serverId == ServerId('server') && accountId == 'account' && profileId == 'profile';
}

class _Profile extends ChangeNotifier implements ActiveProfileProvider {
  _Profile(this.connection);
  PlexAccountConnection connection;

  void replace(PlexAccountConnection value) {
    connection = value;
    notifyListeners();
  }

  @override
  Profile get active =>
      Profile.local(id: 'profile', displayName: 'Fixture', createdAt: DateTime.fromMillisecondsSinceEpoch(0));
  @override
  String get activeId => active.id;
  @override
  int get identityMutationGeneration => 0;
  @override
  Map<String, Connection> get connectionsById => {'account': connection};
  @override
  Map<String, List<ProfileConnection>> get connectionsByProfile => {
    'profile': [const ProfileConnection(profileId: 'profile', connectionId: 'account', userIdentifier: 'fixture-user')],
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
