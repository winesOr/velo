import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../i18n/strings.g.dart';
import '../services/android_app_update_service.dart';
import '../services/update_service.dart';
import '../widgets/dialog_action_button.dart';
import 'dialogs.dart';

Future<void> showUpdateAvailableDialog(
  BuildContext context,
  Map<String, dynamic> updateInfo, {
  required String title,
  required String dismissLabel,
  bool showSkipVersion = false,
  bool autoDownload = false,
}) {
  if (Platform.isAndroid && updateInfo['androidAsset'] is AndroidUpdateAsset) {
    return showScopedDialog<void>(
      context: context,
      builder: (_) => AndroidUpdateDialog(
        updateInfo: updateInfo,
        title: title,
        dismissLabel: dismissLabel,
        showSkipVersion: showSkipVersion,
        autoDownload: autoDownload,
      ),
    );
  }
  return showScopedDialog<void>(
    context: context,
    builder: (dialogContext) {
      final latestVersion = updateInfo['latestVersion'] as String;
      final releaseUrl = updateInfo['releaseUrl'] as String;

      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Text(
              t.update.versionAvailable(version: latestVersion),
              style: Theme.of(dialogContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              t.update.currentVersion(version: updateInfo['currentVersion']),
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            if (Platform.isAndroid) ...[const SizedBox(height: 16), Text(t.update.manualUpdateRequired)],
          ],
        ),
        actions: [
          DialogActionButton(onPressed: () => Navigator.pop(dialogContext), label: dismissLabel),
          if (showSkipVersion)
            DialogActionButton(
              onPressed: () async {
                await UpdateService.skipVersion(latestVersion);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              label: t.update.skipVersion,
            ),
          DialogActionButton(
            onPressed: () async {
              final url = Uri.parse(releaseUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            label: t.update.viewRelease,
            isPrimary: true,
          ),
        ],
      );
    },
  );
}

/// The download belongs to the service, while permission and installer UI
/// belong to this visible dialog. Closing the dialog keeps the download alive.
class AndroidUpdateDialog extends StatefulWidget {
  final Map<String, dynamic> updateInfo;
  final String title;
  final String dismissLabel;
  final bool showSkipVersion;
  final bool autoDownload;
  final AndroidAppUpdateService? service;

  const AndroidUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.title,
    required this.dismissLabel,
    this.showSkipVersion = false,
    this.autoDownload = false,
    this.service,
  });

  @override
  State<AndroidUpdateDialog> createState() => _AndroidUpdateDialogState();
}

class _AndroidUpdateDialogState extends State<AndroidUpdateDialog> with WidgetsBindingObserver {
  late final AndroidAppUpdateService _service;
  bool _autoInstallRequested = false;
  bool _actionInProgress = false;

  bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  bool get _matchesUpdate => _service.updateInfo?['latestVersion'] == widget.updateInfo['latestVersion'];

  AndroidUpdateStatus get _status => _matchesUpdate ? _service.status : AndroidUpdateStatus.idle;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AndroidAppUpdateService.instance;
    _service.addListener(_onUpdateChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.autoDownload) return;
      switch (_status) {
        case AndroidUpdateStatus.idle:
          unawaited(_download());
        case AndroidUpdateStatus.downloading:
        case AndroidUpdateStatus.ready:
          _autoInstallRequested = true;
          _tryAutomaticInstall();
        case AndroidUpdateStatus.needsPermission:
        case AndroidUpdateStatus.installing:
        case AndroidUpdateStatus.error:
          // A declined permission, cancelled installer or failed download is
          // retried only after another explicit action.
          break;
      }
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onUpdateChanged() {
    if (!mounted) return;
    setState(() {});
    _tryAutomaticInstall();
  }

  void _tryAutomaticInstall() {
    if (!mounted || !_autoInstallRequested || !_isForeground || _actionInProgress) return;
    if (_status != AndroidUpdateStatus.ready || ModalRoute.of(context)?.isCurrent != true) return;
    // Consume before crossing into Android so resume/cancellation cannot
    // trigger another installer automatically.
    _autoInstallRequested = false;
    unawaited(_install());
  }

  Future<void> _download() async {
    _autoInstallRequested = true;
    await _service.downloadUpdate(widget.updateInfo);
    if (mounted) _tryAutomaticInstall();
  }

  Future<void> _install({bool requestPermission = false}) async {
    if (!mounted || !_isForeground || _actionInProgress) return;
    _autoInstallRequested = false;
    setState(() => _actionInProgress = true);
    try {
      await _service.installUpdate(requestPermission: requestPermission);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_resumeInstall());
  }

  Future<void> _resumeInstall() async {
    if (!mounted || _actionInProgress || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _actionInProgress = true);
    try {
      await _service.resumePendingInstall();
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
    if (mounted) _tryAutomaticInstall();
  }

  Future<void> _viewRelease() async {
    final url = Uri.tryParse(widget.updateInfo['releaseUrl'] as String? ?? '');
    if (url != null && await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final progress = _matchesUpdate ? _service.progress : null;
    final latestVersion = widget.updateInfo['latestVersion'] as String;
    final description = switch (status) {
      AndroidUpdateStatus.idle => null,
      AndroidUpdateStatus.downloading =>
        progress == null
            ? t.update.downloading
            : t.update.downloadProgress(percent: (progress * 100).round().toString()),
      AndroidUpdateStatus.ready => t.update.readyToInstall,
      AndroidUpdateStatus.needsPermission => t.update.permissionRequired,
      AndroidUpdateStatus.installing => t.update.installerOpened,
      AndroidUpdateStatus.error => t.update.updateFailed,
    };

    return PopScope(
      canPop: !_actionInProgress,
      child: AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Text(t.update.versionAvailable(version: latestVersion), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                t.update.currentVersion(version: widget.updateInfo['currentVersion']),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_actionInProgress) ...[
                const SizedBox(height: 16),
                Text(t.update.preparingInstall),
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ] else if (description != null) ...[
                const SizedBox(height: 16),
                Text(description),
              ],
              if (status == AndroidUpdateStatus.downloading) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(t.update.downloadContinues, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        actions: [
          DialogActionButton(
            onPressed: _actionInProgress ? null : () => Navigator.pop(context),
            label: widget.dismissLabel,
          ),
          if (widget.showSkipVersion && status != AndroidUpdateStatus.downloading)
            DialogActionButton(
              onPressed: _actionInProgress
                  ? null
                  : () async {
                      _autoInstallRequested = false;
                      await UpdateService.skipVersion(latestVersion);
                      if (context.mounted) Navigator.pop(context);
                    },
              label: t.update.skipVersion,
            ),
          DialogActionButton(onPressed: _actionInProgress ? null : _viewRelease, label: t.update.viewRelease),
          if (status != AndroidUpdateStatus.downloading)
            DialogActionButton(
              onPressed: _actionInProgress
                  ? null
                  : switch (status) {
                      AndroidUpdateStatus.idle || AndroidUpdateStatus.error => () => unawaited(_download()),
                      AndroidUpdateStatus.needsPermission => () => unawaited(_install(requestPermission: true)),
                      _ => () => unawaited(_install()),
                    },
              label: switch (status) {
                AndroidUpdateStatus.idle => t.update.download,
                AndroidUpdateStatus.error => t.common.retry,
                AndroidUpdateStatus.needsPermission => t.update.allowInstallation,
                _ => t.update.installUpdate,
              },
              isPrimary: true,
            ),
        ],
      ),
    );
  }
}
