import 'package:material_symbols_icons/symbols.dart';

import '../../../focus/focus_theme.dart';
import '../../../focus/focusable_wrapper.dart';
import '../video_control_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plezy/utils/formatters.dart';

import '../../../media/media_item.dart';
import '../../../media/media_backend.dart';
import '../../../i18n/strings.g.dart';
import '../../../mpv/mpv.dart';
import '../../../utils/episode_titles.dart';
import '../../../utils/provider_extensions.dart';
import '../../optimized_media_image.dart';
import '../../app_icon.dart';
import '../../../watch_together/widgets/watch_together_overlay.dart';
import '../../../watch_together/providers/watch_together_provider.dart';
import '../../app_bar_back_button.dart';
import '../../system_clock.dart';
import '../../press_feedback.dart';
import 'dolby_playback_indicator.dart';
import 'first_frame_guard.dart';

/// Header layout style for video controls
enum VideoHeaderStyle {
  /// Multi-line: Series name on first line, episode info on second line
  multiLine,

  /// Single-line: All info combined with separators (for macOS)
  singleLine,
}

String? playerLogoPath(MediaItem metadata) {
  final path = metadata.clearLogoPath;
  if (path == null || path.isEmpty || metadata.backend == MediaBackend.plex) return path;
  final uri = Uri.tryParse(path);
  if (uri == null) return null;
  final query = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((key, _) => {'maxheight', 'height', 'quality'}.contains(key.toLowerCase()))
    ..addAll({'maxHeight': '720', 'quality': '90'});
  return uri.replace(queryParameters: query).toString();
}

/// Shared header widget for video controls with back button and title.
///
/// Displays the video title with optional series/episode information.
/// Supports both single-line (macOS) and multi-line (other platforms) layouts.
class VideoControlsHeader extends StatelessWidget {
  final MediaItem metadata;
  final VideoHeaderStyle style;
  final Player? player;
  final ValueNotifier<bool>? hasFirstFrame;

  /// Optional trailing widget (e.g., track/chapter controls)
  final Widget? trailing;
  final bool trailingOnSeparateRow;
  final bool mobileLayout;

  /// Optional callback for back button. If null, defaults to Navigator.pop(true).
  final VoidCallback? onBack;
  final VoidCallback? onCancelAutoHide;
  final VoidCallback? onStartAutoHide;

  /// Whether to show the system clock. Off for a portrait phone, where the
  /// header is too narrow to fit the clock beside the title and trailing
  /// controls.
  final bool showClock;
  final List<FocusNode>? tvFocusNodes;
  final KeyEventResult Function(FocusNode, KeyEvent)? onTvKeyEvent;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback? onToggleDanmaku;
  final bool danmakuEnabled;
  final VoidCallback? onMore;

