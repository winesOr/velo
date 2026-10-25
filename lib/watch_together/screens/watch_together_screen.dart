import 'dart:io';

import '../../media/ids.dart';

import 'package:flutter/material.dart';

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
import '../services/watch_together_relay_endpoint.dart';
import '../widgets/join_session_dialog.dart';
import '../widgets/local_media_match_dialog.dart';
import '../../widgets/loading_indicator_box.dart';

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
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppIcon(Symbols.groups_rounded, size: 28, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            t.watchTogether.introHeading,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 25,
              fontWeight: FontWeight.w500,
              fontVariations: const [FontVariation('wght', 550)],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t.watchTogether.description,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FocusableButton(
            autofocus: _recentRooms.isEmpty,
            onPressed: _isBusy ? null : _createSession,
            useBackgroundFocus: true,
            child: FilledButton.icon(
              onPressed: _isBusy ? null : _createSession,
              icon: _isCreating ? const LoadingIndicatorBox(size: 20) : const AppIcon(Symbols.add_rounded),
              label: Text(_isCreating ? t.watchTogether.creating : t.watchTogether.createSession),
            ),
          ),
          const SizedBox(height: 12),
          FocusableButton(
            onPressed: _isBusy ? null : _joinSession,
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : _joinSession,
              icon: _isJoining ? const LoadingIndicatorBox(size: 20) : const AppIcon(Symbols.group_add_rounded),
              label: Text(_isJoining ? t.watchTogether.joining : t.watchTogether.joinSession),
            ),
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
        Text(t.watchTogether.recentRooms, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          t.watchTogether.recentRoomsDescription,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
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

  /// Persists [code] as a recent room for the active profile and refreshes the
  /// list. A null [controlMode] leaves any stored mode untouched.
  Future<void> _recordRecentRoom(String code, {ControlMode? controlMode}) async {
    final profileId = _profileId;
    if (profileId == null || profileId.isEmpty) return;
    await RecentRoomsService.addOrUpdateRoom(
      code,
      profileId: profileId,
      endpoint: _relayEndpoint,
      controlMode: controlMode,
    );
    setStateIfMounted(() => _recentRooms = _loadRecentRooms());
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
    final controlMode = await _showControlModeDialog();
    if (controlMode == null || !mounted) return;

    await _runSessionAction(
      setBusy: (busy) => _isCreating = busy,
      logMessage: 'Failed to create session',
      failureMessage: t.watchTogether.failedToCreate,
      action: () async {
        final sessionId = await widget.watchTogether.createSession(
          controlMode: controlMode,
          relayEndpoint: _relayEndpoint,
          displayName: _plexDisplayName,
        );
        await _recordRecentRoom(sessionId, controlMode: controlMode);
      },
    );
  }

  Future<ControlMode?> _showControlModeDialog() {
    return showScopedDialog<ControlMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.watchTogether.controlMode),
        content: Text(t.watchTogether.controlModeQuestion),
        actions: [
          DialogActionButton(onPressed: () => Navigator.pop(context), label: t.common.cancel),
          DialogActionButton(
            onPressed: () => Navigator.pop(context, ControlMode.hostOnly),
            label: t.watchTogether.hostOnly,
          ),
          DialogActionButton(
            onPressed: () => Navigator.pop(context, ControlMode.anyone),
            label: t.watchTogether.anyone,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Future<void> _joinSession() async {
    final sessionId = await showJoinSessionDialog(context);
    if (sessionId == null || !mounted) return;

    await _runSessionAction(
      setBusy: (busy) => _isJoining = busy,
      logMessage: 'Failed to join session',
      failureMessage: t.watchTogether.failedToJoin,
      action: () async {
        await widget.watchTogether.joinSession(sessionId, relayEndpoint: _relayEndpoint, displayName: _plexDisplayName);
        await _recordRecentRoom(sessionId);
      },
    );
  }

  Future<void> _enterRoom(RecentRoom room) async {
    await _runSessionAction(
      setBusy: (busy) => _enteringRoomCode = busy ? room.code : null,
      logMessage: 'Failed to enter room',
      failureMessage: t.watchTogether.failedToJoin,
      action: () async {
        await widget.watchTogether.enterRoom(
          room.code,
          relayEndpoint: _relayEndpoint,
          controlMode: room.controlMode ?? ControlMode.anyone,
          displayName: _plexDisplayName,
        );
        await _recordRecentRoom(room.code);
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
    await RecentRoomsService.removeRoom(room.code, profileId: profileId, endpoint: _relayEndpoint);
    setStateIfMounted(() => _recentRooms = _loadRecentRooms());
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
    return AlertDialog(
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
    final theme = Theme.of(context);
    final title = room.name ?? room.code;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: FocusableWrapper(
        useBackgroundFocus: true,
        borderRadius: 12,
        // Hold SELECT/OK to open the rename/remove menu on TV/dpad (matches media cards).
        enableLongPress: true,
        // The wrapper owns key handling; the ListTile's InkWell and the trailing
        // more_vert IconButton must not steal focus from the long-press handler.
        descendantsAreFocusable: false,
        onSelect: isBusy ? null : onTap,
        onLongPress: () => _showActions(context),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            leading: isEntering ? const LoadingIndicatorBox(size: 24) : const AppIcon(Symbols.meeting_room_rounded),
            title: Text(title, maxLines: 1, overflow: .ellipsis),
            subtitle: room.name != null
                ? Text(
                    room.code,
                    style: TextStyle(fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant),
                  )
                : null,
            trailing: IconButton(
              icon: const AppIcon(Symbols.more_vert_rounded),
              onPressed: () => _showActions(context),
            ),
            onTap: isBusy ? null : onTap,
            onLongPress: () => _showActions(context),
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
                      if (participant.isBuffering) const LoadingIndicatorBox(size: 16),
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
  const _RoomSurface({required this.child, this.highlighted = false});
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.22)),
      ),
      color: Color.alphaBlend(colors.onSurface.withValues(alpha: highlighted ? 0.045 : 0.025), colors.surface),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
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
        child: InkWell(
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
