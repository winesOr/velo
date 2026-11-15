import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../focus/focusable_wrapper.dart';
import '../i18n/strings.g.dart';
import '../utils/focus_utils.dart';
import '../media/media_item.dart';
import '../media/media_rating.dart';
import '../utils/rating_display_policy.dart';
import '../utils/rating_utils.dart';
import 'app_icon.dart';
import 'media_rating_badge.dart';
import 'settings_builder.dart';
import 'rating_source_dialog.dart';

/// A compact external-score region, independent of metadata's fitting budget.
/// Empty data collapses entirely; adding sources keeps the existing slot geometry.
class MediaRatingsStrip extends StatefulWidget {
  const MediaRatingsStrip({
    super.key,
    required this.item,
    this.fallbackItem,
    this.foregroundColor,
    this.alignment = WrapAlignment.center,
    this.maxRatings = RatingDisplayPolicy.detailLimit,
    this.padding = EdgeInsets.zero,
    this.firstFocusNode,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  final MediaItem item;
  final MediaItem? fallbackItem;
  final Color? foregroundColor;
  final WrapAlignment alignment;
  final int maxRatings;
  final EdgeInsetsGeometry padding;
  final FocusNode? firstFocusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  static int columnsFor(double width, TextScaler scaler, int slots) =>
      math.max(1, math.min(slots, (width / (88 * scaler.scale(1))).floor()));

  static double heightFor(double width, TextScaler scaler, {int slots = RatingDisplayPolicy.detailLimit}) {
    final columns = columnsFor(width, scaler, slots);
    return (slots / columns).ceil() * 48 * scaler.scale(1);
  }

  @override
  State<MediaRatingsStrip> createState() => _MediaRatingsStripState();
}

class _MediaRatingsStripState extends State<MediaRatingsStrip> {
  final List<FocusNode> _ownedNodes = [];
  bool _opening = false;

  FocusNode _nodeAt(int index) {
    if (index == 0 && widget.firstFocusNode != null) return widget.firstFocusNode!;
    while (_ownedNodes.length <= index) {
      _ownedNodes.add(FocusNode(debugLabel: 'detail_rating_source_${_ownedNodes.length}'));
    }
    return _ownedNodes[index];
  }

  Future<void> _open(List<MediaRatingSource> ratings, FocusNode node) async {
    if (_opening) return;
    final restoreFocus = node.hasFocus;
    _opening = true;
    try {
      await showRatingSourceDialog(context, ratings);
    } finally {
      _opening = false;
      if (mounted && restoreFocus) FocusUtils.restoreFocusAfterBuild(this, node);
    }
  }

  @override
  void dispose() {
    for (final node in _ownedNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsBuilder(
    prefs: ratingDisplayPrefs,
    builder: (context) {
      final allRatings = preferredMediaRatingsFor(widget.item, fallbackItem: widget.fallbackItem);
      final ratings = allRatings.take(widget.maxRatings).toList(growable: false);
      if (ratings.isEmpty) return const SizedBox.shrink();
      final foreground = widget.foregroundColor ?? Theme.of(context).colorScheme.onSurface;
      final scaler = MediaQuery.textScalerOf(context);
      return Padding(
        padding: widget.padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth ? constraints.maxWidth : 320.0;
            final columns = MediaRatingsStrip.columnsFor(width, scaler, widget.maxRatings);
            final cellWidth = width / columns;
            final cellHeight = 48 * scaler.scale(1);
            return SizedBox(
              height: MediaRatingsStrip.heightFor(width, scaler, slots: widget.maxRatings),
              child: Wrap(
                alignment: widget.alignment,
                children: [
                  for (var index = 0; index < ratings.length; index++)
                    SizedBox(
                      width: cellWidth,
                      height: cellHeight,
                      child: Semantics(
                        button: true,
                        label: ratingsSemanticLabel([ratings[index]]),
                        hint: t.ratingDetails.viewSources,
                        onTap: () => _open(allRatings, _nodeAt(index)),
                        excludeSemantics: true,
                        child: FocusableWrapper(
                          focusNode: _nodeAt(index),
                          onSelect: () => _open(allRatings, _nodeAt(index)),
                          onNavigateUp: widget.onNavigateUp,
                          onNavigateDown: widget.onNavigateDown,
                          onNavigateLeft: index > 0 ? () => _nodeAt(index - 1).requestFocus() : null,
                          onNavigateRight: index + 1 < ratings.length ? () => _nodeAt(index + 1).requestFocus() : null,
                          disableScale: true,
                          borderRadius: 8,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _open(allRatings, _nodeAt(index)),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: index % columns == 0
                                    ? null
                                    : Border(left: BorderSide(color: foreground.withValues(alpha: .16))),
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  widget.alignment == WrapAlignment.start && index % columns == 0 ? 0 : 12,
                                  5,
                                  12,
                                  5,
                                ),
                                child: Align(
                                  alignment: widget.alignment == WrapAlignment.start
                                      ? Alignment.centerLeft
                                      : Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _RatingScore(rating: ratings[index], foreground: foreground),
                                  ),
                                ),
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
