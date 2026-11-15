import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../media/media_item.dart';
import '../media/media_rating.dart';
import '../utils/rating_display_policy.dart';
import '../utils/rating_utils.dart';
import 'app_icon.dart';
import 'media_rating_badge.dart';
import 'settings_builder.dart';

/// A compact external-score region, independent of metadata's fitting budget.
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
      math.max(1, math.min(slots, (width / (88 * scaler.scale(1))).floor()));

  static double heightFor(double width, TextScaler scaler, {int slots = RatingDisplayPolicy.detailLimit}) {
    final columns = columnsFor(width, scaler, slots);
    return (slots / columns).ceil() * 48 * scaler.scale(1);
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
            final cellHeight = 48 * scaler.scale(1);
            return SizedBox(
              height: heightFor(width, scaler, slots: maxRatings),
              child: Wrap(
                alignment: alignment,
                children: [
                  for (var index = 0; index < ratings.length; index++)
                    SizedBox(
                      width: cellWidth,
                      height: cellHeight,
                      child: Semantics(
                        label: ratingsSemanticLabel([ratings[index]]),
                        excludeSemantics: true,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: index % columns == 0
                                ? null
                                : Border(left: BorderSide(color: foreground.withValues(alpha: .16))),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              alignment == WrapAlignment.start && index % columns == 0 ? 0 : 12,
                              5,
                              12,
                              5,
                            ),
                            child: Align(
                              alignment: alignment == WrapAlignment.start ? Alignment.centerLeft : Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _RatingScore(rating: ratings[index], foreground: foreground),
                              ),
                            ),
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

class _RatingScore extends StatelessWidget {
  const _RatingScore({required this.rating, required this.foreground});

  final MediaRatingSource rating;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final info = ratingInfoForSource(rating.source, rating.value);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (info != null)
          SizedBox(width: 18 * info.iconAspect, height: 18, child: SvgPicture.asset(info.assetPath))
        else
          AppIcon(
            rating.source == 'personal' ? Symbols.person_rounded : Symbols.star_rounded,
            fill: 1,
            size: 18,
            color: rating.source == 'personal' ? foreground : const Color(0xfff5c544),
          ),
        const SizedBox(width: 6),
        Text(
          mediaRatingLabel(rating),
          maxLines: 1,
          style: TextStyle(
            color: foreground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// One real score on artwork; personal values are explicitly identified as /10.
class MediaCardRatingBadge extends StatelessWidget {
  const MediaCardRatingBadge({super.key, required this.rating});

  final MediaRatingSource rating;

  @override
  Widget build(BuildContext context) {
    final personal = rating.source == 'personal';
    return Semantics(
      label: ratingsSemanticLabel([rating]),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xcc000000), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (personal) ...[
              AppIcon(Symbols.person_rounded, size: 12, color: Colors.white),
              const SizedBox(width: 3),
              Text('${mediaRatingLabel(rating)}/10', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ] else
              InlineRatingBadges(
                ratings: [rating],
                iconSize: 11,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}
