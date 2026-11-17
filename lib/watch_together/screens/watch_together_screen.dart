import 'dart:io';

import '../../media/ids.dart';

import 'package:flutter/material.dart';

import '../../widgets/app_dialog.dart';

import '../../utils/future_extensions.dart';

import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../i18n/strings.g.dart';
import '../../mixins/mounted_set_state_mixin.dart';
import '../../mixins/refreshable.dart';
import '../../focus/focusable_button.dart';
import '../../focus/focusable_text_field.dart';
import '../../focus/focusable_wrapper.dart';
import '../../profiles/active_profile_provider.dart';
import '../../providers/multi_server_provider.dart';
import '../../services/settings_service.dart';
import '../../services/base_peer_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/error_message_utils.dart';
import '../../utils/platform_detector.dart';
import '../../theme/mono_presentation.dart';
import '../../utils/dialogs.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/dialog_action_button.dart';
import '../../widgets/app_icon.dart';
import '../../utils/video_player_navigation.dart';
import '../../widgets/focused_scroll_scaffold.dart';
import '../../widgets/app_menu.dart';
import '../../widgets/overlay_sheet.dart';
import '../models/watch_session.dart';
import '../providers/watch_together_provider.dart';
import '../services/recent_rooms_service.dart';
import '../services/relay_protocol.g.dart';
import '../services/watch_together_relay_endpoint.dart';
import '../widgets/join_session_dialog.dart';
import '../widgets/create_session_dialog.dart';
import '../widgets/local_media_match_dialog.dart';
import '../../widgets/loading_indicator_box.dart';
import '../../widgets/press_feedback.dart';

/// The existing create/join flow embedded in a player's hosted drawer.
class WatchTogetherSetupPanel extends StatelessWidget {
  const WatchTogetherSetupPanel({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Consumer<WatchTogetherProvider>(
      builder: (context, provider, _) => _NotInSessionView(watchTogether: provider),
    ),
  );
}

class WatchTogetherScreen extends StatefulWidget {
  const WatchTogetherScreen({super.key, this.embedded = false, this.onBack});

  /// Embedded in the primary shell; never pop the enclosing profile route.
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<WatchTogetherScreen> createState() => _WatchTogetherScreenState();
}

class _WatchTogetherScreenState extends State<WatchTogetherScreen> with FocusableTab {
  final _contentScope = FocusScopeNode(debugLabel: 'WatchTogetherTab');

  @override
  void dispose() {
    _contentScope.dispose();
    super.dispose();
  }

