import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../i18n/strings.g.dart';
import '../../../mpv/mpv.dart';
import '../../../utils/formatters.dart';
import '../../../utils/track_label_builder.dart';
import '../../../watch_together/providers/watch_together_provider.dart';
import '../../app_icon.dart';

/// Current player values inside the same fading HUD as the timeline.
///
/// Without callbacks this is informational (desktop). With callbacks it is the
/// mobile chip row: speed, a short subtitle chip, then [trailing] chips. Each
/// chip reports its global rect so a popover can open above it.
class PlayerTrackSummary extends StatelessWidget {
  const PlayerTrackSummary({
    super.key,
    required this.player,
    this.isLive = false,
    this.onSpeedTap,
    this.onSubtitleTap,
    this.trailing = const [],
  });

  final Player player;
  final bool isLive;
  final ValueChanged<Rect>? onSpeedTap;
  final ValueChanged<Rect>? onSubtitleTap;
  final List<Widget> trailing;

  bool get _interactive => onSpeedTap != null || onSubtitleTap != null || trailing.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final roomRate = context.select<WatchTogetherProvider?, double?>(
      (session) => session?.syncOwnsRate == true ? session!.roomRate : null,
    );
    return StreamBuilder<Tracks>(
      stream: player.streams.tracks,
      initialData: player.state.tracks,
      builder: (context, tracksSnapshot) => StreamBuilder<TrackSelection>(
        stream: player.streams.track,
        initialData: player.state.track,
        builder: (context, selectionSnapshot) => StreamBuilder<double>(
          stream: player.streams.rate,
          initialData: player.state.rate,
          builder: (context, rateSnapshot) {
            final tracks = tracksSnapshot.data ?? player.state.tracks;
            final selection = selectionSnapshot.data ?? player.state.track;
            final audio = selection.audio;
            final subtitle = selection.subtitle;
            final hasSubtitles =
                tracks.subtitle.any((track) => track.id != SubtitleTrack.off.id && track.id != SubtitleTrack.auto.id) ||
                (subtitle != null && subtitle.id != SubtitleTrack.off.id && subtitle.id != SubtitleTrack.auto.id);
            final subtitleOff = subtitle == null || subtitle.id == SubtitleTrack.off.id;
            final rateLabel = formatPlaybackRate(roomRate ?? rateSnapshot.data ?? 1);
            if (_interactive) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isLive)
                    PlayerChip(
                      label: rateLabel,
                      semanticLabel: t.videoSettings.playbackSpeed,
                      onTapWithRect: onSpeedTap,
                    ),
                  if (onSubtitleTap != null)
                    PlayerChip(
                      icon: Symbols.closed_caption_rounded,
                      // Language only: the popover shows codec and source.
                      label: !hasSubtitles || subtitleOff
                          ? t.common.off
                          : _shortSubtitleName(subtitle.title) ??
                                resolveTrackLanguageDisplay(language: subtitle.language) ??
                                TrackLabelBuilder.subtitleLabel(
                                  title: subtitle.title,
                                  language: subtitle.language,
                                  codec: subtitle.codec,
                                  forced: subtitle.isForced,
                                  index: tracks.subtitle.indexWhere((track) => track.id == subtitle.id).clamp(0, 999),
                                ).primary,
                      semanticLabel: t.videoControls.subtitlesLabel,
                      onTapWithRect: onSubtitleTap,
                    ),
                  ...trailing,
                ],
              );
            }
            final values = <Widget>[];
            if (audio != null && audio.id != AudioTrack.off.id && audio.id != AudioTrack.auto.id) {
              values.add(
                _value(
                  Symbols.audiotrack_rounded,
                  TrackLabelBuilder.audioLabel(
                    title: audio.title,
                    language: audio.language,
                    codec: audio.codec,
                    codecProfile: audio.codecProfile,
                    channels: audio.channelsCount,
                    index: tracks.audio.indexWhere((track) => track.id == audio.id).clamp(0, 999),
                  ).joined,
                ),
              );
            }
            if (hasSubtitles) {
              values.add(
                _value(
                  Symbols.subtitles_rounded,
                  subtitleOff
                      ? t.common.off
                      : TrackLabelBuilder.subtitleLabel(
                          title: subtitle.title,
                          language: subtitle.language,
                          codec: subtitle.codec,
                          forced: subtitle.isForced,
                          index: tracks.subtitle.indexWhere((track) => track.id == subtitle.id).clamp(0, 999),
                        ).joined,
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  for (final value in values) Expanded(child: value),
                  if (!isLive) _value(Symbols.speed_rounded, rateLabel),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// A track title short enough for the chip ("简体中文", "English SDH");
  /// release-style titles and long descriptions fall back to the language.
  static String? _shortSubtitleName(String? title) {
    final text = cleanTrackMetadataValue(title);
    if (text == null || text.isEmpty || text.length > 10) return null;
    return text;
  }

  Widget _value(IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

/// Pill used in the mobile player's bottom row: a faint fill over the
/// gradient, no border. [onTapWithRect] receives the chip's global rect.
class PlayerChip extends StatelessWidget {
  const PlayerChip({super.key, required this.label, this.icon, this.semanticLabel, this.onTapWithRect});

  final String label;
  final IconData? icon;
  final String? semanticLabel;
  final ValueChanged<Rect>? onTapWithRect;

  @override
  Widget build(BuildContext context) {
    final onTapWithRect = this.onTapWithRect;
    final enabled = onTapWithRect != null;
    final color = enabled ? Colors.white : Colors.white60;
    void tap() {
      final box = context.findRenderObject() as RenderBox?;
      if (onTapWithRect == null || box == null || !box.hasSize) return;
      onTapWithRect(box.localToGlobal(Offset.zero) & box.size);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Semantics(
        button: enabled,
        label: semanticLabel == null ? label : '$semanticLabel, $label',
        excludeSemantics: true,
        onTap: enabled ? tap : null,
        child: Material(
          color: Colors.white.withValues(alpha: .1),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? tap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 28, maxWidth: 140),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[AppIcon(icon, size: 15, color: color), const SizedBox(width: 4)],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
