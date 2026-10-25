import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../i18n/strings.g.dart';
import '../utils/layout_constants.dart';
import '../theme/mono_presentation.dart';
import '../utils/platform_detector.dart';
import '../widgets/ambient_skeleton.dart';
import '../widgets/app_icon.dart';

/// First-load home frame. The hero and rows use the same rhythm as the loaded
/// feed so artwork landing does not collapse an empty spinner into a new page.
class DiscoverLoadingSkeleton extends StatelessWidget {
  const DiscoverLoadingSkeleton({super.key, this.isTv});

  final bool? isTv;

  @override
  Widget build(BuildContext context) {
    final tv = isTv ?? PlatformDetector.isTV();
    return AmbientSkeletonScope(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientSkeletonBackdrop(brandMark: true),
          if (tv) _TvDiscoverSkeleton() else _MobileDiscoverSkeleton(),
        ],
      ),
    );
  }
}

/// A bounded rail placeholder for a later hub pass. Unlike
/// [DiscoverLoadingSkeleton], this can be inserted directly into the home
/// sliver list without asking the outer scroll view for unbounded height.
class DiscoverHubLoadingSkeleton extends StatelessWidget {
  const DiscoverHubLoadingSkeleton({super.key, this.topPadding = 8, this.rows = 2});

  final double topPadding;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final cardWidth = compact ? 111.0 : 148.0;
    final posterHeight = cardWidth * 1.5;

    return AmbientSkeletonScope(
      child: Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var row = 0; row < rows; row++)
              Padding(
                padding: EdgeInsets.fromLTRB(17, row == 0 ? 0 : 22, 0, 0),
                child: _MobileHubSkeletonRow(row: row, cardWidth: cardWidth, posterHeight: posterHeight),
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileDiscoverSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final heroHeight = MonoPresentation.isTablet(context)
        ? MonoPresentation.touchHeroHeight(context)
        : (size.height < 600 ? size.height : size.height * .68);
    final compact = size.width < 600;
    final cardWidth = compact ? 111.0 : 148.0;
    final posterHeight = cardWidth * 1.5;

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: .055),
                        Colors.transparent,
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                      stops: const [0, .64, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      const AmbientSkeletonBox(
                        width: 126,
                        height: 38,
                        borderRadius: BorderRadius.all(Radius.circular(19)),
                      ),
                      const Spacer(),
                      AmbientSkeletonBox(width: 38, height: 38, shape: BoxShape.circle),
                      const SizedBox(width: 8),
                      AmbientSkeletonBox(width: 38, height: 38, shape: BoxShape.circle),
                    ],
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 54,
                  child: Column(
                    children: [
                      const AmbientSkeletonBox(
                        width: 196,
                        height: 36,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      const SizedBox(height: 16),
                      const AmbientSkeletonBox(
                        width: 168,
                        height: 11,
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                      const SizedBox(height: 16),
                      const AmbientSkeletonBox(
                        width: 112,
                        height: 42,
                        borderRadius: BorderRadius.all(Radius.circular(21)),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            AmbientSkeletonBox(width: i == 0 ? 15 : 5, height: 5, shape: BoxShape.circle),
                            if (i != 2) const SizedBox(width: 7),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (var row = 0; row < 3; row++)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(17, row == 0 ? 8 : 22, 0, 0),
              child: _MobileHubSkeletonRow(row: row, cardWidth: cardWidth, posterHeight: posterHeight),
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 116)),
      ],
    );
  }
}

class _MobileHubSkeletonRow extends StatelessWidget {
  const _MobileHubSkeletonRow({required this.row, required this.cardWidth, required this.posterHeight});

  final int row;
  final double cardWidth;
  final double posterHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AmbientSkeletonBox(
              width: row == 0 ? 122 : 92 + row * 14,
              height: 18,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            const SizedBox(width: 10),
            const AmbientSkeletonBox(width: 38, height: 18, borderRadius: BorderRadius.all(Radius.circular(4))),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: posterHeight + 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(right: 17),
            itemCount: 5,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => AmbientSkeletonCard(
              width: cardWidth,
              posterHeight: posterHeight,
              titleWidthFactor: index.isEven ? .88 : .68,
            ),
          ),
        ),
      ],
    );
  }
}

class _TvDiscoverSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final railHeight = (size.height * .35).clamp(220.0, 390.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: TvLayoutConstants.horizontalInset,
          right: size.width * .35,
          top: size.height * .19,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AmbientSkeletonBox(width: 360, height: 74, borderRadius: BorderRadius.all(Radius.circular(10))),
              const SizedBox(height: 20),
              const AmbientSkeletonBox(width: 280, height: 13, borderRadius: BorderRadius.all(Radius.circular(5))),
              const SizedBox(height: 10),
              const AmbientSkeletonBox(width: 220, height: 13, borderRadius: BorderRadius.all(Radius.circular(5))),
              const SizedBox(height: 28),
              Row(
                children: [
                  const AmbientSkeletonBox(width: 124, height: 46, borderRadius: BorderRadius.all(Radius.circular(23))),
                  const SizedBox(width: 12),
                  AmbientSkeletonBox(width: 46, height: 46, shape: BoxShape.circle),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: TvLayoutConstants.horizontalInset,
          right: TvLayoutConstants.horizontalInset,
          bottom: 38,
          height: railHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AmbientSkeletonBox(width: 180, height: 22, borderRadius: BorderRadius.all(Radius.circular(4))),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => AmbientSkeletonCard(
                    width: railHeight * .39,
                    posterHeight: railHeight - 100,
                    titleWidthFactor: index.isEven ? .9 : .7,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: TvLayoutConstants.horizontalInset,
          right: TvLayoutConstants.horizontalInset,
          top: 22,
          child: Row(
            children: [
              AmbientSkeletonBox(width: 140, height: 24, borderRadius: const BorderRadius.all(Radius.circular(6))),
              const Spacer(),
              for (var i = 0; i < 4; i++) ...[
                AmbientSkeletonBox(width: 24, height: 24, shape: BoxShape.circle),
                if (i != 3) const SizedBox(width: 18),
              ],
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 22,
          child: Center(
            child: Semantics(
              label: t.common.loading,
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
                      letterSpacing: .2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hub-only TV loading frame used after Continue Watching has settled but the
/// recommendation rows are still in flight. The full spotlight skeleton is
/// reserved for the first frame, when there is no content to preserve.
class TvDiscoverHubLoadingSkeleton extends StatelessWidget {
  const TvDiscoverHubLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final railHeight = (size.height * .35).clamp(220.0, 390.0);

    return AmbientSkeletonScope(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientSkeletonBackdrop(brandMark: true),
          Positioned(
            left: TvLayoutConstants.horizontalInset,
            right: TvLayoutConstants.horizontalInset,
            bottom: 38,
            height: railHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AmbientSkeletonBox(width: 180, height: 22, borderRadius: BorderRadius.all(Radius.circular(4))),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 6,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) => AmbientSkeletonCard(
                      width: railHeight * .39,
                      posterHeight: railHeight - 100,
                      titleWidthFactor: index.isEven ? .9 : .7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Center(
              child: Semantics(
                label: t.common.loading,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
