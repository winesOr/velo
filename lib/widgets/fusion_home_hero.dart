import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../media/media_item.dart';
import '../media/media_item_types.dart';
import '../media/media_server_client.dart';
import '../navigation/home_theme.dart';
import '../theme/home_typography.dart';
import '../theme/mono_presentation.dart';
import '../utils/tone_mapped_logo_image.dart';
import 'optimized_media_image.dart';
import 'hero_metadata_badges.dart';

/// Full-bleed artwork gradually joins the same sampled surface as the page.
/// No bundled demonstration artwork: image failures leave the title playable.
class FusionHomeHero extends StatelessWidget {
  const FusionHomeHero({
    super.key,
    required this.item,
    required this.backdrop,
    required this.onPlay,
    this.playButton,
    this.client,
    this.compact = false,
  });

  final MediaItem item;
  final MediaServerClient? client;
  final Widget backdrop;
  final VoidCallback onPlay;
  final Widget? playButton;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tablet = MonoPresentation.isTablet(context);
    final leftAligned = MonoPresentation.isLandscapeTablet(context);
    final alignment = leftAligned ? Alignment.bottomLeft : Alignment.bottomCenter;
    final textAlign = leftAligned ? TextAlign.left : TextAlign.center;
    final color = HomeThemeScope.colorOf(context);
    final foreground = Theme.of(context).colorScheme.onSurface;
    final homeType = Theme.of(context).extension<HomeTypography>();
    final heroForeground = homeType?.heroTitle.color ?? foreground;
    final title = item.isEpisode ? item.grandparentTitle ?? item.displayTitle : item.displayTitle;
    final originalTitle = item.originalTitle?.trim();
    final metadataStyle = TextStyle(
      color: homeType?.caption.color ?? foreground,
      fontSize: tablet ? 14 : 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0,
    );
    Widget fallbackTitle(BuildContext context) => Align(
      alignment: alignment,
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: (homeType?.heroTitle ?? Theme.of(context).textTheme.displaySmall)?.copyWith(
          fontSize: tablet ? 48 : null,
          color: heroForeground,
          shadows: [
            Shadow(
              color: heroForeground.computeLuminance() > .5
                  ? Colors.black.withValues(alpha: .24)
                  : Colors.white.withValues(alpha: .3),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
    final titleSize = Theme.of(context).textTheme.displaySmall?.fontSize ?? 36;
    final logoHeight = math.max(compact ? 64.0 : 100.0, MediaQuery.textScalerOf(context).scale(titleSize) * 2.2);
    return Semantics(
      label: title,
      button: true,
      child: GestureDetector(
        onTap: onPlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ColoredBox(color: color, child: backdrop),
            ),
            // Spread the blend over most of the artwork, with a gentle start
            // and finish. Every stop uses the page's current artwork color:
            // appearance must never add a white veil over a colored poster.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(decoration: BoxDecoration(gradient: MonoPresentation.artworkBlend(color))),
              ),
            ),
            // Keep status-bar contrast separate from the content background.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: .13), Colors.transparent],
                    stops: const [0, .24],
                  ),
                ),
              ),
            ),
            Positioned(
              left: tablet ? 32 : 20,
              right: tablet ? 32 : 20,
              bottom: 28,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Align(
                  alignment: alignment,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: leftAligned ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (originalTitle != null && originalTitle.isNotEmpty && originalTitle != title) ...[
                          Text(
                            originalTitle.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontFamilyFallback: const ['Go Noto Current', 'serif'],
                              color: metadataStyle.color!.withValues(alpha: .8),
                              fontSize: 9,
                              height: 1.2,
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (item.clearLogoPath?.isNotEmpty ?? false)
                          ClearLogoImage(
                            client: client,
                            logoPath: item.clearLogoPath,
                            width: tablet ? 400 : 310,
                            fallbackWidth: tablet ? 560 : 350,
                            height: logoHeight,
                            alignment: alignment,
                            logoToneTarget: logoToneTargetFor(surface: color, foreground: heroForeground),
                            fallbackBuilder: fallbackTitle,
                          )
                        else
                          fallbackTitle(context),
                        const SizedBox(height: 14),
                        HeroMetadataBadges(
                          item: item,
                          foreground: metadataStyle.color!,
                          fontSize: tablet ? 14 : 12,
                          alignment: leftAligned ? WrapAlignment.start : WrapAlignment.center,
                        ),
                        if (playButton != null) ...[const SizedBox(height: 12), playButton!],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
