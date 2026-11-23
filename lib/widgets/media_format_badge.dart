import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../utils/media_quality_labels.dart';
import 'app_icon.dart';

class MediaFormatBadge extends StatelessWidget {
  const MediaFormatBadge(this.format, {super.key, this.onArtwork = false, this.compact = false, this.scale = 1});

  final MediaFormat format;
  final bool onArtwork;
  final bool compact;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = onArtwork ? Colors.white : colors.onSurface;
    final icon = switch (format) {
      MediaFormat.dolbyVision => Symbols.movie_filter_rounded,
      MediaFormat.hdr || MediaFormat.hdr10 || MediaFormat.hlg => Symbols.hdr_on_rounded,
      MediaFormat.hdr10Plus => Symbols.hdr_plus_rounded,
      MediaFormat.dolbyAtmos => Symbols.spatial_audio_rounded,
      MediaFormat.dolbyAudio || MediaFormat.dtsX => Symbols.surround_sound_rounded,
    };
    final label = !compact
        ? format.label
        : switch (format) {
            MediaFormat.dolbyVision => 'DV',
            MediaFormat.dolbyAtmos => 'Atmos',
            MediaFormat.dolbyAudio => 'Dolby',
            _ => format.label,
          };
    return Semantics(
      label: format.label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onArtwork ? const Color(0xBF000000) : colors.onSurface.withValues(alpha: .08),
          border: Border.all(color: foreground.withValues(alpha: .22)),
          borderRadius: BorderRadius.circular((compact ? 4 : 7) * scale),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: (compact ? 4 : 6) * scale, vertical: 2 * scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 3 * scale,
            children: [
              AppIcon(icon, color: foreground, size: (compact ? 11 : 14) * scale),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: (compact ? 9 : 11) * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
