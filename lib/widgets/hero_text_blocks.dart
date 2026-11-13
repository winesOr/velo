import 'package:flutter/material.dart';

import '../media/media_item.dart';
import '../media/media_item_types.dart';

bool heroHasOriginalTitle(MediaItem item, String displayTitle) {
  final originalTitle = item.originalTitle?.trim();
  return originalTitle != null &&
      originalTitle.isNotEmpty &&
      originalTitle.toLowerCase() != displayTitle.trim().toLowerCase();
}

bool heroHasSummary(MediaItem item, bool hideSpoiler) {
  if (hideSpoiler) {
    return item.isEpisode && item.parentIndex != null && item.index != null;
  }
  return item.summary?.trim().isNotEmpty ?? false;
}

class HeroOriginalTitle extends StatelessWidget {
  const HeroOriginalTitle({
    super.key,
    required this.item,
    required this.displayTitle,
    required this.color,
    this.fontSize = 9,
    this.textAlign = TextAlign.center,
  });

  final MediaItem item;
  final String displayTitle;
  final Color color;
  final double fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    if (!heroHasOriginalTitle(item, displayTitle)) return const SizedBox.shrink();

    return Text(
      item.originalTitle!.trim().toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: const ['Go Noto Current', 'serif'],
        color: color.withValues(alpha: .8),
        fontSize: fontSize,
        height: 1.2,
        letterSpacing: 2.5,
      ),
    );
  }
}

class HeroSummary extends StatelessWidget {
  const HeroSummary({
    super.key,
    required this.item,
    required this.hideSpoiler,
    required this.maxLines,
    required this.fontSize,
    required this.height,
    required this.color,
    this.textAlign = TextAlign.center,
  });

  final MediaItem item;
  final bool hideSpoiler;
  final int maxLines;
  final double fontSize;
  final double height;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    if (!heroHasSummary(item, hideSpoiler)) return const SizedBox.shrink();

    final style = TextStyle(color: color, fontSize: fontSize, height: height);
    if (hideSpoiler) {
      return Text(
        'S${item.parentIndex}, E${item.index}: ${item.title}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      );
    }

    return RichText(
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      text: TextSpan(
        style: style,
        children: [
          if (item.isEpisode && item.parentIndex != null && item.index != null)
            TextSpan(
              text: 'S${item.parentIndex}, E${item.index}: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          TextSpan(text: item.summary),
        ],
      ),
    );
  }
}
