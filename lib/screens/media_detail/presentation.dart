part of '../media_detail_screen.dart';

extension _MediaDetailPresentation on _MediaDetailScreenState {
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
                      Expanded(child: Text(_seasons[index].displayTitle)),
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
        season?.displayTitle ??
        (metadata.isSeason
            ? metadata.displayTitle
            : _seasons.length == 1
            ? _seasons.first.displayTitle
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

  Widget _buildCompactDetailHeader(BuildContext context, MediaItem metadata) {
    final theme = Theme.of(context);
    final tablet = MonoPresentation.isTablet(context);
    final leftAligned = MonoPresentation.isLandscapeTablet(context);
    final textAlign = leftAligned ? TextAlign.left : TextAlign.center;
    final target = _playbackTargetItem(metadata);
    final labels = <String>[];
    void addLabel(String? value) {
      final label = value?.trim();
      if (label == null || label.isEmpty || labels.contains(label)) return;
      labels.add(label);
    }

    final identity = [
      if (metadata.year != null) '${metadata.year}',
      if (metadata.studio?.isNotEmpty == true) metadata.studio!,
      ...?metadata.genres?.take(2),
    ];
    addLabel(metadata.contentRating == null ? null : formatContentRating(metadata.contentRating!));
    final durationMs = target?.durationMs ?? metadata.durationMs;
    if (durationMs != null) addLabel(formatDurationTextual(durationMs));
    if (metadata.isShow && metadata.leafCount != null) {
      addLabel(t.explore.episodeCount(n: metadata.leafCount!));
    }
    for (final label in buildMediaQualityLabels(target ?? metadata)) {
      addLabel(label);
    }

    return Align(
      alignment: leftAligned ? Alignment.bottomLeft : Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: leftAligned ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          _buildDetailLogoOrTitle(
            context,
            metadata,
            width: tablet ? 400 : 300,
            height: metadata.clearLogoPath == null ? 76 * math.max(1, MediaQuery.textScalerOf(context).scale(1)) : 86,
            availableWidth: tablet ? 560 : MediaQuery.sizeOf(context).width - 32,
            alignment: leftAligned ? Alignment.centerLeft : Alignment.center,
            titleBuilder: (context, title) => _buildDetailTitle(
              context,
              title,
              fontSize: tablet ? 34 : 26,
              fontWeight: FontWeight.w600,
              textAlign: textAlign,
            ),
          ),
          const SizedBox(height: 7),
          if (identity.isNotEmpty) ...[
            Text(
              identity.join(' · '),
              textAlign: textAlign,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: tablet ? 13 : 11, height: 1.5, color: Colors.white),
            ),
            const SizedBox(height: 5),
          ],
          Text(
            labels.join(' · '),
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: tablet ? 13 : 11,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          _buildActionButtons(metadata),
        ],
      ),
    );
  }

  Widget _buildDetailSourceRow(BuildContext context, MediaItem metadata) {
    return ValueListenableBuilder<int>(
      valueListenable: _playbackStatusRevision,
      builder: (context, _, _) {
        final target = _playbackTargetItem(metadata);
        final probed = target == null ? null : _playbackSources[target.globalKey];
        if (target != null && probed == null) _scheduleTargetProbe(context, target);
        final item = probed?.item ?? target ?? metadata;
        final versionIndex = probed?.mediaIndex ?? 0;
        final labels = [
          ...buildMediaVideoLabels(item, versionIndex: versionIndex),
          ?buildMediaSizeLabel(item, versionIndex: versionIndex),
        ];
        final client = _getMediaClientForMetadata(context);
        final versions = item.mediaVersions;
        final versionCount = versions?.length ?? 0;
        final canChoose = target != null && !widget.isOffline && client != null && versionCount > 1;
        final serverLabel = item.serverName?.trim().isNotEmpty == true ? item.serverName!.trim() : item.backend.id;
        final detailLabel = labels.isNotEmpty ? labels.join(' · ') : item.libraryTitle?.trim();
        final inline =
            MediaQuery.sizeOf(context).width < ScreenBreakpoints.mobile &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        return FocusableWrapper(
          key: const ValueKey('detail_source_version'),
          disableScale: true,
          canRequestFocus: canChoose,
          onSelect: canChoose ? () => unawaited(_chooseDetailVersion(target)) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canChoose ? () => unawaited(_chooseDetailVersion(target)) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .024),
                border: Border.all(color: Colors.white.withValues(alpha: .082)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  BackendBadge(backend: item.backend, size: 20, color: BackendBadge.brandColor(item.backend)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: inline
                        ? Row(
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 60),
                                child: Text(
                                  serverLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.white),
                                ),
                              ),
                              if (detailLabel != null && detailLabel.isNotEmpty) ...[
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    detailLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                serverLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (detailLabel != null && detailLabel.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  detailLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                  if (versionCount > 1)
                    Semantics(
                      label: t.fileInfo.versionCounter(index: versionIndex + 1, count: versionCount),
                      excludeSemantics: true,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 124),
                        child: Text(
                          t.fileInfo.versionCounter(index: versionIndex + 1, count: versionCount),
                          key: const ValueKey('detail_source_version_label'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  if (canChoose) const DetailActionIcon(DetailActionGlyph.next, size: 17),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _chooseDetailVersion(MediaItem target) async {
    final client = _getMediaClientForMetadata(context);
    if (!_canUseDetail || widget.isOffline || client == null) return;
    final versions = await resolveMediaVersions(target, client);
    if (!mounted || !_canUseDetail || _playbackTargetItem(_metadata)?.globalKey != target.globalKey) return;
    if (versions.length < 2) return;
    final selected = await showVersionPickerDialog(context, versions, t.mediaMenu.playVersion);
    if (selected == null || !_canUseDetail || _playbackTargetItem(_metadata)?.globalKey != target.globalKey) return;
    await saveMediaVersionPreferenceFor(target, index: selected, versions: versions);
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
