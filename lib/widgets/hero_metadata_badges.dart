import 'package:flutter/material.dart';

import '../media/media_item.dart';
import '../media/media_rating.dart';
import '../focus/focusable_button.dart';
import '../i18n/strings.g.dart';
import '../utils/focus_utils.dart';
import 'rating_source_dialog.dart';
import '../utils/content_utils.dart';
import '../utils/rating_display_policy.dart';
import 'media_rating_badge.dart';
import 'settings_builder.dart';
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
  Widget build(BuildContext context) => SettingsBuilder(prefs: ratingDisplayPrefs, builder: _buildBadges);

  Widget _buildBadges(BuildContext context) {
    final lightInk = foreground.computeLuminance() > .5;
    final genres = item.genres?.map((g) => g.trim()).where((g) => g.isNotEmpty).take(2) ?? const <String>[];
    final labels = <String>{
      if (item.year != null) item.year.toString(),
      if (item.contentRating?.trim().isNotEmpty ?? false) formatContentRating(item.contentRating!),
      ...buildMediaQualityLabels(item),
      ...genres,
    };
    final ratings = preferredMediaRatingsFor(item);
    final visibleRatings = ratings.take(RatingDisplayPolicy.heroLimit).toList(growable: false);
    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      children: [
        if (visibleRatings.isNotEmpty)
          _HeroRatingSourcesButton(
            key: const ValueKey('hero-rating-sources'),
            ratings: ratings,
            visibleRatings: visibleRatings,
            foreground: foreground,
            fontSize: fontSize,
          ),
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

class _HeroRatingSourcesButton extends StatefulWidget {
  const _HeroRatingSourcesButton({
    super.key,
    required this.ratings,
    required this.visibleRatings,
    required this.foreground,
    required this.fontSize,
  });
  final List<MediaRatingSource> ratings;
  final List<MediaRatingSource> visibleRatings;
  final Color foreground;
  final double fontSize;
  @override
  State<_HeroRatingSourcesButton> createState() => _HeroRatingSourcesButtonState();
}

class _HeroRatingSourcesButtonState extends State<_HeroRatingSourcesButton> {
  final _focusNode = FocusNode(debugLabel: 'Hero rating sources');
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      await showRatingSourceDialog(context, widget.ratings);
    } finally {
      _opening = false;
      if (mounted) FocusUtils.restoreFocusAfterBuild(this, _focusNode);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${t.ratingDetails.viewSources}. ${ratingsSemanticLabel(widget.visibleRatings)}',
    onTap: _open,
    excludeSemantics: true,
    child: FocusableButton(
      focusNode: _focusNode,
      onPressed: _open,
      dimWhenUnfocused: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final rating in widget.visibleRatings)
              InlineRatingBadges(
                ratings: [rating],
                foregroundColor: widget.foreground,
                textStyle: TextStyle(color: widget.foreground, fontSize: widget.fontSize),
              ),
          ],
        ),
      ),
    ),
  );
}
