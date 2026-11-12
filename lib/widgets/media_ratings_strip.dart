import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../i18n/strings.g.dart';
import '../media/media_item.dart';
import '../media/media_rating.dart';
import '../utils/rating_display_policy.dart';
import '../utils/rating_utils.dart';
import 'app_icon.dart';
import 'media_rating_badge.dart';
import 'settings_builder.dart';

/// A reserved external-score region, independent of metadata's fitting budget.
/// Empty data collapses entirely; adding sources keeps the existing slot geometry.
class MediaRatingsStrip extends StatelessWidget {
  const MediaRatingsStrip({
    super.key,
    required this.item,
    this.fallbackItem,
    this.foregroundColor,
    this.alignment = WrapAlignment.center,
    this.maxRatings = RatingDisplayPolicy.detailLimit,
    this.padding = EdgeInsets.zero,
  });

  final MediaItem item;
  final MediaItem? fallbackItem;
  final Color? foregroundColor;
  final WrapAlignment alignment;
  final int maxRatings;
  final EdgeInsetsGeometry padding;

  static int columnsFor(double width, TextScaler scaler, int slots) =>
      math.max(1, math.min(slots, (width / (76 * scaler.scale(1))).floor()));

  static double heightFor(double width, TextScaler scaler, {int slots = RatingDisplayPolicy.detailLimit}) {
    final columns = columnsFor(width, scaler, slots);
    return (slots / columns).ceil() * 78 * scaler.scale(1);
  }

  @override
  Widget build(BuildContext context) => SettingsBuilder(
    prefs: ratingDisplayPrefs,
    builder: (context) {
      final ratings = preferredMediaRatingsFor(item, fallbackItem: fallbackItem, limit: maxRatings);
      if (ratings.isEmpty) return const SizedBox.shrink();
      final foreground = foregroundColor ?? Theme.of(context).colorScheme.onSurface;
      final scaler = MediaQuery.textScalerOf(context);
      return Padding(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth ? constraints.maxWidth : 320.0;
            final columns = columnsFor(width, scaler, maxRatings);
            final cellWidth = width / columns;
            return SizedBox(
              height: heightFor(width, scaler, slots: maxRatings),
              child: Wrap(
                alignment: alignment,
                children: [
                  for (final rating in ratings)
                    SizedBox(
                      width: cellWidth,
                      height: 78 * scaler.scale(1),
                      child: Semantics(
                        label: ratingsSemanticLabel([rating]),
                        excludeSemantics: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                mediaRatingLabel(rating),
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ratingSourceLabel(rating.source) ?? t.settings.otherRatingSources,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: foreground.withValues(alpha: .78), fontSize: 11, height: 1.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

/// One real score on artwork; personal values are explicitly identified as /10.
class MediaCardRatingBadge extends StatelessWidget {
  const MediaCardRatingBadge({super.key, required this.rating});

  final MediaRatingSource rating;

  @override
  Widget build(BuildContext context) {
    final personal = rating.source == 'personal';
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: ratingsSemanticLabel([rating]),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (personal) ...[
              AppIcon(Symbols.person_rounded, size: 12, color: colors.primary),
              const SizedBox(width: 3),
              Text('${mediaRatingLabel(rating)}/10', style: TextStyle(color: colors.onSurface, fontSize: 11)),
            ] else
              InlineRatingBadges(
                ratings: [rating],
                iconSize: 11,
                textStyle: TextStyle(color: colors.onSurface, fontSize: 11, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}
