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
        var visibleBottom = viewport.size.height;
        final rail = _tvDetailHubs(_metadata).isEmpty ? null : _tvDetailRailKey.currentContext?.findRenderObject();
        if (rail is RenderBox && rail.attached && rail.hasSize) {
          // The foreground viewport can extend into the rail's top padding.
          // Its clip alone therefore overstates the unobscured area. Measure
          // the actual sibling rail in the same coordinates, not an estimate.
          final railTop = viewport.globalToLocal(rail.localToGlobal(Offset.zero)).dy;
          visibleBottom = math.min(visibleBottom, railTop);
        }
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

  Widget _buildHeroHeader(BuildContext context, MediaItem metadata) {
    final centered =
        MediaQuery.sizeOf(context).width < 720 ||
        (MonoPresentation.isTablet(context) && !MonoPresentation.isLandscapeTablet(context));
    final inset = MonoPresentation.pageInset(context);
    final artwork = metadata.thumbPath?.isNotEmpty == true || metadata.artPath?.isNotEmpty == true;
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          inset,
          MediaQuery.paddingOf(context).top + _heroChromeHeight + (artwork ? (centered ? 120 : 64) : 24),
          inset,
          16,
        ),
        child: Align(
          alignment: centered ? Alignment.bottomCenter : Alignment.bottomLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _buildCompactDetailHeader(context, metadata),
          ),
        ),
      ),
    );
  }

  Widget _buildTvDetailForeground(
    BuildContext context,
    MediaItem metadata, {
    required bool hideSpoilers,
    required double scale,
  }) {
    final description = _tvDetailDescription(metadata, hideSpoilers: hideSpoilers);
    final focusedEpisode = _tvDetailFocusedEpisode.value;
    final ratingsItem = focusedEpisode == null ? metadata : _withProbedRatings(focusedEpisode);
    final canRate = _canEditDetailRating(metadata);
    void openDetails() => _openTvDetailsSheet(context, metadata, hideSpoilers: hideSpoilers);
    return SingleChildScrollView(
      key: const ValueKey('tv_detail_content_scroll'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              key: const ValueKey('tv_detail_information_semantics'),
              identifier: 'tv_detail_information',
              container: true,
              button: true,
              label: _tvDetailInformationSemanticLabel(
                metadata,
                description: description,
                genres: metadata.genres ?? const [],
              ),
              hint: t.mediaMenu.viewDetails,
              onTap: openDetails,
              child: ExcludeSemantics(
                child: FocusableWrapper(
                  focusNode: _tvDetailInfoFocusNode,
                  onSelect: openDetails,
                  onNavigateUp: _backButtonFocusNode.requestFocus,
                  onNavigateDown: canRate ? _ratingChipFocusNode.requestFocus : _focusTvDetailActionRow,
                  onBack: _popMediaDetailIfBackNotSuppressed,
                  disableScale: true,
                  borderRadius: 8,
                  descendantsAreFocusable: false,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: openDetails,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNaturalDetailTitle(context, metadata, centered: false, tv: true, scale: scale),
                        const SizedBox(height: 12),
                        if (focusedEpisode?.title?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              focusedEpisode!.title!,
                              key: const ValueKey('tv_detail_episode_title'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        _buildTvDetailMetadataLine(context, metadata, scale),
                        if (description?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              description!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              key: _tvDetailRatingsGroupKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MediaRatingsStrip(
                  item: ratingsItem,
                  fallbackItem: metadata,
                  foregroundColor: _tvDetailForegroundColor(context),
                ),
                if (canRate) _buildUserRatingChip(metadata),
              ],
            ),
            const SizedBox(height: 14),
            KeyedSubtree(key: _tvDetailActionGroupKey, child: _buildActionButtons(metadata)),
            const SizedBox(height: 16),
            _buildPlaybackSelectors(context, metadata),
          ],
        ),
      ),
    );
  }
}
