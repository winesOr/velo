part of '../video_controls.dart';

/// Mobile player drawers, queue popover and one-shot actions.
extension _PlexVideoControlsMobileChipMethods on _PlexVideoControlsState {
  String? get _mobileCoreLabel {
    if (!Platform.isAndroid) return null;
    return switch (widget.player.playerType) {
      'exoplayer' => t.settings.exoPlayer,
      'mpv' => t.settings.mpv,
      _ => null,
    };
  }

  void _openSpeedDrawer(BuildContext context, TrackControlsState state) {
    widget.chromeController.cancelAutoHide();
    OverlaySheetController.of(context)
        .show(
          style: OverlaySheetStyle.glass,
          presentation: OverlaySheetPresentation.edgeDrawer,
          constraints: BoxConstraints(maxWidth: PlayerSettingsDrawer.widthFor(context)),
          builder: (_) => PlayerSpeedDrawer(player: widget.player, state: state),
        )
        .whenComplete(_startHideTimer);
  }

  void _openChapterDrawer(BuildContext context) {
    widget.chromeController.cancelAutoHide();
    OverlaySheetController.of(context)
        .show(
          style: OverlaySheetStyle.glass,
          presentation: OverlaySheetPresentation.edgeDrawer,
          constraints: BoxConstraints(maxWidth: PlayerSettingsDrawer.widthFor(context)),
          builder: (_) => ChapterSheet(
            player: widget.player,
            chapters: _chapters,
            chaptersLoaded: _chaptersLoaded,
            canControl: widget.canControl,
            serverId: widget.metadata.serverId,
            onSeekRequested: widget.onSeekRequested,
            onSeekCompleted: widget.onSeekCompleted,
          ),
        )
        .whenComplete(_startHideTimer);
  }

  void _openEpisodesDrawer(BuildContext context) {
    widget.chromeController.cancelAutoHide();
    final host = context.findAncestorStateOfType<VideoPlayerScreenState>();
    OverlaySheetController.of(context)
        .show(
          style: OverlaySheetStyle.glass,
          presentation: OverlaySheetPresentation.edgeDrawer,
          constraints: BoxConstraints(maxWidth: PlayerSettingsDrawer.widthFor(context)),
          builder: (_) => EpisodesDrawer(
            current: widget.metadata,
            offline: widget.isOfflinePlayback,
            canNavigate: widget.canNavigateMediaItems,
            onSelect: (item) async {
              if (host == null) return false;
              _hiddenSeek.cancel();
              _desktopControlsKey.currentState?.abandonPendingSeek();
              _dismissSkipFeedback();
              return host.navigateToQueueItemForDrawer(item);
            },
            isAuthorized: () => host?.canChangeQueueFromDrawer() ?? false,
            onRepeat: (mode) async => await host?.changeDrawerRepeat(mode) ?? false,
            onShuffle: (enabled, isCurrent) async =>
                await host?.changeDrawerShuffle(enabled, isDrawerCurrent: isCurrent) ?? false,
          ),
        )
        .whenComplete(_startHideTimer);
  }

  void _openPlayerDrawer(BuildContext context, TrackControlsState state, PlayerDrawerTab tab) {
    widget.chromeController.cancelAutoHide();
    OverlaySheetController.of(context)
        .show(
          style: OverlaySheetStyle.glass,
          presentation: OverlaySheetPresentation.edgeDrawer,
          constraints: BoxConstraints(maxWidth: PlayerSettingsDrawer.widthFor(context)),
          builder: (_) => PlayerSettingsDrawer(
            player: widget.player,
            state: state,
            metadata: widget.metadata,
            volumeController: widget.volumeController,
            initialTab: tab,
            coreLabel: _mobileCoreLabel,
            onSwitchCore: widget.onSwitchPlayerCore,
          ),
        )
        .whenComplete(_startHideTimer);
  }

  void _openCastPanel(BuildContext context) {
    if (widget.onCast != null) {
      widget.onCast!();
      return;
    }
    widget.chromeController.cancelAutoHide();
    OverlaySheetController.of(context)
        .show(
          style: OverlaySheetStyle.glass,
          presentation: OverlaySheetPresentation.edgeDrawer,
          constraints: BoxConstraints(maxWidth: PlayerSettingsDrawer.widthFor(context)),
          builder: (_) => const _CastUnavailablePanel(),
        )
        .whenComplete(_startHideTimer);
  }

  void _toggleDanmaku() {
    final session = DanmakuSession.instance;
    unawaited(session.updateStyle(enabled: !session.enabled).then((_) => _setControlsState(() {})));
  }

  /// Flips between portrait and landscape. The rotation-lock pref now means
  /// "landscape", so the existing effect binding applies the change.
  void _toggleOrientation() {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    unawaited(_settings.write(SettingsService.rotationLocked, portrait));
    if (!portrait) unawaited(OrientationHelper.lockPortraitOrientation());
  }

  /// Android copies the video plane; danmaku and the HUD are not included.
  Future<void> _captureMobileScreenshot() async {
    try {
      await deviceChannel.invokeMethod<String>('captureVideoFrame');
      if (mounted) _showScreenshotToast();
    } catch (error, stackTrace) {
      appLogger.w('Video frame capture failed', error: error, stackTrace: stackTrace);
      if (mounted) widget.toastController.show(Symbols.error_rounded, t.videoControls.screenshotFailed);
    }
  }
}

class _CastUnavailablePanel extends StatelessWidget {
  const _CastUnavailablePanel();

  @override
  Widget build(BuildContext context) {
    final glass = GlassSheetColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(Symbols.cast_rounded, size: 20, color: glass.foreground),
              const SizedBox(width: 8),
              Text(
                t.videoControls.castUnavailableTitle,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: glass.foreground),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(t.videoControls.castUnavailable, style: TextStyle(fontSize: 13, color: glass.muted)),
        ],
      ),
    );
  }
}
