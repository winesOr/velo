import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../exceptions/media_server_exceptions.dart';

import '../../connection/connection.dart';
import '../../connection/connection_registry.dart';
import '../../connection/server_routes.dart';
import '../../connection/server_route_identity.dart';
import '../../database/app_database.dart';
import '../../media/ids.dart';
import '../../focus/focusable_button.dart';
import '../../focus/focusable_text_field.dart';
import '../../i18n/strings.g.dart';
import '../../profiles/active_profile_binder.dart';
import '../../profiles/active_profile_provider.dart';
import '../../profiles/profile_connection_registry.dart';
import '../../providers/multi_server_provider.dart';
import '../../services/jellyfin_endpoint_discovery.dart';
import '../../utils/dialogs.dart';
import '../../utils/media_server_http_client.dart';
import '../../utils/media_server_timeouts.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/press_feedback.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/focusable_list_tile.dart';
import '../../widgets/setting_tile.dart';
import '../../widgets/settings_page.dart';
import '../../widgets/settings_section.dart';
import 'async_form_state_mixin.dart';

/// Lists only connections attached to the current app profile. Plex servers
/// additionally require an authorization snapshot for that account/profile,
/// including servers whose selected route is currently offline.
class ServerRoutesScreen extends StatelessWidget {
  const ServerRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ActiveProfileProvider>();
    final active = profile.active;
    final authorized = {
      for (final row in profile.connectionsByProfile[active?.id] ?? []) row.connectionId,
      if (active?.parentConnectionId != null) active!.parentConnectionId!,
    };
    final servers = context.watch<MultiServerProvider>();
    final children = <Widget>[];
    for (final connection in profile.connectionsById.values.where((c) => authorized.contains(c.id))) {
      switch (connection) {
        case final JellyfinConnection c:
          children.add(_entry(context, c, c.serverMachineId, '${c.serverName} · ${c.userName}'));
        case final PlexAccountConnection c:
          for (final server in c.servers) {
            if (active == null ||
                !servers.serverManager.hasPlexServerAuthorization(
                  ServerId(server.clientIdentifier),
                  accountId: c.id,
                  profileId: active.id,
                )) {
              continue;
            }
            children.add(_entry(context, c, server.clientIdentifier, '${server.name} · ${c.accountLabel}'));
          }
      }
    }
    return SettingsPage(
      title: Text(t.routes.title),
      children: [
        SettingsGroup(children: children.isEmpty ? [PressFeedbackListTile(title: Text(t.routes.noServers))] : children),
      ],
    );
  }

  Widget _entry(BuildContext context, Connection connection, String serverId, String label) => SettingNavigationTile(
    icon: Symbols.route_rounded,
    title: label,
    subtitle: switch (connection) {
      PlexAccountConnection() => 'Plex',
      JellyfinConnection c => c.dialect.productName,
    },
    destinationBuilder: (_) => _ServerRouteList(connectionId: connection.id, serverId: serverId, title: label),
  );
}

class _ServerRouteList extends StatefulWidget {
  final String connectionId;
  final String serverId;
  final String title;
  const _ServerRouteList({required this.connectionId, required this.serverId, required this.title});

  @override
  State<_ServerRouteList> createState() => _ServerRouteListState();
}

class _ServerRouteListState extends State<_ServerRouteList> with AsyncFormStateMixin {
  late final String? _profileId = context.read<ActiveProfileProvider>().activeId;
  late final int _generation = context.read<ActiveProfileProvider>().identityMutationGeneration;

  void _checkScope() {
    if (!mounted) throw StateError('The route was closed.');
    final active = context.read<ActiveProfileProvider>();
    if (active.activeId != _profileId || active.identityMutationGeneration != _generation) {
      throw StateError('The active profile changed.');
    }
  }

  List<ServerRoute> _routes(Connection connection) {
    final settings = connection.serverRoutes[widget.serverId];
    if (settings != null) return settings.routes;
    final urls = switch (connection) {
      JellyfinConnection c => c.baseUrls,
      PlexAccountConnection c =>
        c.servers
                .where((s) => s.clientIdentifier == widget.serverId)
                .firstOrNull
                ?.connections
                .map((c) => c.uri)
                .toSet()
                .toList() ??
            const <String>[],
    };
    return [for (final url in urls) ServerRoute(name: url, url: url)];
  }

  Future<void> _write(Connection expected, ServerRouteSettings settings) => _prepareWrite(expected).write(settings);

