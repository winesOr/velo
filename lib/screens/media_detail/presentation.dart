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
    if (number != null) return t.common.seasonNumber(number: number);
    if (title != null && title.isNotEmpty) return title;
    return season.displaySubtitle ?? season.displayTitle;
  }

  Future<void> _chooseCompactDetailSeason(BuildContext context) async {
    final selected = await OverlaySheetController.showAdaptive<int>(
      context,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
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
                      Expanded(child: Text(_seasonLabel(_seasons[index]))),
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
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
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
        if (_episodes.isNotEmpty && !_detailAllEpisodes)
          TextButton(
            onPressed: () => setStateIfMounted(() => _detailAllEpisodes = true),
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
    if (!_canUseDetail || widget.isOffline || client?.capabilities.userFavorites != true) return;
    try {
      final next = metadata.isFavorite != true;
      await client!.setFavorite(metadata, next);
      if (!_canUseDetail) return;
      setStateIfMounted(() => _fullMetadata = _metadata.copyWith(isFavorite: next));
    } catch (error) {
      if (mounted && _canUseDetail) {
        showErrorSnackBar(context, t.messages.errorLoading(error: localizedErrorReason(error)));
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
    final fontSize = tv
        ? 64 * scale
        : centered
        ? 40.0
        : 48.0;
    Widget title(BuildContext context, String text) => Text(
      text,
      key: const ValueKey('detail_natural_title'),
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.12,
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
        height: tv ? 110 * scale : 100,
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
    final labels = <String>[
      if (metadata.year != null) '${metadata.year}',
      if (metadata.contentRating?.isNotEmpty == true) formatContentRating(metadata.contentRating!),
      if ((target?.durationMs ?? metadata.durationMs) case final int duration) formatDurationTextual(duration),
      if (metadata.isShow && metadata.leafCount != null) t.explore.episodeCount(n: metadata.leafCount!),
      ...?metadata.genres?.take(2),
      ...buildMediaQualityLabels(target ?? metadata),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        _buildNaturalDetailTitle(context, metadata, centered: centered),
        const SizedBox(height: 14),
        if (labels.isNotEmpty)
          Text(
            labels.join(' · '),
            key: const ValueKey('detail_plain_metadata'),
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        MediaRatingsStrip(item: metadata, alignment: centered ? WrapAlignment.center : WrapAlignment.start),
        const SizedBox(height: 18),
        if (!_usesCompactHero(MediaQuery.sizeOf(context).width - _heroSideInset * 2) && _canEditDetailRating(metadata))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildUserRatingChip(metadata)),
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
          targetKey: target.globalKey,
          title: target.displayTitle,
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
    setStateIfMounted(() => _detailSelectedEpisode = episode);
    _playbackStatusRevision.value++;
  }

  Widget _buildDetailEpisodeRail() {
    final group = _detailEpisodeGroup.clamp(0, math.max(0, (_episodes.length - 1) ~/ 10)).toInt();
    final start = group * 10;
    final visible = _episodes.skip(start).take(10).toList();
    final selected = _playbackTargetItem(_metadata)?.globalKey;
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      key: _detailEpisodesKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 158 + math.max(0, textScale - 1) * 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final episode = _fresh(visible[index]);
              final active = selected == episode.globalKey;
              final episodeNumber = effectiveEpisodeIndex(episode);
              final status = episode.isWatched
                  ? t.libraries.watched
                  : episode.viewOffsetMs != null && episode.viewOffsetMs! > 0
                  ? t.common.resume
                  : t.libraries.filterCategories.unwatched;
              final local = widget.isOffline && episode.thumbPath != null
                  ? _offlineArtworkCandidatePath(context, episode.thumbPath!)
                  : null;
              return SizedBox(
                width: 202,
                child: FocusableWrapper(
                  key: ValueKey('detail_episode_${episode.id}'),
                  focusNode: _episodeListFocusNode(
                    episode: episode,
                    index: start + index,
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
                  onNavigateUp: _focusSelectedSeasonTab,
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
                            color: Colors.white,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          [
                            if (episode.durationMs != null) formatDurationTextual(episode.durationMs!),
                            status,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontSize: 10, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildDetailEpisodeGroups(group),
      ],
    );
  }

  Widget _buildDetailEpisodeGroups(int group) => Align(
    alignment: Alignment.centerLeft,
    child: TabChipStrip(
      children: [
        for (var index = 0; index < (_episodes.length + 9) ~/ 10; index++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FocusableWrapper(
              disableScale: true,
              onSelect: () => setStateIfMounted(() => _detailEpisodeGroup = index),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setStateIfMounted(() => _detailEpisodeGroup = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: index == group ? .125 : .035),
                    border: Border.all(color: Colors.white.withValues(alpha: index == group ? .375 : .125)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${index * 10 + 1}–${math.min((index + 1) * 10, _episodes.length)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.5),
                  ),
                ),
              ),
            ),
          ),
        if (_episodeListHasMore || _episodeListPageError)
          TextButton(
            onPressed: _episodeListLoadingMore ? null : () => unawaited(_loadMoreEpisodeList()),
            child: Text(_episodeListPageError ? t.common.retry : t.libraries.loadMore),
          ),
      ],
    ),
  );
}
