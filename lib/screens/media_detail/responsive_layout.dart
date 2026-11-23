part of '../media_detail_screen.dart';

extension _MediaDetailResponsiveLayout on _MediaDetailScreenState {
  void _revealTvDetailForeground(GlobalKey key, bool Function() stillFocused) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUseDetail || !PlatformDetector.isTV() || !stillFocused()) return;
      final targetContext = key.currentContext;
      final target = targetContext?.findRenderObject();
      if (targetContext == null || target == null || !target.attached) return;
      final scrollable = Scrollable.maybeOf(targetContext);
      if (scrollable == null || scrollable.position.axis != Axis.vertical) return;
      final viewport = scrollable.context.findRenderObject();
      var revealAlignment = .5;
      if (target is RenderBox && viewport is RenderBox && target.hasSize && viewport.hasSize) {
        final top = target.localToGlobal(Offset.zero, ancestor: viewport).dy;
        final bottom = top + target.size.height;
        final visibleBottom = viewport.size.height;
        // ensureVisible's alignment is relative to the entire viewport's free
        // space. Convert the unobscured region's center to that coordinate so
        // the reveal itself respects the rail as well as the visibility guard.
        final viewportFreeSpace = viewport.size.height - target.size.height;
        revealAlignment = viewportFreeSpace > 0
            ? ((visibleBottom - target.size.height) / (2 * viewportFreeSpace)).clamp(0.0, 1.0).toDouble()
            : 0.0;
        // Initial Play focus should preserve an already readable first screen.
        // Check the complete group on both edges; a clipped group still needs
        // the same reveal path when entered from the information area or rail.
        if (top >= 0 && bottom <= visibleBottom) {
          // A previous focus reveal may still be animating. Let the current
          // visible target take ownership without changing the current offset.
          if (scrollable.position.isScrollingNotifier.value) {
            scrollable.position.jumpTo(scrollable.position.pixels);
          }
          return;
        }
      }
      unawaited(
        scrollable.position.ensureVisible(
          target,
          alignment: revealAlignment,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        ),
      );
    });
  }

  bool _isPortraitPhone(BuildContext context) =>
      PlatformDetector.isPhone(context) && MediaQuery.orientationOf(context) == Orientation.portrait;

  Widget _buildHeroHeader(BuildContext context, MediaItem metadata) {
    final centered =
        MediaQuery.sizeOf(context).width < 720 ||
        (MonoPresentation.isTablet(context) && !MonoPresentation.isLandscapeTablet(context));
    final size = MediaQuery.sizeOf(context);
    final phone = _isPortraitPhone(context);
    final inset = phone ? 24.0 : MonoPresentation.pageInset(context);
    final artwork =
        metadata.thumbPath?.isNotEmpty == true ||
        metadata.heroArtCandidates(containerAspectRatio: size.aspectRatio).isNotEmpty;
    final toolbarBottom = MediaQuery.paddingOf(context).top + _heroChromeHeight;
    // In portrait the title begins at the lower edge of the poster. Everything
    // after it flows naturally as sources, title length and text scale change.
    final top = phone
        ? math.max(
            toolbarBottom + 12,
            artwork
                ? (metadata.isShow || metadata.isSeason || metadata.isEpisode
                      ? math.min(size.width * (320 / 390), size.height * .4)
                      // Movies start the title ~37pt lower (matches _movieHeroArtHeight).
                      : math.min(size.width * (357 / 390), size.height * .44))
                : 0.0,
          )
        : toolbarBottom + (artwork ? (centered ? 120 : 64) : 24);
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset, top, inset, 16),
        child: Align(
          alignment: centered ? Alignment.bottomCenter : Alignment.bottomLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildCompactDetailHeader(context, metadata),
          ),
        ),
      ),
    );
  }

  Widget _buildTvScrollableHero(BuildContext context, MediaItem metadata) {
    final scale = MediaQuery.sizeOf(context).width / 1060;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 320 * scale),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Positioned.fill(
            child: TvSpotlightBackground(
              item: metadata,
              client: _getArtworkMediaClient(context),
              showInfo: false,
              detailScrim: true,
              localArtworkPathResolver: widget.isOffline ? (path) => _offlineArtworkCandidatePath(context, path) : null,
              allowNetwork: !widget.isOffline,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(45 * scale, 68 * scale, 0, 24 * scale),
            child: SizedBox(
              width: 420 * scale,
              child: ListenableBuilder(
                listenable: _tvDetailForegroundListenable,
                builder: (context, _) => _buildCompactDetailHeader(context, metadata),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