  @override
  void focusActiveTabIfReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_contentScope.focusedChild != null) {
        _contentScope.requestFocus();
      } else {
        _contentScope.nextFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _contentScope,
      child: Consumer<WatchTogetherProvider>(
        builder: (context, watchTogether, child) {
          final canGoBack = watchTogether.isHost || !watchTogether.isInSession;
          // The host owns sheet + system back: a back with the actions sheet open
          // closes it; otherwise the route pops only when [canGoBack] (a guest in
          // an active session can't leave). canGoBack==true also preserves the iOS
          // interactive swipe-back.
          return OverlaySheetHost(
            canPop: widget.embedded || canGoBack,
            child: FocusedScrollScaffold(
              title: Text(t.watchTogether.title),
              contentTopPadding: 16,
              automaticallyImplyLeading: !widget.embedded && canGoBack,
              onBackPressed: widget.embedded ? widget.onBack ?? () {} : null,
              slivers: [
                if (watchTogether.isInSession)
                  ..._buildActiveSessionSlivers(watchTogether)
                else
                  SliverToBoxAdapter(child: _NotInSessionView(watchTogether: watchTogether)),
                if (widget.embedded && PlatformDetector.isMobile(context))
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildActiveSessionSlivers(WatchTogetherProvider watchTogether) {
    return [
      SliverPadding(
        padding: EdgeInsets.all(MonoPresentation.pageInset(context)),
        sliver: SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: _ActiveSessionContent(watchTogether: watchTogether),
            ),
          ),
        ),
      ),
    ];
  }
}

/// View shown when not in a session
class _NotInSessionView extends StatefulWidget {
  final WatchTogetherProvider watchTogether;

  const _NotInSessionView({required this.watchTogether});

  @override
  State<_NotInSessionView> createState() => _NotInSessionViewState();
}

class _NotInSessionViewState extends State<_NotInSessionView> with MountedSetStateMixin {
  bool _isCreating = false;
  bool _isJoining = false;
  String? _enteringRoomCode;
  bool? _healthOk;
  String? _profileId;
  late WatchTogetherRelayEndpoint _relayEndpoint;
  List<RecentRoom> _recentRooms = [];
  Listenable? _relayPreference;
  int _healthGeneration = 0;

  @override
  void initState() {
    super.initState();
    _profileId = context.read<ActiveProfileProvider>().activeId;
    _relayEndpoint = WatchTogetherRelayEndpoint.resolve(
      SettingsService.instanceOrNull?.read(SettingsService.customRelayUrl),
    );
    _recentRooms = _loadRecentRooms();
    _relayPreference = SettingsService.instanceOrNull?.listenableOf(SettingsService.customRelayUrl);
    _relayPreference?.addListener(_onRelayChanged);
    _checkHealth();
  }

  @override
  void dispose() {
    _relayPreference?.removeListener(_onRelayChanged);
    _healthGeneration++;
    super.dispose();
  }

  void _onRelayChanged() {
    if (!mounted) return;
    setState(() {
      _relayEndpoint = WatchTogetherRelayEndpoint.resolve(
        SettingsService.instanceOrNull?.read(SettingsService.customRelayUrl),
      );
      _healthOk = null;
      _recentRooms = _loadRecentRooms();
    });
    _checkHealth();
  }

  bool get _isBusy => _isCreating || _isJoining || _enteringRoomCode != null;

  String? get _plexDisplayName => context.read<ActiveProfileProvider>().active?.displayName;

  List<RecentRoom> _loadRecentRooms() {
    final profileId = _profileId;
    if (profileId == null || profileId.isEmpty) return const [];
    return RecentRoomsService.getRecentRooms(profileId: profileId, endpoint: _relayEndpoint);
  }

  Future<void> _checkHealth() async {
    final generation = ++_healthGeneration;
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(_relayEndpoint.healthUri);
      final response = await request.close().namedTimeout(
        const Duration(seconds: 5),
        operation: 'WatchTogether health check',
      );
      final body = await response.transform(const SystemEncoding().decoder).join();
      if (!mounted || generation != _healthGeneration) return;
      setState(() => _healthOk = response.statusCode == 200 && body.trim() == 'ok');
    } catch (e) {
      appLogger.w('Watch Together health check failed', error: e);
      if (!mounted || generation != _healthGeneration) return;
      setState(() => _healthOk = false);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final endedMessage = widget.watchTogether.sessionEndedMessage;
    final intro = _RoomSurface(
      highlighted: true,
      introductory: true,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppIcon(Symbols.group, size: 31, fill: 0, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Text(
            t.watchTogether.introLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              letterSpacing: 2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.watchTogether.introHeading,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: PlatformDetector.isTV() ? 30 : 25,
              letterSpacing: -0.7,
              fontWeight: FontWeight.w500,
              fontVariations: const [FontVariation('wght', 550)],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            t.watchTogether.introDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              height: 1.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Flexible(
                child: _RoomEntryButton(
                  autofocus: _recentRooms.isEmpty,
                  primary: true,
                  onPressed: _isBusy ? null : _createSession,
                  label: _isCreating ? t.watchTogether.creating : t.watchTogether.createSession,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _RoomEntryButton(
                  onPressed: _isBusy ? null : _joinSession,
                  label: _isJoining ? t.watchTogether.joining : t.watchTogether.joinByCode,
                ),
              ),
            ],
          ),
          if (_healthOk == false) ...[
            const SizedBox(height: 20),
            _RoomStatus(message: t.watchTogether.relayUnreachable, isError: true),
            FocusableButton(
              onPressed: _checkHealth,
              child: TextButton(onPressed: _checkHealth, child: Text(t.common.retry)),
            ),
          ],
          if (endedMessage != null) ...[const SizedBox(height: 16), _RoomStatus(message: endedMessage, isError: true)],
        ],
      ),
    );
    final recent = Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.watchTogether.recentRooms,
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              t.watchTogether.recentLabel,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentRooms.isEmpty)
          _RoomSurface(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(t.watchTogether.noRecentRooms, style: theme.textTheme.bodyMedium),
            ),
          ),
        ..._recentRooms.map(
          (room) => _RecentRoomTile(
            room: room,
            isBusy: _isBusy,
            isEntering: _enteringRoomCode == room.code,
            onTap: () => _enterRoom(room),
            onRename: () => _renameRoom(room),
            onRemove: () => _removeRoom(room),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t.watchTogether.inviteOnlyDescription,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.all(MonoPresentation.pageInset(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: _AdaptiveRoomColumns(leading: intro, trailing: recent),
        ),
      ),
    );
  }

  /// Runs [action] behind a busy flag, logging [logMessage] and showing
  /// [failureMessage] in a snackbar when it throws.
  Future<void> _runSessionAction({
    required void Function(bool busy) setBusy,
    required String logMessage,
    required String failureMessage,
    required Future<void> Function() action,
  }) async {
    setState(() => setBusy(true));
    try {
      await action();
    } catch (e) {
      appLogger.e(logMessage, error: e);
      if (mounted) {
        showErrorSnackBar(context, '$failureMessage: ${_sessionActionErrorDetail(e)}');
      }
    } finally {
      if (mounted) {
        setState(() => setBusy(false));
      }
    }
  }

  /// [PeerError.toString] is a debug dump (`PeerError(type): message`); its
  /// [PeerError.message] is already localized, so show that instead.
  String _sessionActionErrorDetail(Object error) => error is PeerError ? error.message : error.toString();

  Future<void> _createSession() async {
    final provider = widget.watchTogether;
    final profiles = context.read<ActiveProfileProvider>();
    final settings = SettingsService.instanceOrNull;
    await showScopedDialog<void>(
      context: context,
      builder: (_) => CreateSessionDialog(
        onSubmit: (dialogContext, name, controlMode) async {
          final profileId = profiles.activeId;
          final profileGeneration = profiles.identityMutationGeneration;
          final endpoint = WatchTogetherRelayEndpoint.resolve(settings?.read(SettingsService.customRelayUrl));
          final displayName = profiles.active?.displayName;
          final relayPreference = settings?.listenableOf(SettingsService.customRelayUrl);
          var relayChanged = false;
          void onRelayChanged() => relayChanged = true;
          relayPreference?.addListener(onRelayChanged);
          if (mounted) setState(() => _isCreating = true);
          try {
            final sessionId = await provider.createSession(
              controlMode: controlMode,
              relayEndpoint: endpoint,
              displayName: displayName,
            );
            final scopeIsCurrent =
                profiles.activeId == profileId &&
                profiles.identityMutationGeneration == profileGeneration &&
                !relayChanged &&
                WatchTogetherRelayEndpoint.resolve(settings?.read(SettingsService.customRelayUrl)) == endpoint &&
                provider.isConnected &&
                provider.sessionId == sessionId &&
                dialogContext.mounted &&
                (ModalRoute.of(dialogContext)?.isCurrent ?? false);
            if (!scopeIsCurrent) return (success: false, error: t.watchTogether.failedToCreate);
            if (profileId != null && profileId.isNotEmpty) {
              await provider.recordRecentRoom(profileId: profileId, endpoint: endpoint, name: name);
            }
            return (success: true, error: null);
          } catch (error) {
            appLogger.e('Failed to create session', error: error);
            if (dialogContext.mounted && (ModalRoute.of(dialogContext)?.isCurrent ?? false)) {
              showErrorSnackBar(
                dialogContext,
                '${t.watchTogether.failedToCreate}: ${_sessionActionErrorDetail(error)}',
              );
            }
            return (success: false, error: null);
          } finally {
            relayPreference?.removeListener(onRelayChanged);
            if (mounted) setState(() => _isCreating = false);
          }
        },
      ),
    );
  }

  Future<void> _joinSession() async {
    final provider = widget.watchTogether;
    final profiles = context.read<ActiveProfileProvider>();
    final settings = SettingsService.instanceOrNull;
    await showJoinSessionDialog(
      context,
      onSubmit: (dialogContext, sessionId) async {
        final profileId = profiles.activeId;
        final profileGeneration = profiles.identityMutationGeneration;
        final endpoint = WatchTogetherRelayEndpoint.resolve(settings?.read(SettingsService.customRelayUrl));
        final displayName = profiles.active?.displayName;
        final relayPreference = settings?.listenableOf(SettingsService.customRelayUrl);
        var relayChanged = false;
        void onRelayChanged() => relayChanged = true;
        relayPreference?.addListener(onRelayChanged);
        if (mounted) setState(() => _isJoining = true);
        try {
          await provider.joinSession(sessionId, relayEndpoint: endpoint, displayName: displayName);
          final scopeIsCurrent =
              profiles.activeId == profileId &&
              profiles.identityMutationGeneration == profileGeneration &&
              !relayChanged &&
              WatchTogetherRelayEndpoint.resolve(settings?.read(SettingsService.customRelayUrl)) == endpoint &&
              provider.isConnected &&
              provider.sessionId == sessionId &&
              dialogContext.mounted &&
              (ModalRoute.of(dialogContext)?.isCurrent ?? false);
          if (!scopeIsCurrent) return (success: false, error: t.watchTogether.failedToJoin);
          if (profileId != null && profileId.isNotEmpty) {
            await provider.recordRecentRoom(profileId: profileId, endpoint: endpoint);
          }
          return (success: true, error: null);
        } catch (error) {
          appLogger.e('Failed to join session', error: error);
          if (error is PeerError &&
              (error.type == PeerErrorType.invalidSession || error.serverCode == RelayProtocol.roomNotFoundCode)) {
            return (success: false, error: t.watchTogether.roomNotFound);
          }
          if (error is PeerError && error.serverCode == RelayProtocol.roomFullCode) {
            return (success: false, error: t.watchTogether.roomFull);
          }
          if (dialogContext.mounted && (ModalRoute.of(dialogContext)?.isCurrent ?? false)) {
            showErrorSnackBar(dialogContext, '${t.watchTogether.failedToJoin}: ${_sessionActionErrorDetail(error)}');
          }
          return (success: false, error: null);
        } finally {
          relayPreference?.removeListener(onRelayChanged);
          if (mounted) setState(() => _isJoining = false);
        }
      },
    );
  }

  Future<void> _enterRoom(RecentRoom room) async {
    await _runSessionAction(
      setBusy: (busy) => _enteringRoomCode = busy ? room.code : null,
      logMessage: 'Failed to enter room',
      failureMessage: t.watchTogether.failedToJoin,
      action: () async {
        final profiles = context.read<ActiveProfileProvider>();
        final profileId = profiles.activeId;
        final generation = profiles.identityMutationGeneration;
        final endpoint = _relayEndpoint;
        final relayPreference = SettingsService.instanceOrNull?.listenableOf(SettingsService.customRelayUrl);
        var relayChanged = false;
        void onRelayChanged() => relayChanged = true;
        relayPreference?.addListener(onRelayChanged);
        try {
          await widget.watchTogether.enterRoom(
            room.code,
            relayEndpoint: endpoint,
            controlMode: room.controlMode ?? ControlMode.anyone,
            displayName: _plexDisplayName,
          );
          if (profileId == null ||
              profileId.isEmpty ||
              relayChanged ||
              profiles.activeId != profileId ||
              profiles.identityMutationGeneration != generation ||
              WatchTogetherRelayEndpoint.resolve(
                    SettingsService.instanceOrNull?.read(SettingsService.customRelayUrl),
                  ) !=
                  endpoint ||
              !widget.watchTogether.isConnected ||
              widget.watchTogether.sessionId != room.code) {
            return;
          }
          await widget.watchTogether.recordRecentRoom(profileId: profileId, endpoint: endpoint);
        } finally {
          relayPreference?.removeListener(onRelayChanged);
        }
      },
    );
  }

  Future<void> _renameRoom(RecentRoom room) async {
    final name = await showScopedDialog<String>(
      context: context,
      builder: (_) => _RenameRoomDialog(room: room),
    );
    if (name == null || !mounted) return;

    final profileId = _profileId;
    if (profileId == null || profileId.isEmpty) return;
    await RecentRoomsService.renameRoom(
      room.code,
      name.isEmpty ? null : name,
      profileId: profileId,
      endpoint: _relayEndpoint,
    );
    setStateIfMounted(() => _recentRooms = _loadRecentRooms());
  }

  Future<void> _removeRoom(RecentRoom room) async {
    final profileId = _profileId;
    if (profileId == null || profileId.isEmpty) return;
    final endpoint = _relayEndpoint;
    final settings = SettingsService.instanceOrNull;
    bool canCommit() =>
        WatchTogetherRelayEndpoint.resolve(settings?.read(SettingsService.customRelayUrl)) == endpoint &&
        RecentRoomsService.getRecentRooms(
          profileId: profileId,
          endpoint: endpoint,
        ).any((entry) => entry.code == room.code);
    if (!await confirmUndoableAction(context, t.messages.pendingRemoval, canCommit: canCommit)) {
      return;
    }
    try {
      await RecentRoomsService.removeRoom(room.code, profileId: profileId, endpoint: endpoint);
      setStateIfMounted(() => _recentRooms = _loadRecentRooms());
    } catch (error) {
      final message = t.messages.errorLoading(error: localizedErrorReason(error));
      if (mounted) {
        showErrorSnackBar(context, message);
      } else {
        showGlobalErrorSnackBar(message);
      }
    }
  }
}

class _RenameRoomDialog extends StatefulWidget {
  final RecentRoom room;

