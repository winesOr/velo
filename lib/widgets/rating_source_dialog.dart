import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../i18n/strings.g.dart';
import '../focus/focusable_wrapper.dart';
import '../media/media_rating.dart';
import '../theme/overlay_tokens.dart';
import '../utils/dialogs.dart';
import '../utils/rating_display_policy.dart';
import '../utils/rating_utils.dart';
import 'app_dialog.dart';
import 'app_glass_surface.dart';
import 'app_icon.dart';
import 'dialog_action_button.dart';
import 'media_rating_badge.dart';

/// Shows the caller's enabled, ordered scores without fetching or combining them.
/// Empty/invalid scores do not open a route. The nearest scoped navigator owns it.
Future<void> showRatingSourceDialog(BuildContext context, List<MediaRatingSource> ratings) async {
  if (!context.mounted) return;
  final valid = List<MediaRatingSource>.unmodifiable(ratings.where(RatingDisplayPolicy.isPublicScore));
  if (valid.isEmpty) return;
  await showScopedDialog<void>(
    context: context,
    builder: (_) => RatingSourceDialog(ratings: valid),
  );
}

/// Source details shared by the home and media detail pages.
class RatingSourceDialog extends StatefulWidget {
  const RatingSourceDialog({super.key, required this.ratings});

  final List<MediaRatingSource> ratings;

  @override
  State<RatingSourceDialog> createState() => _RatingSourceDialogState();
}

class _RatingSourceDialogState extends State<RatingSourceDialog> {
  final _scrollController = ScrollController();
  final _contentFocus = FocusNode(debugLabel: 'Rating source content');
  final _closeFocus = FocusNode(debugLabel: 'Close rating sources');

  void _scrollBy(double direction) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + direction * position.viewportDimension * .5)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    if (target == position.pixels) {
      if (direction > 0) _closeFocus.requestFocus();
      return;
    }
    if (AppGlassSurface.reduceEffects(context)) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _contentFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The scoped route can capture white or black ink chosen for artwork.
    // Its glass panel uses the app appearance, so all its ink must use that
    // same theme. This lookup does not change which navigator owns the route.
    final appTheme = Theme.of(Navigator.of(context, rootNavigator: true).context);
    return Theme(
      data: appTheme,
      child: Builder(builder: _buildDialog),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    void close() {
      if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
    }

    final dialog = AppDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Semantics(
              namesRoute: true,
              header: true,
              child: AppDialogTitle(title: Text(t.ratingDetails.title, style: Theme.of(context).textTheme.titleLarge)),
            ),
          ),
          Flexible(
            child: FocusableWrapper(
              focusNode: _contentFocus,
              delegateFocusBorder: true,
              disableScale: true,
              autoScroll: false,
              onNavigateUp: () => _scrollBy(-1),
              onNavigateDown: () => _scrollBy(1),
              onNavigateRight: _closeFocus.requestFocus,
              onBack: close,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t.ratingDetails.explanation,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    for (final rating in widget.ratings.where(RatingDisplayPolicy.isPublicScore))
                      _RatingSourceRow(rating: rating),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DialogActionButton(
                autofocus: true,
                focusNode: _closeFocus,
                label: t.common.close,
                onPressed: close,
                onBack: close,
                onNavigateUp: _contentFocus.requestFocus,
                onNavigateLeft: _contentFocus.requestFocus,
              ),
            ),
          ),
        ],
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppGlassSurface.reduceEffects(context) ? Duration.zero : OverlayTokens.motion,
      curve: Curves.easeOutCubic,
      child: dialog,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: .96 + .04 * value, child: child),
      ),
    );
  }
}

class _RatingSourceRow extends StatelessWidget {
  const _RatingSourceRow({required this.rating});
  final MediaRatingSource rating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = ratingSourceLabel(rating.source);
    final name = label ?? t.ratingDetails.serverRating;
    final info = ratingInfoForSource(rating.source, rating.value);
    final percent = switch (rating.source) {
      'tmdb' || 'rottenTomatoes' || 'rottenTomatoesCritic' || 'rottenTomatoesAudience' => true,
      _ => false,
    };
    final scale = percent ? t.ratingDetails.percentageScale : t.ratingDetails.tenPointScale;
    final value = percent ? mediaRatingLabel(rating) : '${mediaRatingLabel(rating)}/10';
    final unspecified = label == null || rating.source == 'critic' || rating.source == 'audience';
    final description = unspecified
        ? t.ratingDetails.serverExplanation(source: t.ratingDetails.sourceUnspecified, scale: scale)
        : t.ratingDetails.sourceExplanation(source: name, scale: scale);
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              height: 28,
              child: info == null
                  ? AppIcon(
                      unspecified ? Symbols.dns_rounded : Symbols.star_rounded,
                      size: 24,
                      color: colors.onSurfaceVariant,
                    )
                  : SvgPicture.asset(info.assetPath, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleSmall),
                      Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
