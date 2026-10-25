part of '../video_controls.dart';

/// Popovers, the "more" drawer and one-shot actions of the mobile player
/// (V4, `design/prototype/player.html`). Popovers anchor above their chip;
/// the drawer floats at the right edge. Both use [OverlaySheetStyle.glass].
extension _PlexVideoControlsMobileChipMethods on _PlexVideoControlsState {
  String? get _mobileCoreLabel {
    if (!Platform.isAndroid) return null;
    return switch (widget.player.playerType) {
      'exoplayer' => t.settings.exoPlayer,
      'mpv' => t.settings.mpv,
      _ => null,
    };
  }

  /// Lifts the anchor above the whole bottom HUD so the timeline stays visible.
  Rect _popoverAnchor(BuildContext context, Rect chip) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return chip;
    final top = box.localToGlobal(Offset.zero).dy + box.size.height - _mobileBottomHudHeight;
    return Rect.fromLTRB(chip.left, top, chip.right, chip.bottom);
  }

  /// Timeline row plus control row, measured from the bottom of the surface.
  static const double _mobileBottomHudHeight = 96;

  void _showPopover(BuildContext context, Rect chip, WidgetBuilder builder) {
    widget.chromeController.cancelAutoHide();
    OverlaySheetController.of(context)
        .show(
          style: OverlaySheetStyle.glass,
          anchor: _popoverAnchor(context, chip),
          constraints: const BoxConstraints(maxWidth: 280),
          builder: builder,
        )
        .whenComplete(_startHideTimer);
  }

  void _openSpeedPopover(BuildContext context, TrackControlsState state, Rect chip) {
    _showPopover(context, chip, (_) => PlayerSpeedPopover(player: widget.player, state: state));
  }

  void _openSubtitlePopover(BuildContext context, TrackControlsState state, Rect chip) {
    _showPopover(
      context,
      chip,
      (_) => SizedBox(
        width: 280,
        child: EmbeddedVideoControlSheet(
          child: TrackSheet(player: widget.player, trackControlsState: state, only: TrackSheetKind.subtitles),
        ),
      ),
    );
  }

  void _openEpisodesPopover(BuildContext context, Rect chip) {
    final playback = context.read<PlaybackStateProvider>();
    if (playback.isQueueActive && widget.canNavigateMediaItems) {
      _showPopover(
        context,
        chip,
        (_) => PlayerEpisodesPopover(onSelected: _onQueueItemSelected, current: widget.metadata),
      );
      return;
    }
    // Movies with chapters: the chapter list stands in for episodes.
    _showPopover(
      context,
      chip,
      (_) => SizedBox(
        width: 280,
        child: EmbeddedVideoControlSheet(
          child: ChapterSheet(
            player: widget.player,
            chapters: _chapters,
            chaptersLoaded: _chaptersLoaded,
            canControl: widget.canControl,
            serverId: widget.metadata.serverId,
            onSeekRequested: widget.onSeekRequested,
            onSeekCompleted: widget.onSeekCompleted,
          ),
        ),
      ),
    );
  }

  void _openPlayerDrawer(BuildContext context, TrackControlsState state, PlayerDrawerTab tab) {
    widget.chromeController.cancelAutoHide();
    OverlaySheetController.of(context)
        .show(
          style: OverlaySheetStyle.glass,
          blurSigma: 28,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xc716171b)
              : const Color(0xd1f6f6f8),
          alignment: Alignment.centerRight,
          constraints: BoxConstraints(
            maxWidth: PlayerSettingsDrawer.widthFor(context),
            maxHeight: MediaQuery.sizeOf(context).height - 20,
          ),
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
          alignment: Alignment.centerRight,
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
