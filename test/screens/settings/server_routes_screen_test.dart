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
