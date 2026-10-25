import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../media/media_item.dart';
import '../../mpv/mpv.dart';
import '../../models/livetv_capture_buffer.dart';
import '../../media/media_source_info.dart';
import '../../services/scrub_preview_source.dart';
import '../../utils/desktop_window_padding.dart';
import '../../utils/platform_detector.dart';
import '../../i18n/strings.g.dart';
import 'widgets/first_frame_guard.dart';
import 'widgets/play_pause_stream_builder.dart';
import 'widgets/velo_play_pause_icon.dart';
import 'widgets/player_track_summary.dart';
import 'widgets/live_timeline_bar.dart';
import 'widgets/video_controls_header.dart';
import 'widgets/video_timeline_bar.dart';
import 'video_control_button.dart';

/// Mobile video controls (player V4, `design/prototype/player.html`):
/// - Top bar: back, logo title, then danmaku toggle, cast, orientation, more
/// - Right rail: screenshot above PiP
/// - No centre transport: double taps and swipes own the picture
/// - Bottom: timeline, then play/next and the speed / subtitle / episode /
///   danmaku chips
class MobileVideoControls extends StatefulWidget {
  final Player player;
  final MediaItem metadata;
  final List<MediaChapter> chapters;
  final bool chaptersLoaded;
  final List<BufferRange> skipRanges;
  final bool showChapterMarkersOnTimeline;
  final Function(Duration) onSeek;
  final Function(Duration) onSeekEnd;
  final VoidCallback? onScrubStart;
  final VoidCallback? onScrubEnd;
  final Future<void> Function(Duration position)? onSeekRequested;
  final Function(Duration)? onSeekCompleted;
  final VoidCallback onPlayPause;
  final VoidCallback? onCancelAutoHide;
  final VoidCallback? onStartAutoHide;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  /// Whether the user can control playback (false in host-only mode for non-host).
  final bool canControl;

  /// Notifier for whether first video frame has rendered (shows loading state when false).
  final ValueNotifier<bool>? hasFirstFrame;

  /// Optional callback that returns thumbnail image bytes for a given timestamp.
  final ScrubFrame? Function(Duration time)? thumbnailDataBuilder;

  /// Whether this is a live TV stream
  final bool isLive;

  final String? liveChannelName;

  // Live TV time-shift
  final CaptureBuffer? captureBuffer;
  final bool isAtLiveEdge;
  final int Function(Duration position)? liveEpochForPosition;
  final ValueChanged<int>? onLiveSeek;

  /// Returns true when a global touch position belongs to the parent edge-adjustment zone.
  final bool Function(Offset globalPosition)? isInEdgeAdjustmentZone;

  /// Bottom chips. Rect-taking callbacks receive the chip's global rect so the
  /// popover can sit above it.
  final ValueChanged<Rect>? onSpeedTap;
  final ValueChanged<Rect>? onSubtitlesTap;
  final ValueChanged<Rect>? onEpisodesTap;
  final ValueChanged<Rect>? onDanmakuTap;

  /// Top-right actions; a null callback hides its button.
  final VoidCallback? onDanmakuToggle;
  final bool danmakuEnabled;
  final VoidCallback? onCast;
  final VoidCallback? onToggleOrientation;
  final VoidCallback? onMore;

  /// Right rail.
  final VoidCallback? onScreenshot;
  final VoidCallback? onTogglePip;

  const MobileVideoControls({
    super.key,
    required this.player,
    required this.metadata,
    required this.chapters,
    required this.chaptersLoaded,
    this.skipRanges = const [],
    this.showChapterMarkersOnTimeline = true,
    required this.onSeek,
    required this.onSeekEnd,
    this.onScrubStart,
    this.onScrubEnd,
    required this.onPlayPause,
    this.onSeekRequested,
    this.onSeekCompleted,
    this.onCancelAutoHide,
    this.onStartAutoHide,
    this.onBack,
    this.onNext,
    this.canControl = true,
    this.hasFirstFrame,
    this.thumbnailDataBuilder,
    this.isLive = false,
    this.liveChannelName,
    this.captureBuffer,
    this.isAtLiveEdge = true,
    this.liveEpochForPosition,
    this.onLiveSeek,
    this.isInEdgeAdjustmentZone,
    this.onSpeedTap,
    this.onSubtitlesTap,
    this.onEpisodesTap,
    this.onDanmakuTap,
    this.onDanmakuToggle,
    this.danmakuEnabled = false,
    this.onCast,
    this.onToggleOrientation,
    this.onMore,
    this.onScreenshot,
    this.onTogglePip,
  });