  ({bool Function() canCommit, Future<void> Function(ServerRouteSettings) write}) _prepareWrite(Connection expected) {
    _checkScope();
    final db = context.read<AppDatabase>();
    final registry = context.read<ConnectionRegistry>();
    final ownership = context.read<ProfileConnectionRegistry>();
    final active = context.read<ActiveProfileProvider>();
    final binder = context.read<ActiveProfileBinder>();
    final provider = context.read<MultiServerProvider>();
    final serverId = widget.serverId;
    final profileId = _profileId;
    final generation = _generation;
    bool canCommit() =>
        active.activeId == profileId &&
        active.identityMutationGeneration == generation &&
        active.connectionsById[expected.id] == expected &&
        (expected is! PlexAccountConnection ||
            profileId != null &&
                provider.serverManager.hasPlexServerAuthorization(
                  ServerId(serverId),
                  accountId: expected.id,
                  profileId: profileId,
                ));
    void checkCurrent() {
      if (!canCommit()) throw StateError('The connection scope changed.');
    }

    Future<void> write(ServerRouteSettings settings) async {
      checkCurrent();
      await db.runIdentityMutation(() async {
        checkCurrent();
        final row = _profileId == null ? null : await ownership.get(_profileId, expected.id);
        checkCurrent();
        if (row == null && active.active?.parentConnectionId != expected.id) {
          throw StateError('Connection access changed.');
        }
        if (expected is PlexAccountConnection) {
          if (_profileId == null ||
              !provider.serverManager.hasPlexServerAuthorization(
                ServerId(serverId),
                accountId: expected.id,
                profileId: _profileId,
              )) {
            throw StateError('Server authorization changed.');
          }
        }
        final routes = {...expected.serverRoutes, serverId: settings};
        final updated = switch (expected) {
          JellyfinConnection c => c.copyWith(serverRoutes: routes),
          PlexAccountConnection c => c.copyWith(serverRoutes: routes),
        };
        await registry.upsert(updated, expected: expected, checkCurrent: checkCurrent, updateServerRoutes: true);
      });
      if (mounted) setState(() {});
      await binder.rebindActive();
    }

    return (canCommit: canCommit, write: write);
  }

  Future<void> _perform(Future<void> Function() body) => runAsync<void>(
    body,
    errorMapper: (error) => switch (error) {
      ServerRouteIdentityMismatch() => t.routes.identityMismatch,
      MediaServerAuthException() => t.routes.authenticationFailed,
      MediaServerHttpException(statusCode: 401 || 403) => t.routes.authenticationFailed,
      MediaServerHttpException() || MediaServerUrlException() => t.routes.unreachable,
      _ => t.routes.saveFailed,
    },
  );