  const _RenameRoomDialog({required this.room});

  @override
  State<_RenameRoomDialog> createState() => _RenameRoomDialogState();
}

class _RenameRoomDialogState extends State<_RenameRoomDialog> {
  late final _controller = TextEditingController(text: widget.room.name ?? '');
  final _fieldFocusNode = FocusNode(debugLabel: 'WatchTogetherRenameField');
  final _cancelFocusNode = FocusNode(debugLabel: 'WatchTogetherRenameCancel');
  final _saveFocusNode = FocusNode(debugLabel: 'WatchTogetherRenameSave');

  @override
  void dispose() {
    _fieldFocusNode.dispose();
    _cancelFocusNode.dispose();
    _saveFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Text(t.watchTogether.renameRoom),
      content: FocusableTextField(
        controller: _controller,
        focusNode: _fieldFocusNode,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.room.code),
        onNavigateDown: _saveFocusNode.requestFocus,
        onSubmitted: _submit,
      ),
      actions: [
        DialogActionButton(
          focusNode: _cancelFocusNode,
          onPressed: () => Navigator.pop(context),
          onNavigateRight: _saveFocusNode.requestFocus,
          label: t.common.cancel,
        ),
        DialogActionButton(
          focusNode: _saveFocusNode,
          onPressed: () => _submit(_controller.text),
          onNavigateLeft: _cancelFocusNode.requestFocus,
          isPrimary: true,
          label: t.common.save,
        ),
      ],
    );
  }
}

