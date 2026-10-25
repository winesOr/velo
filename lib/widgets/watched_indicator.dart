import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../media/media_item.dart';
import '../media/media_item_types.dart';
import '../media/media_kind.dart';
import '../services/settings_service.dart';
import '../theme/mono_tokens.dart';
import '../utils/formatters.dart';
import 'app_icon.dart';
import 'media_progress_bar.dart';
import 'unwatched_count_badge.dart';

/// Size preset for [WatchedIndicator]: [standard] for grid/poster cards,
/// [compact] for dense surfaces (folder tree rows, episode thumbnails).
/// Add a preset here instead of hand-rolling a new overlay variant.
enum WatchedIndicatorSize {
  standard(
    checkInset: 4,
    checkPadding: 4,
    checkIconSize: 16,
    badgeSize: 24,
    badgeFontSize: 12,
    barRadius: 8,
    barMinHeight: 4,
  ),
  compact(
    checkInset: 3,
    checkPadding: 2,
    checkIconSize: 12,
    badgeSize: 20,
    badgeFontSize: 10,
    barRadius: 6,
    barMinHeight: 3,
  );

  const WatchedIndicatorSize({
    required this.checkInset,
    required this.checkPadding,
    required this.checkIconSize,
    required this.badgeSize,
    required this.badgeFontSize,
    required this.barRadius,
    required this.barMinHeight,
  });

  final double checkInset;
  final double checkPadding;
  final double checkIconSize;
  final double badgeSize;
  final double badgeFontSize;
  final double barRadius;
  final double barMinHeight;
}

/// Watched/progress overlay for media artwork: watched checkmark,
/// unwatched-count pill (shows/seasons), active-progress bar, and season
/// completion bar. The single implementation behind every surface that
/// stamps watch state onto a poster/thumbnail. Callers that must react to
/// [SettingsService.showWatchedIndicators] or [SettingsService.showUnwatchedCount]
/// flipping wrap themselves in a [SettingsBuilder] on those prefs.
class WatchedIndicator extends StatelessWidget {
  final MediaItem item;
  final WatchedIndicatorSize size;

  /// Overrides the settings read for the unwatched-count pill — pass it when
  /// the caller already watches [SettingsService.showUnwatchedCount] so pill
  /// visibility updates reactively with the caller's rebuilds.
  final bool? showUnwatchedCount;

  /// Continue Watching uses inset white progress, timestamps and a play ring.
  /// Decorative only: the containing media card retains tap and D-pad actions.
  final bool showResumeDetails;
  final bool showProgress;

  const WatchedIndicator({
    super.key,
    required this.item,
    this.size = WatchedIndicatorSize.standard,
    this.showUnwatchedCount,
    this.showResumeDetails = false,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool showCount = showUnwatchedCount ?? SettingsService.instance.read(SettingsService.showUnwatchedCount);
    final bool showWatched = SettingsService.instance.read(SettingsService.showWatchedIndicators);
    final hasActiveProgress = item.hasActiveProgress;
    final resumeDetails = showResumeDetails && (item.isMovie || item.isEpisode);
    final unwatched = item.unwatchedCount;
    final barRadius = BorderRadius.only(
      bottomLeft: Radius.circular(size.barRadius),
      bottomRight: Radius.circular(size.barRadius),
    );

    return Stack(
      children: [
        // Watched checkmark
        if (showWatched && item.isWatched && !hasActiveProgress)
          Positioned(
            top: size.checkInset,
            right: size.checkInset,
            child: Container(
              padding: EdgeInsets.all(size.checkPadding),
              decoration: BoxDecoration(
                color: tokens(context).text,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
              ),
              child: AppIcon(Symbols.check_rounded, fill: 1, color: tokens(context).bg, size: size.checkIconSize),
            ),
          ),
        // Unwatched count for shows/seasons
        if (showCount &&
            !item.isWatched &&
            (item.kind == MediaKind.show || item.kind == MediaKind.season) &&
            unwatched != null &&
            unwatched > 0)
          Positioned(
            top: size.checkInset,
            right: size.checkInset,
            child: UnwatchedCountBadge(count: unwatched, size: size.badgeSize, fontSize: size.badgeFontSize),
          ),
        // Progress bar for partially watched content (episodes/movies)
        if (showProgress && resumeDetails) Positioned.fill(child: _ResumeDetails(item: item)),
        if (showProgress && hasActiveProgress && !resumeDetails)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: barRadius,
              child: MediaProgressBar(
                viewOffset: item.viewOffsetMs!,
                duration: item.durationMs!,
                minHeight: size.barMinHeight,
              ),
            ),
          ),
        // Progress bar for seasons (viewed leaves / total leaves).
        if (showProgress && item.isSeason && item.isPartiallyWatched)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: barRadius,
              child: LinearProgressIndicator(
                value: item.leafWatchFraction,
                backgroundColor: tokens(context).outline,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                minHeight: size.barMinHeight,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResumeDetails extends StatelessWidget {
  const _ResumeDetails({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final duration = item.durationMs;
    final hasDuration = duration != null && duration > 0;
    final position = hasDuration ? (item.viewOffsetMs ?? 0).clamp(0, duration) : 0;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (constraints.maxWidth / 218).clamp(.8, 1.3);
          final inset = 12 * scale;
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [.45, 1],
                    colors: [Colors.transparent, Color(0x80000000)],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 40 * scale,
                  height: 40 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2 * scale),
                    boxShadow: const [BoxShadow(color: Color(0x20000000), blurRadius: 6)],
                  ),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(left: 2 * scale),
                      child: AppIcon(Symbols.play_arrow_rounded, fill: 1, color: Colors.white, size: 30 * scale),
                    ),
                  ),
                ),
              ),
              if (hasDuration) ...[
                Positioned(
                  left: inset,
                  right: inset,
                  bottom: 20 * scale,
                  child: Align(
                    alignment: Alignment.centerRight,
                    heightFactor: 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${formatDurationTimestamp(Duration(milliseconds: position))} / '
                        '${formatDurationTimestamp(Duration(milliseconds: duration))}',
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11 * scale,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          letterSpacing: .3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: inset,
                  right: inset,
                  bottom: 10 * scale,
                  child: LinearProgressIndicator(
                    value: position / duration,
                    minHeight: 4 * scale,
                    borderRadius: BorderRadius.circular(2 * scale),
                    backgroundColor: const Color(0x60FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    trackGap: 0,
                    stopIndicatorRadius: 0,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
