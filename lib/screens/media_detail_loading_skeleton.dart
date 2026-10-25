import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../i18n/strings.g.dart';
import '../media/media_item.dart';
import '../utils/layout_constants.dart';
import '../theme/mono_presentation.dart';
import '../utils/platform_detector.dart';
import '../widgets/ambient_skeleton.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_bar_back_button.dart';
import '../utils/desktop_window_padding.dart';

/// Keeps the detail route's first frame spatially identical to the loaded
/// hero. Metadata usually lands in one round trip, so a full-page spinner made
/// the transition feel like a navigation reset.
class MediaDetailLoadingSkeleton extends StatelessWidget {
  const MediaDetailLoadingSkeleton({super.key, required this.metadata, required this.onBack, this.focusNode});

  final MediaItem metadata;
  final VoidCallback onBack;
  final FocusNode? focusNode;

  static const double _heroChromeHeight = 58;
  static const double _heroLogoHeight = 120;
  static const double _heroActionHeight = 48;
  static const double _heroBottomInset = 16;
  static const double _heroSideInset = 16;

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.isTV()) return _buildTv(context);
    return _buildPhone(context);
  }

  Widget _buildPhone(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.paddingOf(context);
    final compact =
        MonoPresentation.isTablet(context) ||
        size.width - viewPadding.horizontal - _heroSideInset * 2 < ScreenBreakpoints.mobile;
    final hasArtwork =
        metadata.thumbPath?.isNotEmpty == true ||
        metadata.heroArtCandidates(containerAspectRatio: size.aspectRatio).isNotEmpty;
    final compactHeroHeight = MonoPresentation.touchHeroHeight(context, detail: true, hasArtwork: hasArtwork);
    final heroFloor =
        viewPadding.top +
        _heroChromeHeight +
        _heroLogoHeight +
        12 +
        34 * 2 +
        12 +
        12 +
        _heroActionHeight +
        _heroBottomInset;
    final headerHeight = compact ? compactHeroHeight : math.max(size.height * .6, heroFloor);
    final artHeight = _heroArtHeight(size, headerHeight);

    return Scaffold(
      body: AmbientSkeletonScope(
        child: Stack(
          children: [
            Positioned.fill(child: AmbientSkeletonBackdrop()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: artHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: .075),
                        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: .12),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                      stops: const [0, .45, .9],
                    ),
                  ),
                ),
              ),
            ),
            CustomScrollView(
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    key: const ValueKey('detail_hero'),
                    height: headerHeight,
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          MonoPresentation.pageInset(context),
                          viewPadding.top + _heroChromeHeight,
                          MonoPresentation.pageInset(context),
                          _heroBottomInset,
                        ),
                        child: MonoPresentation.isTablet(context)
                            ? _tabletHeader(context)
                            : (compact ? _compactHeader() : _wideHeader()),
                      ),
                    ),
                  ),
                ),
                SliverSafeArea(
                  top: false,
                  bottom: false,
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      child: compact ? _compactBody() : _wideBody(),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              child: DesktopAppBarHelper.buildAdjustedLeading(
                AppBarBackButton(style: BackButtonStyle.circular, onPressed: onBack, focusNode: focusNode),
                context: context,
              )!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideHeader() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AmbientSkeletonBox(width: 320, height: 92, borderRadius: BorderRadius.all(Radius.circular(8))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final width in const [64.0, 54.0, 72.0, 92.0])
                AmbientSkeletonBox(width: width, height: 28, borderRadius: const BorderRadius.all(Radius.circular(14))),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AmbientSkeletonBox(width: 120, height: 48, borderRadius: BorderRadius.all(Radius.circular(24))),
              SizedBox(width: 10),
              AmbientSkeletonBox(width: 48, height: 48, shape: BoxShape.circle),
              SizedBox(width: 10),
              AmbientSkeletonBox(width: 48, height: 48, shape: BoxShape.circle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wideBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AmbientSkeletonBox(height: 54, borderRadius: BorderRadius.all(Radius.circular(14))),
              const SizedBox(height: 24),
              const AmbientSkeletonBox(width: 76, height: 18, borderRadius: BorderRadius.all(Radius.circular(4))),
              const SizedBox(height: 14),
              for (final widthFactor in const [1.0, .94, .88, .62]) ...[
                FractionallySizedBox(
                  widthFactor: widthFactor,
                  alignment: Alignment.centerLeft,
                  child: const AmbientSkeletonBox(height: 12, borderRadius: BorderRadius.all(Radius.circular(4))),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 18),
              const _SkeletonSectionHeader(),
              const SizedBox(height: 14),
              SizedBox(
                height: 178,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => const AmbientSkeletonCard(width: 150, posterHeight: 128),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SkeletonSectionHeader(width: 108),
              const SizedBox(height: 14),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => Column(
                    children: [
                      const AmbientSkeletonBox(width: 62, height: 62, shape: BoxShape.circle),
                      const SizedBox(height: 8),
                      AmbientSkeletonBox(
                        width: index.isEven ? 52 : 40,
                        height: 9,
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compactBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AmbientSkeletonBox(height: 54, borderRadius: BorderRadius.all(Radius.circular(14))),
        const SizedBox(height: 24),
        const AmbientSkeletonBox(width: 76, height: 18, borderRadius: BorderRadius.all(Radius.circular(4))),
        const SizedBox(height: 14),
        for (final widthFactor in const [1.0, .94, .88, .62]) ...[
          FractionallySizedBox(
            widthFactor: widthFactor,
            alignment: Alignment.centerLeft,
            child: const AmbientSkeletonBox(height: 12, borderRadius: BorderRadius.all(Radius.circular(4))),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        const _SkeletonSectionHeader(),
        const SizedBox(height: 14),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => const AmbientSkeletonCard(width: 150, posterHeight: 128),
          ),
        ),
        const SizedBox(height: 26),
        const _SkeletonSectionHeader(width: 108),
        const SizedBox(height: 14),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) => Column(
              children: [
                const AmbientSkeletonBox(width: 62, height: 62, shape: BoxShape.circle),
                const SizedBox(height: 8),
                AmbientSkeletonBox(
                  width: index.isEven ? 52 : 40,
                  height: 9,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabletHeader(BuildContext context) {
    final left = MonoPresentation.isLandscapeTablet(context);
    return Align(
      alignment: left ? Alignment.bottomLeft : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: left ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            const AmbientSkeletonBox(width: 320, height: 86, borderRadius: BorderRadius.all(Radius.circular(8))),
            const SizedBox(height: 12),
            const AmbientSkeletonBox(width: 210, height: 13, borderRadius: BorderRadius.all(Radius.circular(5))),
            const SizedBox(height: 14),
            const AmbientSkeletonBox(height: 47, borderRadius: BorderRadius.all(Radius.circular(24))),
            const SizedBox(height: 6),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _compactHeader() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AmbientSkeletonBox(width: 260, height: 76, borderRadius: BorderRadius.all(Radius.circular(8))),
          const SizedBox(height: 10),
          const AmbientSkeletonBox(width: 210, height: 11, borderRadius: BorderRadius.all(Radius.circular(5))),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AmbientSkeletonBox(width: 116, height: 48, borderRadius: BorderRadius.all(Radius.circular(24))),
              const SizedBox(width: 10),
              const AmbientSkeletonBox(width: 48, height: 48, shape: BoxShape.circle),
              const SizedBox(width: 10),
              AmbientSkeletonBox(
                width: 48,
                height: 48,
                shape: BoxShape.circle,
                borderRadius: BorderRadius.circular(24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTv(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = TvLayoutConstants.scaleForSize(size);
    final spotlightTop = (size.height * .08).clamp(56.0 * scale, 110.0 * scale).toDouble();
    final left = (24 * scale).clamp(18.0, 40.0).toDouble();
    final railHeight = (size.height * .34).clamp(220.0, 360.0);
    final actionSize = 46.0 * scale;

    return Scaffold(
      body: AmbientSkeletonScope(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AmbientSkeletonBackdrop(),
            Positioned(
              left: left,
              right: size.width * .4,
              top: spotlightTop,
              bottom: railHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AmbientSkeletonBox(
                    width: 380,
                    height: 100,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  const SizedBox(height: 18),
                  const AmbientSkeletonBox(width: 260, height: 13, borderRadius: BorderRadius.all(Radius.circular(5))),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      AmbientSkeletonBox(
                        width: 132,
                        height: actionSize,
                        borderRadius: BorderRadius.all(Radius.circular(actionSize / 2)),
                      ),
                      const SizedBox(width: 12),
                      for (var i = 0; i < 3; i++) ...[
                        AmbientSkeletonBox(width: actionSize, height: actionSize, shape: BoxShape.circle),
                        if (i != 2) const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: TvLayoutConstants.horizontalInset,
              right: TvLayoutConstants.horizontalInset,
              bottom: 34,
              height: railHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AmbientSkeletonBox(width: 160, height: 20, borderRadius: BorderRadius.all(Radius.circular(4))),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 6,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) => AmbientSkeletonCard(
                        width: railHeight * .42,
                        posterHeight: railHeight - 98,
                        titleWidthFactor: index.isEven ? .9 : .7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: DesktopAppBarHelper.buildAdjustedLeading(
                AppBarBackButton(style: BackButtonStyle.circular, onPressed: onBack, focusNode: focusNode),
                context: context,
              )!,
            ),
            Positioned(
              right: left,
              bottom: 28,
              child: Row(
                children: [
                  AppIcon(
                    Symbols.progress_activity_rounded,
                    size: 15,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .42),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.common.loading,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .42),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _heroArtHeight(Size size, double headerHeight) {
    const backdropAspect = 16 / 9;
    final maxArtHeight = math.max(headerHeight, size.height * .86);
    return (size.width / backdropAspect).clamp(headerHeight, maxArtHeight).toDouble();
  }
}

class _SkeletonSectionHeader extends StatelessWidget {
  const _SkeletonSectionHeader({this.width = 132});

  final double width;

  @override
  Widget build(BuildContext context) {
    return AmbientSkeletonBox(width: width, height: 18, borderRadius: const BorderRadius.all(Radius.circular(4)));
  }
}