  Future<void> _add(Connection connection) async {
    final route = await showScopedDialog<ServerRoute>(context: context, builder: (_) => const _RouteForm());
    if (route == null || !mounted) return;
    await _perform(() async {
      _checkScope();
      // Anonymous identity verification prevents forwarding an existing token
      // to an unrelated server; this is deliberately not a speed measurement.
      if (connection case final JellyfinConnection c) {
        final info = await JellyfinEndpointDiscovery(dialect: c.dialect).probe(route.url);
        if (c.serverMachineId.isEmpty ||
            info.machineId != c.serverMachineId ||
            (info.dialect != null && info.dialect != c.dialect)) {
          throw const ServerRouteIdentityMismatch();
        }
      } else {
        final http = MediaServerHttpClient(baseUrl: route.url);
        try {
          final response = await http.get('/identity', timeout: MediaServerTimeouts.plexProbe);
          validatePlexRouteIdentity(response, widget.serverId);
        } finally {
          http.close();
        }
      }
      _checkScope();
      final routes = _routes(connection);
      if (routes.any((r) => Uri.parse(r.url) == Uri.parse(route.url))) {
        setErrorText(t.routes.duplicate);
        return;
      }
      await _write(
        connection,
        ServerRouteSettings(
          routes: [...routes, route],
          selectedUrl: connection.serverRoutes[widget.serverId]?.selectedUrl,
          usePrimary: connection.serverRoutes[widget.serverId]?.usePrimary ?? false,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ActiveProfileProvider>().connectionsById[widget.connectionId];
    if (connection == null ||
        connection is PlexAccountConnection &&
            !connection.servers.any((server) => server.clientIdentifier == widget.serverId)) {
      return SettingsPage(
        title: Text(widget.title),
        children: [PressFeedbackListTile(title: Text(t.routes.noServers))],
      );
    }
    final routes = _routes(connection);
    final selected = connection.serverRoutes[widget.serverId]?.selectedUrl;
    final usePrimary = connection.serverRoutes[widget.serverId]?.usePrimary ?? false;
    return SettingsPage(
      title: Text(widget.title),
      children: [
        SettingsGroup(
          title: t.routes.strategy,
          children: [
            FocusableListTile(
              title: Text(t.routes.unset),
              trailing: selected == null && !usePrimary ? const AppIcon(Symbols.check_rounded) : null,
              onTap: busy ? null : () => _perform(() => _write(connection, ServerRouteSettings(routes: routes))),
            ),
            FocusableListTile(
              title: Text(t.routes.primary),
              subtitle: Text(t.routes.primaryDescription),
              trailing: selected == null && usePrimary ? const AppIcon(Symbols.check_rounded) : null,
              onTap: busy || routes.isEmpty
                  ? null
                  : () => _perform(() => _write(connection, ServerRouteSettings(routes: routes, usePrimary: true))),
            ),
            PressFeedbackListTile(title: Text(t.routes.manual), subtitle: Text(t.routes.manualDescription)),
            PressFeedbackListTile(
              enabled: false,
              title: Text(t.routes.automatic),
              subtitle: Text(t.routes.automaticDescription),
            ),
          ],
        ),
        SettingsSectionHeader(t.routes.title),
        if (routes.isEmpty)
          SettingsGroup(
            children: [PressFeedbackListTile(title: Text(t.routes.empty), subtitle: Text(t.routes.emptyDescription))],
          ),
        for (final route in routes) ...[
          SettingsGroup(
            children: [
              FocusableListTile(
                title: Text(route.name),
                selected: selected == route.url,
                subtitle: Text(route.url),
                trailing: selected == route.url ? const AppIcon(Symbols.check_rounded) : null,
                onTap: busy
                    ? null
                    : () => _perform(
                        () => _write(connection, ServerRouteSettings(routes: routes, selectedUrl: route.url)),
                      ),
              ),
              FocusableListTile(
                leading: const AppIcon(Symbols.delete_rounded),
                title: Text(t.common.delete),
                onTap: busy
                    ? null
                    : () async {
                        final operation = _prepareWrite(connection);
                        await _perform(() async {
                          if (!await confirmUndoableAction(
                            this.context,
                            t.messages.pendingRemoval,
                            canCommit: operation.canCommit,
                          )) {
                            return;
                          }
                          final remaining = routes.where((r) => r.url != route.url).toList();
                          try {
                            await operation.write(
                              ServerRouteSettings(
                                routes: remaining,
                                selectedUrl: selected == route.url ? null : selected,
                                usePrimary: remaining.isNotEmpty && usePrimary,
                              ),
                            );
                          } catch (_) {
                            if (!mounted) showGlobalErrorSnackBar(t.routes.saveFailed);
                            rethrow;
                          }
                        });
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        SettingsGroup(
          children: [
            SettingNavigationTile(
              icon: Symbols.add_rounded,
              title: t.routes.add,
              enabled: !busy,
              onTap: busy ? null : () => _add(connection),
            ),
          ],
        ),
        if (busy) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: buildInlineError(Theme.of(context))),
        ),
      ],
    );
  }
}

class _RouteForm extends StatefulWidget {
  const _RouteForm();
  @override
  State<_RouteForm> createState() => _RouteFormState();
}

class _RouteFormState extends State<_RouteForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _port = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppAlertDialog(
    title: Text(t.routes.add),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FocusableTextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 40,
                decoration: InputDecoration(labelText: t.routes.name),
                validator: (value) => ServerRoute.validName(value ?? '') ? null : t.routes.nameError,
              ),
              const SizedBox(height: 12),
              FocusableTextFormField(
                controller: _address,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: t.routes.address),
                validator: (value) => ServerRoute.validAddress(value ?? '') ? null : t.routes.addressError,
              ),
              const SizedBox(height: 12),
              FocusableTextFormField(
                controller: _port,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t.routes.port),
                validator: (value) => ServerRoute.validPort((value ?? '').trim()) ? null : t.routes.portError,
              ),
              const SizedBox(height: 12),
              Text(t.routes.identityNotice),
            ],
          ),
        ),
      ),
    ),
    actions: [
      FocusableButton(
        onPressed: () => Navigator.pop(context),
        child: TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel)),
      ),
      FocusableButton(
        onPressed: _save,
        child: FilledButton(onPressed: _save, child: Text(t.common.save)),
      ),
    ],
  );

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(context, ServerRoute.fromInput(name: _name.text, address: _address.text, port: _port.text));
  }
}
