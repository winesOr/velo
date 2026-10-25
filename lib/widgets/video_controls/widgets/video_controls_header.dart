import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plezy/utils/formatters.dart';

import '../../../media/media_item.dart';
import '../../../media/media_backend.dart';
import '../../../i18n/strings.g.dart';
import '../../../utils/episode_titles.dart';
import '../../../utils/provider_extensions.dart';
import '../../optimized_media_image.dart';
import '../../../watch_together/widgets/watch_together_overlay.dart';
import '../../../watch_together/providers/watch_together_provider.dart';
import '../../app_bar_back_button.dart';
import '../../system_clock.dart';

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

  /// Optional trailing widget (e.g., track/chapter controls)
  final Widget? trailing;
  final bool trailingOnSeparateRow;

  /// Optional callback for back button. If null, defaults to Navigator.pop(true).
  final VoidCallback? onBack;
  final VoidCallback? onCancelAutoHide;
  final VoidCallback? onStartAutoHide;

  /// Whether to show the system clock. Off for a portrait phone, where the
  /// header is too narrow to fit the clock beside the title and trailing
  /// controls.
  final bool showClock;

  const VideoControlsHeader({
    super.key,
    required this.metadata,
    this.style = VideoHeaderStyle.multiLine,
    this.trailing,
    this.trailingOnSeparateRow = false,
    this.onBack,
    this.onCancelAutoHide,
    this.onStartAutoHide,
    this.showClock = true,
  });

  @override
  Widget build(BuildContext context) {
    final itemTitle = metadata.title ?? t.common.unknown;
    final header = Row(
      children: [
        AppBarBackButton(style: BackButtonStyle.video, onPressed: onBack ?? () => Navigator.of(context).pop(true)),
        const SizedBox(width: 16),
        Expanded(child: _buildTitle(context, itemTitle)),
        Selector<WatchTogetherProvider, bool>(
          selector: (_, p) => p.isInSession,
          builder: (context, inSession, child) {
            if (!inSession) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: WatchTogetherSessionIndicator(
                onCancelAutoHide: onCancelAutoHide,
                onStartAutoHide: onStartAutoHide,
              ),
            );
          },
        ),
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
        Align(alignment: Alignment.centerRight, child: trailing),
      ],
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

  /// "第 12 集 · 提供八字能取前世财" for an episode. A release file name is
  /// dropped (the number says it all); no episode number means no line.
  String? _episodeLine(String itemTitle) {
    final episode = effectiveEpisodeIndex(metadata);
    if (episode == null) return null;
    final parts = <String>[
      if (metadata.parentIndex != null && metadata.parentIndex! > 1)
        t.videoControls.seasonNumber(n: metadata.parentIndex!),
      t.videoControls.episodeNumber(n: episode),
      if (!looksLikeReleaseFileName(itemTitle) && itemTitle != metadata.grandparentTitle) itemTitle,
    ];
    return parts.join(' · ');
  }

  Widget _episodeText(String line) => Text(
    line,
    style: const TextStyle(color: Colors.white70, fontSize: 13),
    maxLines: 1,
    overflow: .ellipsis,
  );

  Widget _buildSeriesName(String itemTitle) => Text(
    metadata.grandparentTitle ?? itemTitle,
    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: .bold),
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
