part of '../media_detail_screen.dart';

extension _MediaDetailPresentation on _MediaDetailScreenState {
  String _seasonLabel(MediaItem season) {
    final number = season.index;
    final title = season.title?.trim();
    if (number == 0 &&
        title != null &&
        title.isNotEmpty &&
        title != season.parentTitle &&
        title != season.grandparentTitle) {
      return title;
    }
    if (number != null) return t.videoControls.seasonNumber(n: number);
    if (title != null && title.isNotEmpty) return title;
    return season.displaySubtitle ?? season.displayTitle;
  }

  Future<void> _chooseCompactDetailSeason(BuildContext context) async {
    final selected = await OverlaySheetController.showAdaptive<int>(
      context,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(t.detailPlayback.selectSeason, style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          for (var index = 0; index < _seasons.length; index++)
            FocusableWrapper(
              autofocus: index == _selectedSeasonIndex,
              disableScale: true,
              onSelect: () => OverlaySheetController.closeAdaptive(sheetContext, index),
              onLongPress: () => _showSeasonTabContextMenu(index),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => OverlaySheetController.closeAdaptive(sheetContext, index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_seasonLabel(_seasons[index])),
                            if ((_seasons[index].leafCount ?? _seasons[index].childCount) case final count?
                                when count > 0)
                              Text(
                                t.detailPlayback.episodesAvailable(n: count),
                                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (index == _selectedSeasonIndex) const AppIcon(Symbols.check_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (selected != null && mounted && _canUseDetail && selected != _selectedSeasonIndex) {
      _selectSeason(selected, selectPlaybackTarget: true);
    }
  }

  Widget _buildCompactDetailEpisodeHeader(BuildContext context, MediaItem metadata, {bool chooseSeason = false}) {
    final season = chooseSeason ? _seasons[_selectedSeasonIndex] : null;
    final label =
        (season != null ? _seasonLabel(season) : null) ??
        (metadata.isSeason
            ? _seasonLabel(metadata)
            : _seasons.length == 1
            ? _seasonLabel(_seasons.first)
            : t.libraries.groupings.episodes);
    return Row(
      key: _seasonsSectionKey,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FocusableWrapper(
              key: const ValueKey('detail_season_picker'),
              focusNode: chooseSeason ? _seasonTabFocusNodes[_selectedSeasonIndex] : null,
              canRequestFocus: chooseSeason,
              disableScale: true,
              onSelect: chooseSeason ? () => unawaited(_chooseCompactDetailSeason(context)) : null,
              onLongPress: chooseSeason ? () => _showSeasonTabContextMenu(_selectedSeasonIndex) : null,
              onNavigateUp: () => _playButtonFocusNode.requestFocus(),
              onNavigateDown: () => _firstEpisodeFocusNode.requestFocus(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: chooseSeason ? () => unawaited(_chooseCompactDetailSeason(context)) : null,
                onLongPress: chooseSeason ? () => _showSeasonTabContextMenu(_selectedSeasonIndex) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (chooseSeason) ...[
                      const SizedBox(width: 5),
                      const DetailActionIcon(DetailActionGlyph.down, size: 13),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_episodes.isNotEmpty)
          TextButton(
            onPressed: () => unawaited(_showDetailEpisodeGrid(context)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.common.viewAll),
                const SizedBox(width: 4),
                const DetailActionIcon(DetailActionGlyph.next, size: 13),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _toggleDetailFavorite(MediaItem metadata) async {
    final client = _getMediaClientForMetadata(context);
    if (!_canUseDetail ||
        widget.isOffline ||
        client?.capabilities.userFavorites != true ||
        _favoriteTarget == metadata.globalKey) {
      return;
    }
    final request = Object();
    final target = metadata.globalKey;
    final next = metadata.isFavorite != true;
    _favoriteToast?.dismiss();
    _favoriteRequest = request;
    _favoriteTarget = target;
    final toast = AppToast.pending(context);
    _favoriteToast = toast;
    setStateIfMounted(() {});
    try {
      await client!.setFavorite(metadata, next);
      if (!_canUseDetail || _metadata.globalKey != target) {
        toast.dismiss();
        return;
      }
      setStateIfMounted(() => _fullMetadata = _metadata.copyWith(isFavorite: next));
      toast.update(next ? t.messages.addedToFavorites : t.messages.removedFromFavorites);
    } catch (error) {
      if (_canUseDetail && _metadata.globalKey == target) {
        toast.update(t.messages.errorLoading(error: localizedErrorReason(error)), type: AppToastType.error);
      } else {
        toast.dismiss();
      }
    } finally {
      if (identical(_favoriteRequest, request)) {
        _favoriteRequest = null;
        _favoriteTarget = null;
        if (identical(_favoriteToast, toast)) _favoriteToast = null;
        setStateIfMounted(() {});
      }
    }
  }

  Widget _buildDetailSectionHeader(BuildContext context, String title, {Key? titleKey, Widget? trailing}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            key: titleKey,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    );
  }

  Widget _buildNaturalDetailTitle(
    BuildContext context,
    MediaItem metadata, {
    required bool centered,
    bool tv = false,
    double scale = 1,
  }) {
    final narrow = MediaQuery.sizeOf(context).width < ScreenBreakpoints.mobile;
    final phone = PlatformDetector.isMobile(context) && !MonoPresentation.isTablet(context);
    final fontSize = tv
        ? 36 * scale
        : narrow || phone
        ? 32.0
        : 36.0;
    Widget title(BuildContext context, String text) => Text(
      text,
      key: const ValueKey('detail_natural_title'),
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -.6,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
    // A text title has no height budget: accessibility text must be allowed
    // to wrap. Logos keep their aspect-ratio slot; large text uses the title.
    if (metadata.clearLogoPath == null || MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return title(context, metadata.displayTitle);
    }
    return LayoutBuilder(
      builder: (context, constraints) => _buildDetailLogoOrTitle(
        context,
        metadata,
        width: math.min(constraints.maxWidth, tv ? 640 * scale : 400),
        height: fontSize * 2,
        availableWidth: constraints.maxWidth,
        alignment: centered ? Alignment.center : Alignment.centerLeft,
        titleBuilder: (context, text) => FittedBox(fit: BoxFit.scaleDown, child: title(context, text)),
      ),
    );
  }

  Widget _buildCompactDetailHeader(BuildContext context, MediaItem metadata) {
    final centered =
        MediaQuery.sizeOf(context).width < 720 ||
        (MonoPresentation.isTablet(context) && !MonoPresentation.isLandscapeTablet(context));
    final target = _playbackTargetItem(metadata);
    final probed = _playbackSources[target?.globalKey];
    final firstLine = <String>[
      if (metadata.isShow || metadata.isSeason) ...[
        if (metadata.studio?.isNotEmpty == true) metadata.studio!,
      ] else if (metadata.year != null)
        '${metadata.year}',
      ...?metadata.genres?.take(2),
    ];
    final seasonCount = metadata.childCount ?? (_seasons.isEmpty ? null : _seasons.length);
    final secondLine = <String>[
      if (metadata.isShow && seasonCount != null) t.explore.detail.seasonCount(n: seasonCount),
      if ((target?.durationMs ?? metadata.durationMs) case final int duration) formatDurationTextual(duration),
      if (buildMediaVideoLabels(probed?.item ?? target ?? metadata, versionIndex: probed?.mediaIndex ?? 0)
          case final quality when quality.isNotEmpty)
        quality.join(' '),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        _buildNaturalDetailTitle(context, metadata, centered: centered),
        const SizedBox(height: 7),
        for (final (index, labels) in [firstLine, secondLine].indexed)
          if (labels.isNotEmpty)
            Text(
              labels.join(' · '),
              key: ValueKey(index == 0 ? 'detail_plain_metadata' : 'detail_secondary_metadata'),
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.6),
            ),
        MediaRatingsStrip(
          item: metadata,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          padding: const EdgeInsets.only(bottom: 18),
        ),
        _buildActionButtons(metadata),
      ],
    );
  }

  Widget _buildDetailTechnicalInfo(BuildContext context, MediaItem metadata) {
    return ValueListenableBuilder<int>(
      valueListenable: _playbackStatusRevision,
      builder: (context, _, _) {
        final target = _playbackTargetItem(metadata);
        if (target == null) return const SizedBox.shrink();
        final probed = _playbackSources[target.globalKey];
        final client = widget.isOffline ? null : _getMediaClientForMetadata(context);
        return MediaDetailTechnicalInfo(
          key: _technicalInfoKey,
          onNavigateUp: PlatformDetector.isTV() ? null : _focusSectionAboveInfoRows,
          targetKey: target.globalKey,
          title: [
            target.isEpisode ? target.grandparentTitle ?? metadata.displayTitle : target.displayTitle,
            if (target.isEpisode)
              [
                if (target.parentIndex != null) t.videoControls.seasonNumber(n: target.parentIndex!),
                if (effectiveEpisodeIndex(target) case final episode?) t.videoControls.episodeNumber(n: episode),
              ].join(' '),
          ].join(' · '),
          offline: widget.isOffline,
          revision: _playbackProbeGeneration,
          sourceId: probed?.source?.mediaSourceId,
          versionIndex: probed?.mediaIndex,
          showHeading: false,
          // Wait for the preference probe: do not briefly show version zero
          // while the actual selected version is still resolving.
          load: client == null || probed == null ? null : () => client.getFileInfo(probed.item),
        );
      },
    );
  }

  void _selectDetailEpisode(MediaItem episode) {
    setStateIfMounted(() {
      _detailSelectedEpisode = episode;
      _detailEpisodeSelectionRevision++;
    });
    _playbackStatusRevision.value++;
  }

  int get _detailEpisodeCount {
    final season = _metadata.isSeason
        ? _metadata
        : _seasons.isNotEmpty
        ? _seasons[_selectedSeasonIndex]
        : null;
    final reported = _isFlattenEpisodeList ? _allEpisodesTotal : _selectedSeasonEpisodeState.totalCount;
    return math.max(_episodes.length, math.max(reported, season?.leafCount ?? season?.childCount ?? 0));
  }

  Future<bool> _ensureDetailEpisodeIndex(int index, {bool Function()? isRequestCurrent}) async {
    final generation = _episodesLoadGeneration;
    final seasonId = _seasons.isEmpty ? null : _seasons[_selectedSeasonIndex].id;
    bool current() =>
        _canUseDetail &&
        (isRequestCurrent?.call() ?? true) &&
        generation == _episodesLoadGeneration &&
        seasonId == (_seasons.isEmpty ? null : _seasons[_selectedSeasonIndex].id);
    while (current() && index >= _episodes.length && _episodeListHasMore) {
      while (current() && _episodeListLoadingMore) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (!current() || index < _episodes.length) break;
      final before = _episodes.length;
      await _loadMoreEpisodeList();
      if (_episodes.length <= before) break;
    }
    return current() && index >= 0 && index < _episodes.length;
  }

  Future<void> _showDetailEpisodeGrid(BuildContext context) async {
    final revision = _detailEpisodeRailRevision;
    final generation = _episodesLoadGeneration;
    final selectionRevision = ++_detailEpisodeSelectionRevision;
    bool requestCurrent() =>
        _canUseDetail &&
        revision == _detailEpisodeRailRevision &&
        generation == _episodesLoadGeneration &&
        selectionRevision == _detailEpisodeSelectionRevision;
    final selected = _playbackTargetItem(_metadata)?.globalKey;
    final season = _metadata.isSeason
        ? _metadata
        : _seasons.isNotEmpty
        ? _seasons[_selectedSeasonIndex]
        : null;
    final title = [if (season != null) _seasonLabel(season), t.detailPlayback.allEpisodes].join(' · ');
    final index = await OverlaySheetController.showAdaptive<int>(
      context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                key: const ValueKey('detail_episode_grid'),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 64,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _detailEpisodeCount,
                itemBuilder: (context, index) {
                  final episode = index < _episodes.length ? _fresh(_episodes[index]) : null;
                  return FocusableWrapper(
                    autofocus: episode?.globalKey == selected,
                    disableScale: true,
                    onSelect: () => OverlaySheetController.closeAdaptive(sheetContext, index),
                    child: TextButton(
                      onPressed: () => OverlaySheetController.closeAdaptive(sheetContext, index),
                      style: TextButton.styleFrom(
                        backgroundColor: episode?.globalKey == selected
                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .12)
                            : null,
                      ),
                      child: Text('${episode == null ? index + 1 : effectiveEpisodeIndex(episode) ?? index + 1}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (index == null || !requestCurrent()) return;
    final loaded = await _ensureDetailEpisodeIndex(index, isRequestCurrent: requestCurrent);
    // Paging completes after the sheet has closed. A newer card selection,
    // grid request or season change owns the target even if the old page lands.
    if (!loaded || !requestCurrent()) return;
    _selectDetailEpisode(_fresh(_episodes[index]));
    setStateIfMounted(() {
      _detailEpisodeRailIndex = index;
      _detailEpisodeRailRevision++;
    });
  }

  Widget _buildDetailEpisodeRail() {
    final selected = _playbackTargetItem(_metadata)?.globalKey;
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return DetailEpisodeRail(
      key: _detailEpisodesKey,
      episodeCount: _episodes.length,
      height: 158 + math.max(0, textScale - 1) * 50,
      initialIndex: _detailEpisodeRailIndex,
      resetToken: _detailEpisodeRailRevision,
      onPositionChanged: (index) => _detailEpisodeRailIndex = index,
      hasTail: _episodeListHasMore || _episodeListLoadingMore || _episodeListPageError,
      canLoadMore: _episodeListHasMore && !_episodeListLoadingMore && !_episodeListPageError,
      onLoadMore: () => unawaited(_loadMoreEpisodeList()),
      onRequestIndex: _ensureDetailEpisodeIndex,
      groupsBuilder: (context, group, scrollToGroup) => _buildDetailEpisodeGroups(group, scrollToGroup),
      itemBuilder: (context, index) {
        if (index == _episodes.length) return _buildEpisodeListTail();
        final episode = _fresh(_episodes[index]);
        final active = selected == episode.globalKey;
        final episodeNumber = effectiveEpisodeIndex(episode);
        final status = active ? t.detailPlayback.pendingPlayback : t.libraries.filterCategories.unwatched;
        final local = widget.isOffline && episode.thumbPath != null
            ? _offlineArtworkCandidatePath(context, episode.thumbPath!)
            : null;
        return SizedBox(
          width: 202,
          child: MediaContextMenu(
            item: episode,
            onRefresh: widget.isOffline ? null : _refreshItemInPlace,
            onListRefresh: widget.isOffline ? null : _refreshCurrentEpisodes,
            child: FocusableWrapper(
              key: ValueKey('detail_episode_${episode.id}'),
              focusNode: _episodeListFocusNode(
                episode: episode,
                index: index,
                hasPinnedLastEpisode: _hasPinnedLastEpisodeInList,
              ),
              onSelect: () => _selectDetailEpisode(episode),
              onLongPress: () => unawaited(
                navigateToVideoPlayerWithRefresh(
                  context,
                  metadata: episode,
                  isOffline: widget.isOffline,
                  onRefresh: _refreshWatchState,
                  isLaunchCurrent: () => _canUseDetail,
                ),
              ),
              onNavigateUp: () {
                if (!_showEpisodesDirectly) {
                  _focusSelectedSeasonTab();
                } else if (!PlatformDetector.isTV() && _metadata.summary?.isNotEmpty == true) {
                  _overviewFocusNode.requestFocus();
                  _scrollSectionIntoView(_overviewSectionKey);
                } else {
                  _playButtonFocusNode.requestFocus();
                }
              },
              disableScale: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _selectDetailEpisode(episode),
                onLongPress: () => unawaited(
                  navigateToVideoPlayerWithRefresh(
                    context,
                    metadata: episode,
                    isOffline: widget.isOffline,
                    onRefresh: _refreshWatchState,
                    isLaunchCurrent: () => _canUseDetail,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 112,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: active ? Border.all(color: theme.colorScheme.onSurface, width: 2) : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          OptimizedMediaImage.thumb(
                            client: widget.isOffline ? null : _getArtworkMediaClient(context),
                            imagePath: episode.thumbPath,
                            localFilePath: local,
                            width: 202,
                            height: 112,
                          ),
                          if (episodeNumber != null)
                            Positioned(
                              right: 8,
                              bottom: 6,
                              child: DecoratedBox(
                                key: ValueKey('detail_episode_number_${episode.id}'),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .52),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  child: Text(
                                    padNumber(episodeNumber, 2),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontSize: 10,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      episodeDisplayTitle(episode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      [if (episode.durationMs != null) formatDurationTextual(episode.durationMs!), status].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailEpisodeGroups(int group, ValueChanged<int> scrollToGroup) => Align(
    alignment: Alignment.centerLeft,
    child: TabChipStrip(
      children: [
        for (var index = 0; index < (_detailEpisodeCount + 9) ~/ 10; index++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              selected: index == group,
              child: FocusableWrapper(
                disableScale: true,
                onSelect: () => scrollToGroup(index),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => scrollToGroup(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: index == group ? .125 : .035),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: index == group ? .375 : .125),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      episodeGroupLabel(index, _detailEpisodeCount),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 11, height: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
