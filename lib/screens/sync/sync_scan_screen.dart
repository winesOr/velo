import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../connection/connection_registry.dart';
import '../../danmaku/danmaku_settings_repository.dart';
import '../../focus/focusable_button.dart';
import '../../focus/key_event_utils.dart';
import '../../i18n/strings.g.dart';
import '../../profiles/plex_home_service.dart';
import '../../profiles/profile_connection_registry.dart';
import '../../profiles/profile_registry.dart';
import '../../services/storage_service.dart';
import '../../services/sync_pairing/sync_pairing_protocol.dart';
import '../../services/sync_pairing/sync_sender.dart';
import '../../theme/mono_tokens.dart';
import '../../utils/app_logger.dart';
import '../../utils/platform_detector.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/focused_scroll_scaffold.dart';

/// Phone-side camera flow that reads a TV pairing QR and sends the current
/// account/profile over the encrypted one-shot LAN channel.
class SyncScanScreen extends StatefulWidget {
  const SyncScanScreen({super.key});

  @override
  State<SyncScanScreen> createState() => _SyncScanScreenState();
}

class _SyncScanScreenState extends State<SyncScanScreen> {
  MobileScannerController? _controller;
  bool _handlingCode = false;
  bool _sending = false;
  String? _error;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    if (!PlatformDetector.isTV()) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handlingCode || _sending || _success) return;
    final raw = capture.barcodes.map((barcode) => barcode.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    _handlingCode = true;
    try {
      final pairing = SyncPairingUri.parse(raw);
      await _controller?.stop();
      if (!mounted) return;
      setState(() {
        _sending = true;
        _error = null;
      });
      final sender = SyncSender(
        connections: context.read<ConnectionRegistry>(),
        profiles: context.read<ProfileRegistry>(),
        profileConnections: context.read<ProfileConnectionRegistry>(),
        plexHome: context.read<PlexHomeService>(),
        storage: context.read<StorageService>(),
        danmaku: DanmakuSettingsRepository(),
      );
      await sender.send(pairing);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _success = true;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() => _error = t.auth.syncInvalidCode);
      await _restartScanner();
    } on SyncPairingHttpException catch (error) {
      appLogger.w('SyncScan: TV rejected sync', error: error);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.statusCode == 410 ? t.auth.syncExpired : t.auth.syncFailed(error: error.statusCode);
      });
      await _restartScanner();
    } catch (error, stackTrace) {
      appLogger.w('SyncScan: sync failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = t.auth.syncFailed(error: error);
      });
      await _restartScanner();
    } finally {
      _handlingCode = false;
    }
  }

  Future<void> _restartScanner() async {
    if (!mounted || _success) return;
    try {
      await _controller?.start();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.isTV()) {
      return FocusedScrollScaffold(
        title: Text(t.auth.scanSyncCode),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.auth.syncPhoneOnly, textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      );
    }
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => handleBackKeyNavigation(context, event),
      child: Scaffold(
        appBar: AppBar(title: Text(t.auth.scanSyncCode)),
        body: _success ? _buildSuccess(context) : _buildScanner(context),
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    final tokensRef = tokens(context);
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: (capture) => unawaited(_handleCapture(capture)),
                errorBuilder: (context, error) => _buildCameraError(context, error),
              ),
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 80)),
                  child: Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(tokensRef.radiusLg),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 28,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(tokensRef.radiusMd),
                  ),
                  child: Text(
                    t.auth.syncScanInstructions,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_sending || _error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                if (_sending) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(t.auth.syncSending),
                ],
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                  FocusableButton(
                    onPressed: () {
                      setState(() => _error = null);
                      unawaited(_restartScanner());
                    },
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _error = null);
                        unawaited(_restartScanner());
                      },
                      child: Text(t.common.retry),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
    final permissionDenied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(permissionDenied ? Symbols.no_photography_rounded : Symbols.videocam_off_rounded, size: 54),
            const SizedBox(height: 16),
            Text(
              permissionDenied ? t.auth.syncCameraPermissionDenied : t.auth.syncCameraUnavailable,
              textAlign: TextAlign.center,
            ),
            if (permissionDenied) ...[
              const SizedBox(height: 16),
              FocusableButton(
                onPressed: () => unawaited(_controller?.start() ?? Future.value()),
                child: FilledButton(
                  onPressed: () => unawaited(_controller?.start() ?? Future.value()),
                  child: Text(t.common.retry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(Symbols.check_circle_rounded, size: 88, color: Colors.green),
            const SizedBox(height: 20),
            Text(t.auth.syncSuccess, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(t.auth.syncSuccessDescription, textAlign: TextAlign.center),
            const SizedBox(height: 28),
            FocusableButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).maybePop(),
              child: FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(t.auth.syncDone)),
            ),
          ],
        ),
      ),
    );
  }
}
