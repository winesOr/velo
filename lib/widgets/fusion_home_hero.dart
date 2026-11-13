import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:math' as math;

import '../media/media_item.dart';
import '../media/media_item_types.dart';
import '../media/media_server_client.dart';
import '../navigation/home_theme.dart';
import '../theme/home_typography.dart';
import '../theme/mono_presentation.dart';
import '../theme/interaction_tokens.dart';
import '../i18n/strings.g.dart';
import '../utils/tone_mapped_logo_image.dart';
import 'optimized_media_image.dart';
import 'hero_metadata_badges.dart';
import 'hero_text_blocks.dart';
import 'app_icon.dart';
import 'press_feedback.dart';

/// Home recommendations may include containers, which have no playable source.
/// Their primary action stays on details until an episode is explicitly chosen.
bool canPlayHomeHeroDirectly(MediaItem item) => item.isMovie || item.isEpisode;

/// Full-bleed artwork gradually joins the same sampled surface as the page.
/// No bundled demonstration artwork: image failures leave the title playable.
class FusionHomeHero extends StatelessWidget {
  const FusionHomeHero({
    super.key,
    required this.item,
    required this.backdrop,
    required this.onPlay,
    this.playButton,
    this.detailsButton,
    this.client,
    this.compact = false,
    this.hideSpoiler = false,
  });

  final MediaItem item;
  final MediaServerClient? client;
  final Widget backdrop;
  final VoidCallback onPlay;
  final Widget? playButton;
  final Widget? detailsButton;
  final bool compact;
  final bool hideSpoiler;

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
        textAlign: textAlign,
        style: (homeType?.heroTitle ?? Theme.of(context).textTheme.displaySmall)?.copyWith(
          fontSize: tablet ? 48 : 44,
          fontWeight: FontWeight.w600,
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
              top: compact ? 24 : MediaQuery.paddingOf(context).top + 48,
              bottom: 28,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Align(
                  alignment: alignment,
                  child: SingleChildScrollView(
                    reverse: true,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: leftAligned ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (heroHasOriginalTitle(item, title)) ...[
                            HeroOriginalTitle(
                              item: item,
                              displayTitle: title,
                              color: metadataStyle.color!,
                              textAlign: textAlign,
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
                          if (heroHasSummary(item, hideSpoiler)) ...[
                            const SizedBox(height: 12),
                            HeroSummary(
                              item: item,
                              hideSpoiler: hideSpoiler,
                              maxLines: 2,
                              fontSize: tablet ? 14 : 13,
                              height: 1.4,
                              color: metadataStyle.color!.withValues(alpha: .8),
                              textAlign: textAlign,
                            ),
                          ],
                          if (playButton != null || detailsButton != null) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: leftAligned ? WrapAlignment.start : WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [?playButton, ?detailsButton],
                            ),
                          ],
                        ],
                      ),
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

/// The production home action, shared with visual fixtures so resumed playback
/// always exercises the real progress bar and localized remaining-time label.
class HomeHeroPrimaryButton extends StatelessWidget {
  const HomeHeroPrimaryButton({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onDetails,
    this.busy = false,
    this.isTv = false,
    this.showFocus = false,
  });

  final MediaItem item;
  final VoidCallback? onPlay;
  final VoidCallback? onDetails;
  final bool busy;
  final bool isTv;
  final bool showFocus;

  @override
  Widget build(BuildContext context) {
    final playable = canPlayHomeHeroDirectly(item);
    final hasProgress = playable && item.hasActiveProgress;
    final minutesLeft = hasProgress ? ((item.durationMs! - item.viewOffsetMs!) / 60000).round() : 0;
    final progress = hasProgress ? (item.viewOffsetMs! / item.durationMs!).clamp(0.0, 1.0).toDouble() : 0.0;
    final label = !playable
        ? t.mediaMenu.viewDetails
        : hasProgress
        ? t.discover.minutesLeft(minutes: minutesLeft)
        : t.common.play;
    final action = busy
        ? null
        : playable
        ? onPlay
        : onDetails;
    final radius = BorderRadius.circular(isTv ? 32 : 24);
    return PressFeedbackBuilder(
      pressedScale: InteractionTokens.mainPressedScale,
      enabled: action != null,
      borderRadius: radius,
      builder: (context, setPressed, confirm) => InkWell(
        onTap: action,
        onHighlightChanged: setPressed,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : InteractionTokens.releaseDuration,
          curve: InteractionTokens.pressCurve,
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: EdgeInsets.symmetric(horizontal: isTv ? 34 : 24, vertical: isTv ? 16 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            boxShadow: showFocus
                ? [BoxShadow(color: Colors.white.withValues(alpha: .35), blurRadius: 28, spreadRadius: 4)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              else
                AppIcon(
                  playable ? Symbols.play_arrow_rounded : Symbols.info_rounded,
                  fill: 1,
                  size: isTv ? 28 : 20,
                  color: Colors.black,
                ),
              SizedBox(width: isTv ? 12 : 8),
              if (hasProgress) ...[
                Container(
                  key: const ValueKey('home-hero-play-progress'),
                  width: isTv ? 56 : 40,
                  height: isTv ? 8 : 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
                SizedBox(width: isTv ? 12 : 8),
              ],
              Flexible(
                child: Text(
                  label,
                  softWrap: true,
                  style: TextStyle(color: Colors.black, fontSize: isTv ? 18 : 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