  @override
  State<MobileVideoControls> createState() => _MobileVideoControlsState();
}

class _MobileVideoControlsState extends State<MobileVideoControls> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(children: [_buildTopBar(context), const Spacer(), _buildBottomBar(context)]),
        if (widget.onScreenshot != null || widget.onTogglePip != null)
          Positioned(right: 12, top: 0, bottom: 0, child: Center(child: _buildRightRail())),
      ],
    );
  }

  /// Screenshot above PiP, centred on the right edge (VidHub's placement).
  Widget _buildRightRail() {
    return SafeArea(
      left: false,
      top: false,
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onScreenshot != null)
            _RailButton(
              icon: Symbols.photo_camera_rounded,
              label: t.videoControls.screenshotButton,
              onPressed: widget.onScreenshot,
            ),
          if (widget.onScreenshot != null && widget.onTogglePip != null) const SizedBox(height: 10),
          if (widget.onTogglePip != null)
            _RailButton(
              icon: Symbols.picture_in_picture_alt_rounded,
              label: t.videoControls.pipButton,
              onPressed: widget.onTogglePip,
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isPortraitPhone =
        PlatformDetector.isPhone(context) && MediaQuery.orientationOf(context) == Orientation.portrait;
    final topBar = _conditionalSafeArea(
      context: context,
      bottom: false, // Only respect top safe area when in portrait
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
        child: VideoControlsHeader(
          metadata: widget.metadata,
          style: VideoHeaderStyle.multiLine,
          onCancelAutoHide: widget.onCancelAutoHide,
          onStartAutoHide: widget.onStartAutoHide,
          trailing: _buildTopActions(),
          trailingOnSeparateRow: isPortraitPhone,
          onBack: widget.onBack,
          showClock: false,
        ),
      ),
    );

    return DesktopAppBarHelper.wrapWithGestureDetector(topBar, opaque: true);
  }

  /// Danmaku toggle, cast, orientation and "more", right-aligned.
  Widget _buildTopActions() {
    Widget button(IconData icon, String label, VoidCallback? onPressed, {bool active = false}) => VideoControlButton(
      icon: icon,
      semanticLabel: label,
      tooltip: label,
      iconSize: 22,
      isActive: active,
      color: active ? null : Colors.white,
      onPressed: onPressed,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onDanmakuToggle != null)
          button(
            Symbols.subtitles_rounded,
            t.videoControls.danmakuToggle,
            widget.onDanmakuToggle,
            active: widget.danmakuEnabled,
          ),
        if (widget.onCast != null) button(Symbols.cast_rounded, t.videoControls.castButton, widget.onCast),
        if (widget.onToggleOrientation != null)
          button(Symbols.screen_rotation_rounded, t.videoControls.orientationButton, widget.onToggleOrientation),
        if (widget.onMore != null) button(Symbols.more_horiz_rounded, t.videoControls.moreButton, widget.onMore),
      ],
    );
  }

  void _togglePlayback(bool isPlaying) {
    widget.onPlayPause();
    if (isPlaying) {
      widget.onCancelAutoHide?.call();
    } else {
      widget.onStartAutoHide?.call();
    }
  }

  /// Play/pause and next on the left; speed, subtitles, episodes and danmaku
  /// chips on the right. Chips report their own rect so popovers can anchor.
  Widget _buildTransportRow() {
    Widget iconButton(IconData icon, String label, VoidCallback? onPressed) => VideoControlButton(
      icon: icon,
      semanticLabel: label,
      tooltip: label,
      iconSize: 24,
      onPressed: onPressed,
      color: onPressed == null ? Colors.white38 : null,
    );
    return Row(
      children: [
        PlayPauseStreamBuilder(
          player: widget.player,
          builder: (context, isPlaying) => VideoControlButton(
            icon: isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
            iconBuilder: (color) => VeloPlayPauseIcon(isPlaying: isPlaying, color: color),
            semanticLabel: isPlaying ? t.videoControls.pauseButton : t.videoControls.playButton,
            tooltip: isPlaying ? t.videoControls.pauseButton : t.videoControls.playButton,
            onPressed: widget.canControl ? () => _togglePlayback(isPlaying) : null,
            color: widget.canControl ? Colors.white : Colors.white38,
          ),
        ),
        if (widget.onNext != null) iconButton(Symbols.skip_next_rounded, t.videoControls.nextButton, widget.onNext),
        const Spacer(),
        PlayerTrackSummary(
          player: widget.player,
          onSpeedTap: widget.canControl ? widget.onSpeedTap : null,
          onSubtitleTap: widget.onSubtitlesTap,
          trailing: [
            if (widget.onEpisodesTap != null)
              PlayerChip(
                icon: Symbols.format_list_bulleted_rounded,
                label: t.videoControls.episodesButton,
                onTapWithRect: widget.onEpisodesTap,
              ),
            if (widget.onDanmakuTap != null)
              PlayerChip(icon: Symbols.subtitles_rounded, label: t.danmaku.title, onTapWithRect: widget.onDanmakuTap),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext _) {
    if (widget.isLive) {
      if (widget.captureBuffer != null) {
        // Live TV with time-shift: show seekable timeline
        return FirstFrameGuard(
          hasFirstFrame: widget.hasFirstFrame,
          builder: (context) => LiveTimelineBar(
            player: widget.player,
            captureBuffer: widget.captureBuffer!,
            epochForPosition: widget.liveEpochForPosition!,
            isAtLiveEdge: widget.isAtLiveEdge,
            onSeekEnd: widget.onLiveSeek,
            horizontalLayout: false,
            enabled: widget.canControl,
          ),
        );
      }
      // Fallback: static LIVE badge (no capture buffer)
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(color: Colors.red, borderRadius: BorderRadius.all(Radius.circular(4))),
              child: Text(
                t.liveTv.live,
                style: const TextStyle(color: Colors.white, fontWeight: .bold, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return FirstFrameGuard(hasFirstFrame: widget.hasFirstFrame, builder: (context) => _buildBottomBarContent(context));
  }

  Widget _buildBottomBarContent(BuildContext context) {
    return _conditionalSafeArea(
      context: context,
      top: false, // Only respect bottom safe area when in portrait
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VideoTimelineBar(
              skipRanges: widget.skipRanges,
              player: widget.player,
              chapters: widget.chapters,
              chaptersLoaded: widget.chaptersLoaded,
              showChapterMarkersOnTimeline: widget.showChapterMarkersOnTimeline,
              onSeek: widget.onSeek,
              onSeekEnd: widget.onSeekEnd,
              onScrubStart: widget.onScrubStart,
              onScrubEnd: widget.onScrubEnd,
              horizontalLayout: false,
              enabled: widget.canControl,
              showFinishTime: true,
              thumbnailDataBuilder: widget.thumbnailDataBuilder,
            ),
            _buildTransportRow(),
          ],
        ),
      ),
    );
  }

  /// Wraps [child] in a SafeArea: full insets in portrait, horizontal-only in
  /// landscape. The landscape header and timeline must still clear the notch
  /// and rounded corners; only the vertical insets are dropped so the
  /// controls can hug the top/bottom edges over the full-bleed video surface.
  Widget _conditionalSafeArea({
    required BuildContext context,
    required Widget child,
    bool top = true,
    bool bottom = true,
  }) {
    final isPortrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return SafeArea(top: isPortrait && top, bottom: isPortrait && bottom, child: child);
  }
}

/// Round glass button on the player's side rails.
class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 0.8),
      ),
      child: VideoControlButton(icon: icon, semanticLabel: label, tooltip: label, iconSize: 20, onPressed: onPressed),
    );
  }
}
