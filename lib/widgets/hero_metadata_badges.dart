import 'package:flutter/material.dart';

import '../media/media_item.dart';
import '../media/media_rating.dart';
import '../focus/focusable_button.dart';
import '../i18n/strings.g.dart';
import '../utils/focus_utils.dart';
import 'rating_source_dialog.dart';
import 'media_rating_badge.dart';
import 'settings_builder.dart';

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
    final genres = item.genres?.map((g) => g.trim()).where((g) => g.isNotEmpty).take(2).join(' · ');
    final labels = <String>[
      if (item.year != null) item.year.toString(),
      if (genres != null && genres.isNotEmpty) genres,
    ];
    final ratings = preferredMediaRatingsFor(item);
    final visibleRatings = ratings.take(1).toList(growable: false);
    final parts = <Widget>[
      if (visibleRatings.isNotEmpty)
        _HeroRatingSourcesButton(
          key: const ValueKey('hero-rating-sources'),
          ratings: ratings,
          visibleRatings: visibleRatings,
          foreground: foreground,
          fontSize: fontSize,
        ),
      for (final label in labels)
        Text(
          label,
          style: TextStyle(color: foreground, fontSize: fontSize, height: 1.2),
        ),
    ];
    return Wrap(
      alignment: alignment,
      spacing: 9,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Text(
              '│',
              style: TextStyle(color: foreground.withValues(alpha: .45), fontSize: fontSize),
            ),
          parts[i],
        ],
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '★',
              style: TextStyle(color: const Color(0xffffe09a), fontSize: widget.fontSize),
            ),
            const SizedBox(width: 3),
            Text(
              widget.visibleRatings.first.value.toStringAsFixed(1),
              style: TextStyle(color: widget.foreground, fontSize: widget.fontSize),
            ),
          ],
        ),
      ),
    ),
  );
}