class _RecentRoomTile extends StatelessWidget {
  final RecentRoom room;
  final bool isBusy;
  final bool isEntering;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  const _RecentRoomTile({
    required this.room,
    required this.isBusy,
    required this.isEntering,
    required this.onTap,
    required this.onRename,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: FocusableWrapper(
        useBackgroundFocus: true,
        borderRadius: 16,
        // Hold SELECT/OK to open the rename/remove menu on TV/dpad (matches media cards).
        enableLongPress: true,
        // The wrapper owns key handling; the ListTile's InkWell and the trailing
        // more_vert IconButton must not steal focus from the long-press handler.
        descendantsAreFocusable: false,
        onSelect: isBusy ? null : onTap,
        onLongPress: () => _showActions(context),
        child: _RoomSurface(
          child: _RoomCardDetails(
            room: room,
            isEntering: isEntering,
            onEnter: isBusy ? null : onTap,
            onMenu: () => _showActions(context),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showAdaptiveAppMenu<String>(
      context,
      entries: [
        AppMenuItem(value: 'rename', icon: Symbols.edit_rounded, label: t.watchTogether.renameRoom),
        AppMenuItem(
          value: 'remove',
          icon: Symbols.delete_rounded,
          label: t.watchTogether.removeRoom,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted) return;
    if (action == 'rename') onRename();
    if (action == 'remove') onRemove();
  }
}

/// Uses only recorded values or the currently admitted room's live state.
class _RoomCardDetails extends StatelessWidget {
  const _RoomCardDetails({required this.room, this.live, this.onEnter, this.onMenu, this.isEntering = false});
  final RecentRoom room;
  final WatchTogetherProvider? live;
  final VoidCallback? onEnter;
  final VoidCallback? onMenu;
  final bool isEntering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = live?.isConnected == true && !live!.isReconnectingRelay && !live!.isWaitingForHostReconnect;
    final count = online ? live!.participantCount : room.lastMemberCount;
    final status = online
        ? (live!.isRoomPlaying ? t.watchTogether.roomPlaying : t.watchTogether.roomWaiting)
        : room.lastSeenAt == null
        ? null
        : t.watchTogether.roomHoursAgo(hours: DateTime.now().difference(room.lastSeenAt!).inHours.clamp(0, 1 << 31));
    final statusParts = [?status, if (count != null) t.watchTogether.roomMemberCount(count: count)];
    final title = online ? live!.currentMediaTitle ?? room.lastMediaTitle : room.lastMediaTitle;
    final episodeLabel = online && title != room.lastMediaTitle ? null : room.lastEpisodeLabel;
    final mediaParts = [if (title != null && title.trim().isNotEmpty) title, ?episodeLabel];
    final initials = online
        ? live!.participants
              .map((participant) => participant.displayName.trim())
              .where((name) => name.isNotEmpty)
              .take(3)
              .map((name) => String.fromCharCodes([name.runes.first]).toUpperCase())
              .toList()
        : room.lastMemberInitials?.take(3).toList() ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (statusParts.isNotEmpty) _RoomTag(label: statusParts.join(' · ')),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Text(
                room.name ?? room.code,
                maxLines: 1,
                overflow: .ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            if (isEntering) const LoadingIndicatorBox(size: 24),
            if (onMenu != null)
              IconButton(
                tooltip: t.videoControls.moreButton,
                icon: const AppIcon(Symbols.more_vert_rounded),
                onPressed: onMenu,
              ),
          ],
        ),
        if (mediaParts.isNotEmpty)
          Text(
            mediaParts.join(' · '),
            maxLines: 2,
            overflow: .ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        if (initials.isNotEmpty || onEnter != null || live == null) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              if (initials.isNotEmpty)
                SizedBox(
                  width: 27 + (initials.length - 1) * 21,
                  height: 27,
                  child: Stack(
                    children: [
                      for (var index = 0; index < initials.length; index++)
                        Positioned(
                          left: index * 21,
                          child: Container(
                            width: 27,
                            height: 27,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.alphaBlend(
                                theme.colorScheme.onSurface.withValues(alpha: .16 + index * .04),
                                theme.colorScheme.surface,
                              ),
                              border: Border.all(color: theme.colorScheme.surface, width: 2),
                            ),
                            child: Text(initials[index], style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
                          ),
                        ),
                    ],
                  ),
                ),
              const Spacer(),
              if (live == null) TextButton(onPressed: onEnter, child: Text(t.watchTogether.enterRoom)),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActiveSessionContent extends StatelessWidget {
  final WatchTogetherProvider watchTogether;

  const _ActiveSessionContent({required this.watchTogether});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = watchTogether.session!;
    final connectionMessage = watchTogether.isReconnectingRelay
        ? t.watchTogether.reconnectingRelay
        : watchTogether.isWaitingForHostReconnect
        ? t.watchTogether.reconnectingToHost
        : session.state == SessionState.connecting
        ? t.watchTogether.joining
        : session.errorMessage ?? t.watchTogether.connectedToRelay;

    final room = Column(
      crossAxisAlignment: .stretch,
      children: [
        _RoomSurface(
          highlighted: true,
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              if (watchTogether.recentRoom case final recentRoom?) ...[
                _RoomCardDetails(room: recentRoom, live: watchTogether),
                const SizedBox(height: 16),
              ],
              Text(
                watchTogether.isHost ? t.watchTogether.hostingSession : t.watchTogether.inSession,
                textAlign: TextAlign.start,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _SessionCodeHero(sessionId: session.sessionId),
              const SizedBox(height: 16),
              Text(
                session.controlMode == ControlMode.anyone
                    ? t.watchTogether.anyoneCanControl
                    : t.watchTogether.hostControlsPlayback,
                textAlign: TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (watchTogether.isConnected &&
            !watchTogether.isReconnectingRelay &&
            !watchTogether.isWaitingForHostReconnect) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _RoomTag(
              label: !watchTogether.hasCurrentPlayback
                  ? t.watchTogether.waitingForMedia
                  : watchTogether.isWaitingForPeers
                  ? t.watchTogether.waitingForParticipants
                  : t.watchTogether.mediaSelected,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _RoomStatus(message: connectionMessage, isError: session.state == SessionState.error),
        if (watchTogether.isWaitingForPeers) ...[
          const SizedBox(height: 8),
          _RoomStatus(message: t.watchTogether.waitingForParticipants),
        ],
        const SizedBox(height: 16),
        if (!watchTogether.hasCurrentPlayback)
          _RoomSurface(child: Text(t.watchTogether.noMediaSelected))
        else if (watchTogether.isHost)
          _RoomSurface(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(t.watchTogether.currentPlayback, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(watchTogether.currentMediaTitle ?? ''),
              ],
            ),
          )
        else
          _JoinCurrentPlaybackCard(watchTogether: watchTogether),
      ],
    );

    final members = Column(
      crossAxisAlignment: .stretch,
      children: [
        _RoomSurface(
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Text(
                '${t.watchTogether.participants} (${watchTogether.participantCount})',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...watchTogether.participants.map(
                (participant) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: AppIcon(
                          participant.isHost ? Symbols.star_rounded : Symbols.person_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          children: [
                            Text(
                              participant.displayName,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (participant.isHost) Text(t.watchTogether.host, style: theme.textTheme.labelSmall),
                          ],
                        ),
                      ),
                      if (watchTogether.isConnected &&
                          !watchTogether.isReconnectingRelay &&
                          !watchTogether.isWaitingForHostReconnect)
                        Flexible(
                          child: _RoomTag(
                            label: participant.isBuffering
                                ? t.watchTogether.bufferingStatus
                                : t.watchTogether.participantConnected,
                          ),
                        ),
                      if (watchTogether.canTransferHostTo(participant))
                        FocusableButton(
                          useBackgroundFocus: true,
                          onPressed: () => _confirmTransferHost(context, participant),
                          child: TextButton(
                            onPressed: () => _confirmTransferHost(context, participant),
                            child: Text(t.watchTogether.makeHost),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FocusableButton(
          autofocus: watchTogether.isHost || !watchTogether.hasCurrentPlayback,
          onPressed: () => _leaveSession(context),
          child: OutlinedButton.icon(
            onPressed: () => _leaveSession(context),
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            icon: AppIcon(watchTogether.isHost ? Symbols.close_rounded : Symbols.logout_rounded),
            label: Text(watchTogether.isHost ? t.watchTogether.endSession : t.watchTogether.leaveSession),
          ),
        ),
      ],
    );
    return _AdaptiveRoomColumns(leading: room, trailing: members);
  }

  Future<void> _leaveSession(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: watchTogether.isHost ? t.watchTogether.endSessionQuestion : t.watchTogether.leaveSessionQuestion,
      message: watchTogether.isHost ? t.watchTogether.endSessionConfirm : t.watchTogether.leaveSessionConfirm,
      confirmText: watchTogether.isHost ? t.watchTogether.end : t.watchTogether.leave,
      isDestructive: true,
    );

    if (!confirmed) return;
    try {
      await watchTogether.leaveSession();
    } catch (error, stackTrace) {
      appLogger.e('WatchTogether: Session leave failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _confirmTransferHost(BuildContext context, Participant participant) async {
    final confirmed = await showConfirmDialog(
      context,
      title: t.watchTogether.makeHostQuestion,
      message: t.watchTogether.makeHostConfirm(name: participant.displayName),
      confirmText: t.watchTogether.transfer,
    );
    if (!confirmed) return;
    watchTogether.transferHost(participant);
  }
}

class _JoinCurrentPlaybackCard extends StatefulWidget {
  final WatchTogetherProvider watchTogether;

  const _JoinCurrentPlaybackCard({required this.watchTogether});

  @override
  State<_JoinCurrentPlaybackCard> createState() => _JoinCurrentPlaybackCardState();
}

class _JoinCurrentPlaybackCardState extends State<_JoinCurrentPlaybackCard> {
  bool _isJoining = false;
  bool _isResolving = true;
  bool _mediaAvailable = false;
  String? _mediaIdentity;
  int _resolutionGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveIfChanged();
  }

  @override
  void didUpdateWidget(covariant _JoinCurrentPlaybackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveIfChanged();
  }

  void _resolveIfChanged() {
    final identity =
        '${widget.watchTogether.sessionId}/${widget.watchTogether.currentMediaServerId}/'
        '${widget.watchTogether.currentMediaRatingKey}/${widget.watchTogether.localMediaMatchVersion}';
    if (identity == _mediaIdentity) return;
    _mediaIdentity = identity;
    _resolveMedia();
  }

  Future<void> _resolveMedia() async {
    final generation = ++_resolutionGeneration;
    final ratingKey = widget.watchTogether.currentMediaRatingKey;
    final serverId = widget.watchTogether.currentMediaServerId;
    // An alternative source requires an explicit confirmed room-local match.
    final servers = context.read<MultiServerProvider?>();
    final target = serverId == null || ratingKey == null
        ? null
        : widget.watchTogether.resolveLocalPlayback(ratingKey: ratingKey, serverId: ServerId(serverId));
    final client = target == null ? null : servers?.getClientForServer(target.serverId);
    setState(() {
      _isResolving = true;
      _mediaAvailable = false;
    });
    var available = false;
    try {
      if (client != null && target != null) {
        final metadata = await client.fetchItem(target.ratingKey);
        if (metadata != null) {
          widget.watchTogether.resolveLocalVersion(metadata.copyWith(serverId: target.serverId));
          available = true;
        }
      }
    } catch (error, stackTrace) {
      appLogger.w('WatchTogether: Media resolution failed', error: error, stackTrace: stackTrace);
    }
    if (!mounted || generation != _resolutionGeneration) return;
    setState(() {
      _isResolving = false;
      _mediaAvailable = available;
    });
  }

  Future<void> _changeMatch() async {
    final together = widget.watchTogether;
    final lease = together.capturePlaybackLease();
    if (lease == null) return;
    final selection = await showScopedDialog<LocalMediaSelection>(
      context: context,
      builder: (_) => LocalMediaMatchDialog(hostTitle: together.currentMediaTitle ?? ''),
    );
    if (!mounted || selection == null || !together.isPlaybackLeaseCurrent(lease)) return;
    if (together.setLocalMediaMatch(selection.item, lease: lease, version: selection.version)) _resolveIfChanged();
  }

  Future<void> _joinCurrentPlayback() async {
    final ratingKey = widget.watchTogether.currentMediaRatingKey;
    final serverId = widget.watchTogether.currentMediaServerId;
    if (ratingKey == null || serverId == null) return;

    setState(() => _isJoining = true);

    try {
      final opened = await navigateToWatchTogetherPlayback(
        context,
        ratingKey: ratingKey,
        serverId: ServerId(serverId),
        onBeforeNavigate: () {
          widget.watchTogether.markCurrentPlaybackHandled(ratingKey: ratingKey, serverId: ServerId(serverId));
        },
      );
      if (!opened && mounted) _resolveIfChanged();
    } catch (e, stackTrace) {
      appLogger.e('WatchTogether: Failed to open current playback', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _mediaAvailable = false);
        showErrorSnackBar(context, t.watchTogether.failedToOpenCurrentPlayback);
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaTitle = widget.watchTogether.currentMediaTitle;
    if (widget.watchTogether.isHost || mediaTitle == null) {
      return const SizedBox.shrink();
    }

    final canJoin = !_isJoining && !_isResolving && _mediaAvailable && !widget.watchTogether.isReconnectingRelay;
    return _RoomSurface(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              AppIcon(Symbols.play_circle_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(t.watchTogether.currentPlayback, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      _isResolving
                          ? t.watchTogether.resolvingMedia
                          : _mediaAvailable
                          ? t.watchTogether.joinCurrentPlaybackDescription
                          : t.watchTogether.mediaUnavailable,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(mediaTitle, style: theme.textTheme.bodyLarge),
          if (!_isResolving) ...[
            const SizedBox(height: 8),
            _RoomTag(label: _mediaAvailable ? t.watchTogether.localMediaAvailable : t.watchTogether.mediaNotMatched),
          ],
          if (widget.watchTogether.localMediaMatch case final match?) ...[
            const SizedBox(height: 8),
            Text('${t.watchTogether.localMatch}: ${match.displayTitle}', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FocusableButton(
              autofocus: true,
              onPressed: _isResolving || _isJoining
                  ? null
                  : canJoin
                  ? _joinCurrentPlayback
                  : _resolveMedia,
              useBackgroundFocus: true,
              child: FilledButton.icon(
                onPressed: _isResolving || _isJoining
                    ? null
                    : canJoin
                    ? _joinCurrentPlayback
                    : _resolveMedia,
                icon: _isJoining || _isResolving
                    ? const LoadingIndicatorBox()
                    : AppIcon(canJoin ? Symbols.play_arrow_rounded : Symbols.refresh_rounded),
                label: Text(
                  _isResolving
                      ? t.watchTogether.resolvingMedia
                      : _isJoining
                      ? t.watchTogether.joining
                      : canJoin
                      ? t.watchTogether.joinCurrentPlayback
                      : t.watchTogether.retryMedia,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FocusableButton(
            onPressed: _isJoining ? null : _changeMatch,
            child: TextButton(onPressed: _isJoining ? null : _changeMatch, child: Text(t.watchTogether.changeMatch)),
          ),
        ],
      ),
    );
  }
}

class _RoomEntryButton extends StatelessWidget {
  const _RoomEntryButton({required this.label, this.onPressed, this.autofocus = false, this.primary = false});

  final String label;
  final VoidCallback? onPressed;
  final bool autofocus;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FocusableButton(
      autofocus: autofocus,
      onPressed: onPressed,
      dimWhenUnfocused: false,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: primary ? const Color(0xfff4f5f6) : colors.onSurface.withValues(alpha: 0.086),
          foregroundColor: primary ? const Color(0xff202126) : colors.onSurface,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
          side: primary ? BorderSide.none : BorderSide(color: colors.onSurface.withValues(alpha: 0.035)),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12, height: 1.2),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _AdaptiveRoomColumns extends StatelessWidget {
  const _AdaptiveRoomColumns({required this.leading, required this.trailing});

  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Large text keeps the single-column reading order, even on a TV.
        final wide = constraints.maxWidth >= 760 && MediaQuery.textScalerOf(context).scale(16) <= 24;
        if (!wide) {
          return Column(crossAxisAlignment: .stretch, children: [leading, const SizedBox(height: 16), trailing]);
        }
        return Row(
          crossAxisAlignment: .start,
          children: [
            Expanded(child: leading),
            const SizedBox(width: 24),
            Expanded(child: trailing),
          ],
        );
      },
    );
  }
}

class _RoomSurface extends StatelessWidget {
  const _RoomSurface({required this.child, this.highlighted = false, this.introductory = false});
  final Widget child;
  final bool highlighted;
  final bool introductory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(introductory ? 20 : 16),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.22)),
      ),
      color: Color.alphaBlend(colors.onSurface.withValues(alpha: highlighted ? 0.045 : 0.025), colors.surface),
      child: Padding(
        padding: introductory ? const EdgeInsets.symmetric(horizontal: 20, vertical: 23) : const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _RoomTag extends StatelessWidget {
  const _RoomTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _RoomStatus extends StatelessWidget {
  const _RoomStatus({required this.message, this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: .start,
        children: [
          AppIcon(
            isError ? Symbols.warning_rounded : Symbols.wifi_rounded,
            size: 18,
            color: isError ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Copyable invitation identity, sized as room content rather than a billboard.
/// Custom IDs wrap naturally while semantics and the clipboard retain all text.
class _SessionCodeHero extends StatelessWidget {
  final String sessionId;

  const _SessionCodeHero({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    // A boundary of its own: otherwise the card's container node absorbs this
    // button together with the sibling title/control-mode text, and assistive
    // tech announces the whole card as one "copy" button.
    return Semantics(
      container: true,
      child: FocusableWrapper(
        useBackgroundFocus: true,
        disableScale: true,
        borderRadius: 12,
        semanticLabel: t.watchTogether.copySessionCode,
        semanticValue: sessionId,
        descendantsAreFocusable: false,
        onSelect: () => _copySessionCode(context),
        child: PressFeedbackInkWell(
          canRequestFocus: false,
          onTap: () => _copySessionCode(context),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: .min,
                  children: [
                    Text(t.watchTogether.sessionCode, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                    const SizedBox(width: 6),
                    AppIcon(Symbols.content_copy_rounded, size: 18, color: muted),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  sessionId,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 28,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copySessionCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: sessionId));
    showSnackBar(context, t.watchTogether.sessionCodeCopied);
  }
}
