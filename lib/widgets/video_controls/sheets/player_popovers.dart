import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../i18n/strings.g.dart';
import '../../../media/media_item.dart';
import '../../../mpv/mpv.dart';
import '../../../providers/playback_state_provider.dart';
import '../../../services/scoped_player_prefs.dart';
import '../../../utils/episode_titles.dart';
import '../../../utils/formatters.dart';
import '../../app_icon.dart';
import '../../focusable_list_tile.dart';
import '../../overlay_sheet.dart';
import '../models/track_controls_state.dart';

/// Rates offered by the speed chip. The full list stays in the settings sheet.
const playerPopoverSpeeds = <double>[2.0, 1.5, 1.25, 1.0, 0.75, 0.5];

/// One row of a player popover: label, optional trailing detail, and a check
/// mark with a soft fill when selected.
class PlayerPopoverRow extends StatelessWidget {
  const PlayerPopoverRow({
    super.key,
    required this.label,
    required this.onTap,
    this.detail,
    this.selected = false,
    this.autofocus = false,
  });

  final String label;
  final String? detail;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = GlassSheetColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? glass.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: FocusableListTile(
          autofocus: autofocus,
          selected: selected,
          dense: true,
          visualDensity: const VisualDensity(vertical: -4),
          contentPadding: const EdgeInsets.only(left: 8, right: 14),
          leading: SizedBox(
            width: 18,
            child: selected ? AppIcon(Symbols.check_rounded, size: 16, color: glass.foreground) : null,
          ),
          minLeadingWidth: 18,
          horizontalTitleGap: 6,
          title: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: glass.foreground,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          trailing: detail == null ? null : Text(detail!, style: TextStyle(color: glass.muted, fontSize: 11)),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Speed chip popover: one column, current rate checked.
class PlayerSpeedPopover extends StatelessWidget {
  const PlayerSpeedPopover({super.key, required this.player, required this.state});

  final Player player;
  final TrackControlsState state;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.streams.rate,
      initialData: player.state.rate,
      builder: (context, snapshot) {
        final current = snapshot.data ?? 1.0;
        final nearest = playerPopoverSpeeds.reduce((a, b) => (a - current).abs() <= (b - current).abs() ? a : b);
        return SizedBox(
          width: 132,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(5),
            children: [
              for (final rate in playerPopoverSpeeds)
                PlayerPopoverRow(
                  label: formatPlaybackRate(rate),
                  selected: rate == nearest && (rate - current).abs() < 0.01,
                  autofocus: rate == nearest,
                  onTap: () async {
                    await (state.onRateRequested ?? player.setRate)(rate);
                    await ScopedPlayerPrefs.write(ScopedPlayerPrefs.playbackSpeed, state.metadata, rate);
                    if (context.mounted) OverlaySheetController.of(context).close();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Episode chip popover: queue items as "episode N + title", current one
/// checked. File-name titles are already cleaned by [MediaItem.displayTitle].
class PlayerEpisodesPopover extends StatelessWidget {
  const PlayerEpisodesPopover({super.key, required this.onSelected, this.current});

  /// The item on screen; marks its row even when the queue holds a copy.
  final MediaItem? current;

  static const _rowExtent = 38.0;

  final ValueChanged<MediaItem> onSelected;

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackStateProvider>();
    final items = playback.loadedItems;
    final currentId = playback.currentPlayQueueItemID;
    // The player's item is a separately fetched copy, so prefer its identity.
    final playingKey = current?.globalKey;
    var currentIndex = playingKey == null ? -1 : items.indexWhere((item) => item.globalKey == playingKey);
    if (currentIndex < 0) currentIndex = items.indexWhere((item) => playback.playQueueItemIdFor(item) == currentId);
    return SizedBox(
      width: 260,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(18),
              child: Text(t.videoControls.noQueueItems, style: TextStyle(color: GlassSheetColors.of(context).muted)),
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(5),
              // Open on the playing episode, one row of context above it.
              itemExtent: _rowExtent,
              controller: ScrollController(
                initialScrollOffset: currentIndex <= 0 ? 0 : (currentIndex - 1) * _rowExtent,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return PlayerPopoverRow(
                  label: episodePopoverLabel(item),
                  detail: item.durationMs == null ? null : formatDurationTextual(item.durationMs!),
                  selected: index == currentIndex,
                  autofocus: index == currentIndex,
                  onTap: () {
                    OverlaySheetController.of(context).close();
                    if (index != currentIndex) onSelected(item);
                  },
                );
              },
            ),
    );
  }
}

/// "第 7 集 · 新的旅程"; the bare number when the server title is a release
/// file name, and the title alone when there is no number.
String episodePopoverLabel(MediaItem item) {
  final number = effectiveEpisodeIndex(item);
  final title = item.title?.trim();
  if (number == null) return (title == null || title.isEmpty) ? t.common.unknown : title;
  final numbered = t.videoControls.episodeNumber(n: number);
  if (title == null || title.isEmpty || looksLikeReleaseFileName(title)) return numbered;
  return '$numbered · $title';
}
