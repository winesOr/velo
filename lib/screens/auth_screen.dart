import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/widgets/app_icon.dart';
import 'package:provider/provider.dart';
import '../connection/connection.dart';
import '../connection/connection_registry.dart';
import '../connection/plex_account_setup.dart';
import '../database/app_database.dart';
import '../mixins/controller_disposer_mixin.dart';
import '../profiles/active_profile_binder.dart';
import '../profiles/active_profile_provider.dart';
import '../profiles/plex_home_service.dart';
import '../profiles/profile.dart';
import '../profiles/profile_connection_registry.dart';
import '../profiles/profile_selection_policy.dart';
import '../services/plex_auth_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../providers/account_preferences_controller.dart';
import '../i18n/strings.g.dart';
import '../utils/app_logger.dart';
import '../utils/dialogs.dart';
import '../utils/platform_detector.dart';
import '../focus/focusable_button.dart';
import '../focus/focusable_text_field.dart';
import '../focus/key_event_utils.dart';
import '../media/media_backend.dart';
import '../media/media_browser_dialect.dart';
import '../navigation/profile_session_screen.dart';
import '../utils/navigation_transitions.dart';
import '../widgets/backend_badge.dart';
import '../widgets/dialog_action_button.dart';
import 'auth/plex_pin_auth_flow.dart';
import 'profile/profile_switch_screen.dart';
import 'settings/add_jellyfin_screen.dart';
import 'sync/sync_receive_screen.dart';
import 'sync/sync_scan_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.initialErrorMessage,
    this.initializeServices = true,
    this.databaseRecoveryRequired = false,
  });

  final String? initialErrorMessage;
  final bool initializeServices;
  final bool databaseRecoveryRequired;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;
  // Reuse a one-shot service for the debug-token verify path; the Plex
  // PIN/QR flow inside [PlexPinAuthFlow] owns its own service instance.
  PlexAuthService? _verifyOnlyService;
  Future<void>? _recoveryAcknowledgement;
  bool _recoveryAcknowledged = false;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialErrorMessage;
    // Debug-token verification only — release builds must not hold an idle
    // auth service (and its HTTP client) for a dialog that can't open.
    if (kDebugMode && widget.initializeServices) unawaited(_initVerifyService());
  }

  Future<void> _initVerifyService() async {
    final svc = await PlexAuthService.create();
    if (!mounted) {
      svc.dispose();
      return;
    }
    setState(() => _verifyOnlyService = svc);
  }

  @override
  void dispose() {
    _verifyOnlyService?.dispose();
    super.dispose();
  }

  /// Auto-select the active profile after sign-in *only* when there's a
  /// single, unprotected Plex Home user — there's no choice for the user to
  /// make. With multiple Home users (the "real" Home case) we leave the active
  /// id unset so [MainScreen] forces the picker before the binder runs,
  /// avoiding a surprise PIN prompt on whichever user we'd otherwise
  /// pre-select. A PIN-protected single user also goes through the picker —
  /// see [initialPlexHomeProfileFromCache].
  Future<void> _selectInitialProfile(
    PlexHomeService plexHome,
    ActiveProfileProvider activeProfiles,
    PlexAccountConnection accountConn,
  ) async {
    await activeProfiles.initialize();
    final profile = initialPlexHomeProfileFromCache(plexHome, accountConn);
    if (profile == null) {
      await activeProfiles.clearActiveProfile();
      return;
    }
    await activeProfiles.activate(profile);
  }

  Future<bool> _prepareDatabaseRecoveryForSignIn() async {
    if (!widget.databaseRecoveryRequired || _recoveryAcknowledged) return true;
    final acknowledgement = _recoveryAcknowledgement ??= context
        .read<AppDatabase>()
        .acknowledgeTvosDatabaseRecoveryRequired();
    try {
      await acknowledgement;
      _recoveryAcknowledged = true;
      if (mounted) setState(() => _errorMessage = null);
      return mounted;
    } catch (_) {
      _recoveryAcknowledgement = null;
      if (mounted) setState(() => _errorMessage = t.auth.localDataRecoveryRequired);
      return false;
    }
  }

  Future<void> _startPlexAfterRecovery(VoidCallback start) async {
    if (await _prepareDatabaseRecoveryForSignIn()) start();
  }

  /// Persist the new Plex account into the connection pipeline, resolve the
  /// initial active profile when possible, and navigate to the main screen.
  /// The top-level [ActiveProfileBinder] picks up the active profile id and
  /// connects servers via [MultiServerManager.refreshTokensForProfile].
  Future<void> _connectToAllServersAndNavigate(String plexToken) async {
    if (!await _prepareDatabaseRecoveryForSignIn()) return;
    if (!mounted) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final connectionRegistry = context.read<ConnectionRegistry>();
    final profileConnections = context.read<ProfileConnectionRegistry>();
    final plexHome = context.read<PlexHomeService>();

    try {
      final storage = await StorageService.getInstance();
      final registration = await registerPlexAccountFromToken(
        token: plexToken,
        connections: connectionRegistry,
        profileConnections: profileConnections,
        storage: storage,
        plexHome: plexHome,
      );
      final accountConnection = registration.connection;

      if (accountConnection.servers.isEmpty) {
        // Nothing to roll back — the registered account row is exactly what
        // a retry will upsert over; wiping global credentials here would
        // also nuke the device identity and every server-endpoint cache.
        if (!mounted) return;
        setState(() {
          _isAuthenticating = false;
          _errorMessage = t.serverSelection.noServersFoundForAccount(
            username: registration.username,
            email: registration.email,
          );
        });
        return;
      }

      if (!registration.homeUsersFetched && plexHome.current[accountConnection.id] == null) {
        // A failed home-user fetch is NOT "multiple users, let them pick":
        // with no home users and no locals there is no profile to select,
        // and navigating lands in a dead session. Surface a retry instead.
        if (!mounted) return;
        setState(() {
          _isAuthenticating = false;
          _errorMessage = t.profiles.failedToLoadHomeUsers;
        });
        return;
      }

      if (!mounted) return;
      final activeProfiles = context.read<ActiveProfileProvider>();
      await _selectInitialProfile(plexHome, activeProfiles, accountConnection);

      if (!mounted) return;

      // Start the binder before the picker/MainScreen, mirroring the
      // cold-start SetupScreen ordering. On a fresh install SetupScreen
      // routes here without ever starting it, so without this the profile
      // activated above is bound only by MainScreen's post-frame start() —
      // Discover renders a "No servers available" flash in the gap, and the
      // picker's awaitBindingSettle resolves before anything is bound.
      context.read<ActiveProfileBinder>().start();

      final settings = await SettingsService.getInstance();
      if (!mounted) return;

      final promptHandled = shouldPromptForInitialProfileSelection(
        activeProfile: activeProfiles.active,
        hasProfiles: activeProfiles.profiles.isNotEmpty,
        accountHasHomeUsers: plexHome.current[accountConnection.id]?.isNotEmpty == true,
        requireProfileSelectionOnOpen: activeProfiles.requiresSelectionOnOpen(settings),
      );
      if (promptHandled) {
        final selected = await Navigator.of(
          context,
        ).push<bool>(MaterialPageRoute(builder: (_) => const ProfileSwitchScreen(requireSelection: true)));
        if (!mounted) return;
        if (selected != true || activeProfiles.active == null) {
          setState(() => _isAuthenticating = false);
          return;
        }
      }

      await context.read<AccountPreferencesController>().ensureActiveLoaded();

      if (!mounted) return;
      unawaited(
        Navigator.pushReplacement(context, fadeRoute(ProfileSessionScreen(initialPromptHandled: promptHandled))),
      );
    } catch (e) {
      appLogger.e('Failed to connect to servers', error: e);
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _errorMessage = t.serverSelection.failedToLoadServers(error: e);
      });
    }
  }

  void _handleDebugTap() {
    if (!kDebugMode) return;
    _showDebugTokenDialog();
  }

  Future<void> _connectToMediaBrowser(MediaBrowserDialect dialect) async {
    if (!await _prepareDatabaseRecoveryForSignIn()) return;
    if (!mounted) return;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddJellyfinScreen(dialect: dialect)),
    );
    if (!mounted || added != true) return;
    // The connection persisted and the manager registered the client; move
    // straight to the main screen. [MainScreen] reads the active client
    // from the server provider, so no client argument is needed here.
    unawaited(Navigator.pushReplacement(context, fadeRoute(const ProfileSessionScreen())));
  }

  void _showDebugTokenDialog() {
    unawaited(
      showScopedDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return _DebugTokenDialog(verifyService: _verifyOnlyService, onTokenAccepted: _connectToAllServersAndNavigate);
        },
      ),
    );
  }

  void _openSyncReceive() {
    unawaited(Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SyncReceiveScreen())));
  }

  void _openSyncScan() {
    unawaited(Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SyncScanScreen())));
  }

  @override
  Widget build(BuildContext context) {
    final isTv = PlatformDetector.isTV();
    // TV gets a purpose-built ten-foot split: a calm brand panel and a wide,
    // single-reading-order action column. Desktop keeps its denser form.
    final isDesktop = MediaQuery.sizeOf(context).width > 700;
    final size = MediaQuery.sizeOf(context);

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => handleBackKeyNavigation(context, event),
      child: Scaffold(
        body: isTv
            ? _buildTvAuthLayout(context, size)
            : Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 800 : 400),
                  padding: .fromLTRB(24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: .center,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: .center,
                                crossAxisAlignment: .center,
                                children: [
                                  Image.asset('assets/velo.png', width: 120, height: 120),
                                  const SizedBox(height: 24),
                                  Text(
                                    t.app.title,
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: .bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 48),
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: .min,
                                    crossAxisAlignment: .stretch,
                                    children: [_buildAuthBody()],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: .min,
                            crossAxisAlignment: .stretch,
                            children: [
                              Image.asset('assets/velo.png', width: 120, height: 120),
                              const SizedBox(height: 24),
                              Text(
                                t.app.title,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: .bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 48),
                              _buildAuthBody(),
                            ],
                          ),
                        ),
                ),
              ),
      ),
    );
  }

  Widget _buildTvAuthLayout(BuildContext context, Size size) {
    final theme = Theme.of(context);
    final wide = size.width >= 1180;
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.72, -.92),
              radius: 1.1,
              colors: [Color(0xff262a32), Color(0xff08090b)],
            ),
          ),
        ),
        Positioned(
          left: size.width * .08,
          right: size.width * .08,
          top: size.height * .08,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: wide ? 9 : 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset('assets/velo.png', width: 84, height: 84),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.app.title,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.auth.syncFromPhoneDescription,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 18,
                                  color: Colors.white.withValues(alpha: .58),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 72),
                    Text(
                      t.auth.syncFromPhone,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 38,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      t.auth.syncFromPhoneDescription,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 20,
                        height: 1.55,
                        color: Colors.white.withValues(alpha: .68),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: wide ? size.width * .09 : 52),
              Expanded(
                flex: wide ? 7 : 8,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 620),
                  padding: const EdgeInsets.fromLTRB(32, 30, 32, 30),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xe01c2026), Color(0xc20c0e11)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: .12)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 48, offset: const Offset(0, 20)),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [_buildAuthBody()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTvActionButton({
    required BuildContext context,
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
    required bool primary,
  }) {
    final theme = Theme.of(context);
    return FocusableButton(
      autofocus: primary,
      onPressed: onPressed,
      useBackgroundFocus: !primary,
      dimWhenUnfocused: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: primary ? const Color(0xfff4f5f7) : Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary ? Colors.transparent : Colors.white.withValues(alpha: .16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(color: primary ? Colors.black : Colors.white.withValues(alpha: .86), size: 24),
              child: icon,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: primary ? Colors.black : Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTvInitialButtons(BuildContext context, VoidCallback startBrowser, VoidCallback startQr, bool busy) {
    void startBrowserAfterRecovery() => unawaited(_startPlexAfterRecovery(startBrowser));
    const jellyfinDialect = MediaBrowserDialect.jellyfin;
    const embyDialect = MediaBrowserDialect.emby;
    void connectToJellyfin() => unawaited(_connectToMediaBrowser(jellyfinDialect));
    void connectToEmby() => unawaited(_connectToMediaBrowser(embyDialect));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTvActionButton(
          context: context,
          icon: const AppIcon(Symbols.sync_rounded),
          label: t.auth.syncFromPhone,
          onPressed: busy ? null : _openSyncReceive,
          primary: true,
        ),
        const SizedBox(height: 14),
        _buildTvActionButton(
          context: context,
          icon: const AppIcon(Symbols.language_rounded),
          label: t.auth.useBrowser,
          onPressed: busy ? null : startBrowserAfterRecovery,
          primary: false,
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withValues(alpha: .1))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                t.auth.or,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 15, color: Colors.white.withValues(alpha: .42)),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withValues(alpha: .1))),
          ],
        ),
        const SizedBox(height: 22),
        _buildTvActionButton(
          context: context,
          icon: const BackendBadge(backend: MediaBackend.jellyfin, size: 24),
          label: t.auth.connectToMediaBrowser(product: jellyfinDialect.productName),
          onPressed: busy ? null : connectToJellyfin,
          primary: false,
        ),
        const SizedBox(height: 12),
        _buildTvActionButton(
          context: context,
          icon: const BackendBadge(backend: MediaBackend.emby, size: 24),
          label: t.auth.connectToMediaBrowser(product: embyDialect.productName),
          onPressed: busy ? null : connectToEmby,
          primary: false,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 18),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildTvAuthBody() {
    if (_isAuthenticating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return PlexPinAuthFlow(
      onTokenReceived: _connectToAllServersAndNavigate,
      autoStartQrOnTV: false,
      initializeService: widget.initializeServices,
      initialButtonsBuilder: _buildTvInitialButtons,
    );
  }

  Widget _buildAuthBody() {
    if (_isAuthenticating) {
      return Column(
        mainAxisSize: .min,
        children: [
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text(
            t.auth.waitingForAuth,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      );
    }
    if (PlatformDetector.isTV()) {
      return _buildTvAuthBody();
    }
    return PlexPinAuthFlow(
      onTokenReceived: _connectToAllServersAndNavigate,
      autoStartQrOnTV: false,
      initializeService: widget.initializeServices,
      initialButtonsBuilder: _buildInitialButtons,
    );
  }

  Widget _buildInitialButtons(BuildContext context, VoidCallback startBrowser, VoidCallback startQr, bool busy) {
    final isTV = PlatformDetector.isTV();
    final isAppleTV = PlatformDetector.isAppleTV();
    void startBrowserAfterRecovery() => unawaited(_startPlexAfterRecovery(startBrowser));
    void startQrAfterRecovery() => unawaited(_startPlexAfterRecovery(startQr));
    const jellyfinDialect = MediaBrowserDialect.jellyfin;
    const embyDialect = MediaBrowserDialect.emby;
    void connectToJellyfin() => unawaited(_connectToMediaBrowser(jellyfinDialect));
    void connectToEmby() => unawaited(_connectToMediaBrowser(embyDialect));
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        if (isTV) ...[
          FocusableButton(
            autofocus: true,
            onPressed: busy ? null : _openSyncReceive,
            useBackgroundFocus: true,
            child: ElevatedButton(
              onPressed: busy ? null : _openSyncReceive,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Row(
                mainAxisAlignment: .center,
                mainAxisSize: .min,
                children: [
                  const AppIcon(Symbols.sync_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(t.auth.syncFromPhone),
                ],
              ),
            ),
          ),
          if (!isAppleTV) ...[
            const SizedBox(height: 12),
            FocusableButton(
              onPressed: busy ? null : startBrowserAfterRecovery,
              child: OutlinedButton(
                onPressed: busy ? null : startBrowserAfterRecovery,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(t.auth.useBrowser),
              ),
            ),
          ],
        ] else ...[
          FocusableButton(
            onPressed: busy ? null : _openSyncScan,
            useBackgroundFocus: true,
            child: ElevatedButton.icon(
              onPressed: busy ? null : _openSyncScan,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const AppIcon(Symbols.qr_code_scanner_rounded, size: 20),
              label: Text(t.auth.scanSyncCode),
            ),
          ),
          const SizedBox(height: 12),
          FocusableButton(
            onPressed: busy ? null : startQrAfterRecovery,
            child: OutlinedButton(
              onPressed: busy ? null : startQrAfterRecovery,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(t.auth.showQRCode),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                t.auth.or,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
            Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
          ],
        ),
        const SizedBox(height: 12),
        FocusableButton(
          onPressed: connectToJellyfin,
          child: OutlinedButton.icon(
            onPressed: connectToJellyfin,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: const BackendBadge(backend: MediaBackend.jellyfin, size: 18),
            label: Text(t.auth.connectToMediaBrowser(product: jellyfinDialect.productName)),
          ),
        ),
        const SizedBox(height: 12),
        FocusableButton(
          onPressed: connectToEmby,
          child: OutlinedButton.icon(
            onPressed: connectToEmby,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: const BackendBadge(backend: MediaBackend.emby, size: 18),
            label: Text(t.auth.connectToMediaBrowser(product: embyDialect.productName)),
          ),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 12),
          FocusableButton(
            onPressed: _handleDebugTap,
            child: OutlinedButton(
              onPressed: _handleDebugTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
              ),
              child: const Text('Debug: Enter Plex Token', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

@visibleForTesting
/// The profile to auto-select after sign-in: the account's only Plex Home
/// user, unless it is PIN-protected. A bare activation skips the PIN check
/// the picker performs, and the first bind of the session may reuse a cached
/// user token — after an in-app logout, the one the previous session minted —
/// so a protected user must be picked (and its PIN entered) explicitly.
Profile? initialPlexHomeProfileFromCache(PlexHomeService plexHome, PlexAccountConnection accountConn) {
  final users = plexHome.current[accountConn.id];
  if (users == null || users.length != 1 || users.single.protected) return null;
  return Profile.virtualPlexHome(connectionId: accountConn.id, homeUser: users.single);
}

@visibleForTesting
bool shouldPromptForInitialProfileSelection({
  required Profile? activeProfile,
  required bool hasProfiles,
  required bool accountHasHomeUsers,
  required bool requireProfileSelectionOnOpen,
}) {
  return requireProfileSelectionOnOpen || (activeProfile == null && (hasProfiles || accountHasHomeUsers));
}

/// Stateful so the [TextEditingController] is disposed when the dialog
/// closes — the previous inline `showDialog` builder created the
/// controller in a closure and leaked it on every dismissal.
class _DebugTokenDialog extends StatefulWidget {
  final PlexAuthService? verifyService;
  final Future<void> Function(String token) onTokenAccepted;

  const _DebugTokenDialog({required this.verifyService, required this.onTokenAccepted});

  @override
  State<_DebugTokenDialog> createState() => _DebugTokenDialogState();
}

class _DebugTokenDialogState extends State<_DebugTokenDialog> with ControllerDisposerMixin {
  late final TextEditingController _tokenController = createTextEditingController();
  String? _errorMessage;
  bool _busy = false;

  Future<void> _submit() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _errorMessage = t.errors.pleaseEnterToken);
      return;
    }
    final svc = widget.verifyService;
    if (svc == null) {
      setState(() => _errorMessage = 'Auth service not ready');
      return;
    }
    final navigator = Navigator.of(context);
    setState(() {
      _errorMessage = null;
      _busy = true;
    });
    try {
      final isValid = await svc.verifyToken(token);
      if (!mounted) return;
      if (!isValid) {
        setState(() {
          _errorMessage = t.errors.invalidToken;
          _busy = false;
        });
        return;
      }
      navigator.pop();
      await widget.onTokenAccepted(token);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = t.errors.failedToVerifyToken(error: e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Debug: Enter Plex Token'),
      content: Column(
        mainAxisSize: .min,
        children: [
          FocusableTextFormField(
            controller: _tokenController,
            decoration: InputDecoration(
              labelText: 'Plex Auth Token',
              hintText: 'Enter your Plex.tv token',
              errorText: _errorMessage,
              border: const OutlineInputBorder(),
            ),
            obscureText: true,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _busy ? null : _submit(),
          ),
        ],
      ),
      actions: [
        DialogActionButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), label: t.common.cancel),
        DialogActionButton(onPressed: _busy ? null : _submit, label: t.auth.authenticate, isPrimary: true),
      ],
    );
  }
}