  const VideoControlsHeader({
    super.key,
    required this.metadata,
    this.style = VideoHeaderStyle.multiLine,
    this.player,
    this.hasFirstFrame,
    this.trailing,
    this.trailingOnSeparateRow = false,
    this.mobileLayout = false,
    this.onBack,
    this.onCancelAutoHide,
    this.onStartAutoHide,
    this.showClock = true,
    this.tvFocusNodes,
    this.onTvKeyEvent,
    this.onFocusChange,
    this.onToggleDanmaku,
    this.danmakuEnabled = false,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final itemTitle = metadata.title ?? t.common.unknown;
    if (tvFocusNodes != null) return _buildTvHeader(context, itemTitle);
    final header = Row(
      children: [
        AppBarBackButton(style: BackButtonStyle.video, onPressed: onBack ?? () => Navigator.of(context).pop(true)),
        const SizedBox(width: 16),
        Expanded(child: _withDolbyIndicator(_buildTitle(context, itemTitle))),
        if (!trailingOnSeparateRow) _sessionIndicator(),
        if (showClock)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SystemClock(
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: .w500),
            ),
          ),
        if (!trailingOnSeparateRow) ?trailing,
      ],
    );
    if (!trailingOnSeparateRow || trailing == null) return header;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(child: _sessionIndicator()),
            trailing!,
          ],
        ),
      ],
    );
  }

  Widget _sessionIndicator() => Selector<WatchTogetherProvider, bool>(
    selector: (_, provider) => provider.isInSession,
    builder: (context, inSession, _) => inSession
        ? Padding(
            padding: const EdgeInsets.only(right: 8),
            child: WatchTogetherSessionIndicator(onCancelAutoHide: onCancelAutoHide, onStartAutoHide: onStartAutoHide),
          )
        : const SizedBox.shrink(),
  );

  Widget _buildTvHeader(BuildContext context, String itemTitle) {
    final scale = FocusTheme.tvPlayerScale(context);
    Widget button(int index, IconData icon, String label, VoidCallback? action, {bool? checked}) => DecoratedBox(
      decoration: BoxDecoration(
        color: checked == null ? Colors.white.withValues(alpha: .14) : Colors.transparent,
        borderRadius: BorderRadius.circular(22 * scale),
      ),
      child: VideoControlButton(
        icon: icon,
        tooltip: label,
        onPressed: action,
        checked: checked,
        overlayGlyph: checked != null,
        isActive: checked ?? false,
        focusNode: tvFocusNodes![index],
        onKeyEvent: onTvKeyEvent,
        onFocusChange: onFocusChange,
      ),
    );
    final episode = effectiveEpisodeIndex(metadata);
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        button(0, Symbols.arrow_back_rounded, t.common.back, onBack ?? () => Navigator.of(context).pop(true)),
        SizedBox(width: 16 * scale),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metadata.grandparentTitle ?? itemTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 24 * scale, fontWeight: FontWeight.w600),
              ),
              if (episode != null)
                Text(
                  [
                        if (metadata.parentIndex != null) t.videoControls.seasonNumber(n: metadata.parentIndex!),
                        t.videoControls.episodeNumber(n: episode),
                      ].join(' · ') +
                      (!looksLikeReleaseFileName(itemTitle) && itemTitle != metadata.grandparentTitle
                          ? '  $itemTitle'
                          : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, fontSize: 14 * scale),
                ),
              _buildDolbyIndicator(),
            ],
          ),
        ),
        button(1, Symbols.subtitles_rounded, t.videoControls.danmakuToggle, onToggleDanmaku, checked: danmakuEnabled),
        SizedBox(width: 8 * scale),
        Consumer<WatchTogetherProvider>(
          builder: (context, provider, _) {
            void openDrawer() {
              onCancelAutoHide?.call();
              showWatchTogetherPlayerDrawer(context).whenComplete(() => onStartAutoHide?.call());
            }

            final label = provider.isInSession
                ? '${t.watchTogether.title} · ${provider.participantCount}'
                : t.watchTogether.title;
            return FocusableWrapper(
              focusNode: tvFocusNodes![2],
              onSelect: openDrawer,
              onKeyEvent: onTvKeyEvent,
              onFocusChange: onFocusChange,
              semanticLabel: t.watchTogether.title,
              semanticValue: provider.isInSession
                  ? '${t.watchTogether.participants}: ${provider.participantCount}'
                  : null,
              descendantsAreFocusable: false,
              autoScroll: false,
              borderRadius: 22 * scale,
              useBackgroundFocus: true,
              child: Material(
                color: const Color(0x4D6FD6CF),
                borderRadius: BorderRadius.circular(22 * scale),
                child: PressFeedbackInkWell(
                  onTap: openDrawer,
                  canRequestFocus: false,
                  borderRadius: BorderRadius.circular(22 * scale),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                    child: SizedBox(
                      height: 44 * scale,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(Symbols.group_rounded, color: Colors.white, size: 18 * scale),
                          SizedBox(width: 6 * scale),
                          Text(
                            label,
                            style: TextStyle(color: Colors.white, fontSize: 14 * scale, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        SizedBox(width: 8 * scale),
        button(3, Symbols.more_horiz_rounded, t.videoControls.moreButton, onMore),
      ],
    );
  }

  Widget _withDolbyIndicator(Widget title) {
    if (player == null) return title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, _buildDolbyIndicator()],
    );
  }

  Widget _buildDolbyIndicator() {
    final playback = player;
    if (playback == null) return const SizedBox.shrink();
    return FirstFrameGuard(
      hasFirstFrame: hasFirstFrame,
      builder: (_) => DolbyPlaybackIndicator(key: ValueKey((playback, metadata.globalKey)), player: playback),
    );
  }

  Widget _buildTitle(BuildContext context, String itemTitle) {
    Widget fallback(BuildContext _) =>
        style == VideoHeaderStyle.singleLine ? _buildSingleLineTitle(itemTitle) : _buildMultiLineTitle(itemTitle);
    final path = playerLogoPath(metadata);
    if (path == null || path.isEmpty) return fallback(context);
    final episodeLine = _episodeLine(itemTitle);
    final logo = LayoutBuilder(
      builder: (context, constraints) => Semantics(
        label: metadata.grandparentTitle ?? itemTitle,
        child: ClearLogoImage(
          client: context.getMediaClientForItemOrNull(metadata),
          logoPath: path,
          width: constraints.maxWidth.clamp(0.0, 240.0),
          height: MediaQuery.textScalerOf(context).scale(48),
          fallbackWidth: constraints.maxWidth,
          // The fallback already carries the episode line.
          fallbackBuilder: (context) =>
              style == VideoHeaderStyle.singleLine ? _buildSingleLineTitle(itemTitle) : _buildSeriesName(itemTitle),
        ),
      ),
    );
    if (style == VideoHeaderStyle.singleLine || episodeLine == null) return logo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [logo, const SizedBox(height: 4), _episodeText(episodeLine)],
    );
  }

  String? _episodeLine(String itemTitle) {
    final episode = effectiveEpisodeIndex(metadata);
    if (episode == null) return null;
    if (!mobileLayout) {
      return [
        if (metadata.parentIndex != null && metadata.parentIndex! > 1)
          t.videoControls.seasonNumber(n: metadata.parentIndex!),
        t.videoControls.episodeNumber(n: episode),
        if (!looksLikeReleaseFileName(itemTitle) && itemTitle != metadata.grandparentTitle) itemTitle,
      ].join(' · ');
    }
    final number = metadata.parentIndex == null
        ? t.videoControls.episodeShort(n: episode)
        : t.videoControls.seasonEpisodeShort(season: metadata.parentIndex!, episode: episode);
    return '$number${!looksLikeReleaseFileName(itemTitle) && itemTitle != metadata.grandparentTitle ? '  $itemTitle' : ''}';
  }

  Widget _episodeText(String line) => Text(
    line,
    style: TextStyle(color: Colors.white70, fontSize: mobileLayout ? 11 : 13),
    maxLines: 1,
    overflow: .ellipsis,
  );

  Widget _buildSeriesName(String itemTitle) => Text(
    metadata.grandparentTitle ?? itemTitle,
    style: TextStyle(color: Colors.white, fontSize: mobileLayout ? 22 : 16, fontWeight: .bold),
    maxLines: 1,
    overflow: .ellipsis,
  );

  Widget _buildSingleLineTitle(String itemTitle) {
    final seriesName = metadata.grandparentTitle ?? itemTitle;
    final episode = effectiveEpisodeIndex(metadata);
    final hasEpisodeInfo = metadata.parentIndex != null && episode != null;

    final List<String> parts = [seriesName];

    if (hasEpisodeInfo) {
      parts.add('S${metadata.parentIndex}E$episode');
      if (!looksLikeReleaseFileName(itemTitle)) parts.add(itemTitle);
    }

    return Text(
      toBulletedString(parts),
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: .w500),
      maxLines: 1,
      overflow: .ellipsis,
    );
  }

  Widget _buildMultiLineTitle(String itemTitle) {
    final line = _episodeLine(itemTitle);
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: MainAxisSize.min,
      children: [_buildSeriesName(itemTitle), if (line != null) _episodeText(line)],
    );
  }
}
