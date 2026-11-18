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
/// Empty data collapses entirely; only rows with actual scores take up space.
class MediaRatingsStrip extends StatefulWidget {
  const MediaRatingsStrip({
    super.key,
    required this.item,
    this.fallbackItem,
    this.foregroundColor,
    this.alignment = WrapAlignment.center,
    this.showSourceLabels = true,
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
  final bool showSourceLabels;
  final int maxRatings;
  final EdgeInsetsGeometry padding;
  final FocusNode? firstFocusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  static int columnsFor(double width, TextScaler scaler, int slots) =>
      math.max(1, math.min(slots, (width / (88 * scaler.scale(1))).floor()));

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
            // Compact scores do not need room for a source caption. Keep two
            // scores grouped centrally, and fit four in a regular phone hero.
            final columns = widget.showSourceLabels
                ? MediaRatingsStrip.columnsFor(width, scaler, widget.maxRatings)
                : (width / scaler.scale(76)).floor().clamp(1, widget.maxRatings);
            final cellWidth = widget.showSourceLabels ? width / columns : math.min(width / columns, scaler.scale(88));
            final cellHeight = 48 * scaler.scale(1);
            return SizedBox(
              width: width,
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
                                    child: _RatingScore(
                                      rating: ratings[index],
                                      foreground: foreground,
                                      showSourceLabel: widget.showSourceLabels,
                                    ),
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
  const _RatingScore({required this.rating, required this.foreground, required this.showSourceLabel});

  final MediaRatingSource rating;
  final Color foreground;
  final bool showSourceLabel;

  @override
  Widget build(BuildContext context) {
    final info = ratingInfoForSource(rating.source, rating.value);
    final score = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (info != null)
          SizedBox(width: 18 * info.iconAspect, height: 18, child: SvgPicture.asset(info.assetPath))
        else
          AppIcon(Symbols.star_rounded, fill: 1, size: 18, color: const Color(0xfff5c544)),
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
    if (!showSourceLabel) return score;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        score,
        Text(
          ratingSourceLabel(rating.source) ?? t.ratingDetails.serverRating,
          maxLines: 1,
          style: TextStyle(color: foreground, fontSize: 11),
        ),
      ],
    );
  }
}

/// The highest-priority enabled public score on the poster.
class MediaCardRatingBadge extends StatelessWidget {
  const MediaCardRatingBadge({super.key, required this.rating, this.withUnit = false});

  final MediaRatingSource rating;
  final bool withUnit;

  @override
  Widget build(BuildContext context) {
    final value = rating.value.toStringAsFixed(1);
    return Semantics(
      label: ratingsSemanticLabel([rating]),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .48), borderRadius: BorderRadius.circular(7)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Text(
            withUnit ? t.common.ratingValue(value: value) : value,
            style: const TextStyle(inherit: false, color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
