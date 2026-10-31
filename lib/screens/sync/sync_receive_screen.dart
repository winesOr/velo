import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../connection/connection_registry.dart';
import '../../danmaku/danmaku_session.dart';
import '../../danmaku/danmaku_settings_repository.dart';
import '../../focus/focusable_button.dart';
import '../../focus/key_event_utils.dart';
import '../../i18n/strings.g.dart';
import '../../navigation/profile_session_screen.dart';
import '../../profiles/active_profile_binder.dart';
import '../../profiles/active_profile_provider.dart';
import '../../profiles/plex_home_service.dart';
import '../../profiles/profile_connection_registry.dart';
import '../../profiles/profile_registry.dart';
import '../../services/storage_service.dart';
import '../../services/sync_pairing/sync_import_service.dart';
import '../../services/sync_pairing/sync_pairing_protocol.dart';
import '../../services/sync_pairing/sync_receiver_server.dart';
import '../../theme/mono_tokens.dart';
import '../../utils/app_logger.dart';
import '../../utils/focus_utils.dart';
import '../../utils/navigation_transitions.dart';
import '../../utils/platform_detector.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/focused_scroll_scaffold.dart';

/// TV-side screen that advertises a short-lived QR code for one phone handoff.
class SyncReceiveScreen extends StatefulWidget {
  const SyncReceiveScreen({super.key});

  @override
  State<SyncReceiveScreen> createState() => _SyncReceiveScreenState();
}

class _SyncReceiveScreenState extends State<SyncReceiveScreen> {
  SyncReceiverServer? _receiver;
  StreamSubscription<SyncReceiverState>? _stateSubscription;
  SyncReceiverState? _state;
  String? _error;
  bool _starting = true;
  bool _applying = false;
  bool _readyToContinue = false;
  final FocusNode _doneFocusNode = FocusNode(debugLabel: 'sync_receive_done');

  @override
  void initState() {
    super.initState();
    unawaited(_startReceiver());
  }

  Future<void> _startReceiver() async {
    final old = _receiver;
    if (old != null) {
      await _stateSubscription?.cancel();
      await old.dispose();
    }
    if (!mounted) return;
    setState(() {
      _starting = true;
      _error = null;
      _state = null;
      _readyToContinue = false;
    });
    try {
      final storage = context.read<StorageService>();
      final receiver = SyncReceiverServer(
        importer: SyncImportService(
          connections: context.read<ConnectionRegistry>(),
          profiles: context.read<ProfileRegistry>(),
          profileConnections: context.read<ProfileConnectionRegistry>(),
          plexHome: context.read<PlexHomeService>(),
          storage: storage,
          danmaku: DanmakuSettingsRepository(),
        ),
      );
      _receiver = receiver;
      _stateSubscription = receiver.states.listen((next) {
        if (!mounted) return;
        setState(() => _state = next);
        if (next.imported) unawaited(_prepareImportedSession());
      });
      final state = await receiver.start();
      if (!mounted) return;
      setState(() {
        _state = state;
        _starting = false;
      });
    } catch (error, stackTrace) {
      appLogger.w('SyncReceive: failed to start receiver', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _prepareImportedSession() async {
    if (_applying) return;
    _applying = true;
    try {
      final activeProfiles = context.read<ActiveProfileProvider>();
      await activeProfiles.reloadFromStorage();
      if (!mounted) return;
      final hasActiveProfile = activeProfiles.active != null;
      if (!hasActiveProfile) {
        setState(() => _error = t.auth.syncNoProfile);
        return;
      }
      context.read<ActiveProfileBinder>().start();
      await activeProfiles.awaitBindingSettle();
      if (!mounted) return;
      // The live session may already hold the pre-sync source list.
      await DanmakuSession.instance.reload();
      setState(() => _readyToContinue = true);
      FocusUtils.requestFocusAfterBuild(this, _doneFocusNode);
    } catch (error, stackTrace) {
      appLogger.w('SyncReceive: failed to apply profile', error: error, stackTrace: stackTrace);
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _applying = false;
    }
  }

  void _continueToProfile() {
    if (!_readyToContinue || !mounted) return;
    unawaited(Navigator.pushReplacement(context, fadeRoute(ProfileSessionScreen(initialPromptHandled: true))));
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_receiver?.dispose());
    _doneFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformDetector.isTV()) {
      return FocusedScrollScaffold(
        title: Text(t.auth.syncFromPhone),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.auth.syncTvOnly, textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      );
    }

    final imported = _state?.imported ?? false;
    final pairing = _state?.pairing;
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => handleBackKeyNavigation(context, event),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 24, 40, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const AppIcon(Symbols.sync_rounded, size: 32),
                    const SizedBox(width: 12),
                    Text(t.auth.syncFromPhone, style: Theme.of(context).textTheme.headlineMedium),
                    const Spacer(),
                    FocusableButton(
                      autofocus: !imported,
                      useBackgroundFocus: true,
                      dimWhenUnfocused: false,
                      onPressed: () => Navigator.maybePop(context),
                      child: TextButton(onPressed: () => Navigator.maybePop(context), child: Text(t.auth.syncNotNow)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _buildInstructions(context, imported: imported)),
                          const SizedBox(width: 36),
                          _buildQrPanel(context, pairing, imported: imported),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions(BuildContext context, {required bool imported}) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(
          imported ? Symbols.check_circle_rounded : Symbols.phonelink_ring_rounded,
          size: 60,
          color: imported ? Colors.greenAccent : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text(imported ? t.auth.syncImportedTitle : t.auth.syncWaiting, style: textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text(
          imported ? t.auth.syncImportedDescription : t.auth.syncFromPhoneDescription,
          style: textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        if (!imported) ...[
          const SizedBox(height: 22),
          _Step(number: '1', text: t.auth.scanSyncCode),
          const SizedBox(height: 12),
          _Step(number: '2', text: t.auth.syncScanInstructions),
        ],
      ],
    );
  }

  Widget _buildQrPanel(BuildContext context, SyncPairingUri? pairing, {required bool imported}) {
    final tokensRef = tokens(context);
    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(tokensRef.radiusLg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_starting)
            const SizedBox.square(dimension: 248, child: Center(child: CircularProgressIndicator()))
          else if (imported)
            const SizedBox.square(
              dimension: 248,
              child: Center(
                child: AppIcon(Symbols.check_circle_rounded, fill: 1, size: 150, color: Colors.greenAccent),
              ),
            )
          else if (pairing != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(14),
              child: QrImageView(
                data: pairing.encode(),
                size: 248,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            )
          else
            SizedBox.square(
              dimension: 248,
              child: Center(
                child: Text(
                  t.auth.syncExpired,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            imported ? t.auth.syncImportedDescription : t.auth.syncWaitingDescription,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!imported && !_starting) ...[
            const SizedBox(height: 12),
            FocusableButton(
              onPressed: _startReceiver,
              useBackgroundFocus: true,
              dimWhenUnfocused: false,
              child: TextButton(onPressed: _startReceiver, child: Text(t.auth.syncTryAgain)),
            ),
          ] else if (imported && _readyToContinue) ...[
            const SizedBox(height: 12),
            FocusableButton(
              focusNode: _doneFocusNode,
              onPressed: _continueToProfile,
              useBackgroundFocus: true,
              dimWhenUnfocused: false,
              child: FilledButton(onPressed: _continueToProfile, child: Text(t.auth.syncDone)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
          child: Text(number, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    );
  }
}
