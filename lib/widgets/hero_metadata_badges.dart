import 'package:flutter/material.dart';

import '../media/media_item.dart';
import '../utils/content_utils.dart';
import '../utils/formatters.dart';
import '../utils/media_quality_labels.dart';

/// Compact metadata from the already-loaded catalog row; never fetches details.
class HeroMetadataBadges extends StatelessWidget {
  const HeroMetadataBadges({
    super.key,
    required this.item,
    this.foreground = Colors.white,
    this.alignment = WrapAlignment.center,
    this.fontSize = 12,
  });

  final MediaItem item;
  final Color foreground;
  final WrapAlignment alignment;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final lightInk = foreground.computeLuminance() > .5;
    final genres = item.genres?.map((g) => g.trim()).where((g) => g.isNotEmpty).take(2) ?? const <String>[];
    final labels = <String>{
      if (item.rating != null) '★ ${formatRating(item.rating!)}',
      if (item.year != null) item.year.toString(),
      if (item.contentRating?.trim().isNotEmpty ?? false) formatContentRating(item.contentRating!),
      ...buildMediaQualityLabels(item),
      ...genres,
    };
    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (lightInk ? Colors.black : Colors.white).withValues(alpha: .2),
              border: Border.all(color: foreground.withValues(alpha: .16), width: .6),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: label.startsWith('★')
                    ? (lightInk ? const Color(0xffffd58a) : const Color(0xff94681f))
                    : foreground.withValues(alpha: .9),
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                height: 1.2,
                letterSpacing: .15,
              ),
            ),
          ),
      ],
    );
  }
}
