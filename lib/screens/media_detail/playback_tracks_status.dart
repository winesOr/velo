part of '../media_detail_screen.dart';

/// Resolves the exact version/source advertised by the detail selectors.
/// TV focus changes the target episode without reusing another item's tracks.
extension _MediaDetailPlaybackTracksStatus on _MediaDetailScreenState {
  /// The item Play would start: the hero's episode for a show, the first
  /// episode for a season, the item itself otherwise. Null while a show has
  /// not resolved any episode yet.
  MediaItem? _playbackTargetItem(MediaItem metadata) {
    if (!_canUseDetail) return null;
    final MediaItem? target;
    if (metadata.isShow) {
      target = _showPlayEpisode();
    } else if (metadata.isSeason) {
      target = _detailSelectedEpisode ?? (_episodes.isEmpty ? null : _episodes.first);
    } else {
      target = metadata;
    }
    return target;
  }

  Future<void> _listenForPlaybackVersionChanges() async {
    final settings = await SettingsService.getInstance();
    if (!_canUseDetail) return;
    bindListenable(settings.listenableOf(SettingsService.mediaVersionPreferences), _onPlaybackVersionChanged);
  }

  void _onPlaybackVersionChanged() {
    if (!_canUseDetail) return;
    _invalidatePlaybackProbes(refreshItems: false);
  }

  void _invalidatePlaybackProbes({required bool refreshItems}) {
    _playbackProbeGeneration++;
    _playbackProbeTimer?.cancel();
    _playbackProbeRequests.clear();
    _playbackProbeErrors.clear();
    _playbackSources.clear();
    if (refreshItems) _probedPlaybackItems.clear();
    _playbackStatusRevision.value++;
  }

  /// Fetch metadata once, then resolve the saved selection independently.
  /// A debounced online probe may prepare original VOD on supporting backends.
  /// Offline only reads the completed download's identity, never a server probe.
  void _scheduleTargetProbe(BuildContext context, MediaItem target) {
    if (!_canUseDetail) return;
    final key = target.globalKey;
    if (_playbackSources.containsKey(key) ||
        _playbackProbeRequests.containsKey(key) ||
        _playbackProbeErrors.contains(key)) {
      return;
    }
    final client = widget.isOffline ? null : _getMediaClientForMetadata(context);
    if (!widget.isOffline && client == null) return;
    final downloads = context.read<DownloadProvider?>();
    _playbackProbeTimer?.cancel();
    final generation = _playbackProbeGeneration;
    _playbackProbeTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || generation != _playbackProbeGeneration || _playbackProbeRequests.containsKey(key)) return;
      unawaited(_probeTarget(client, downloads, target, generation));
    });
  }

  Future<void> _probeTarget(
    MediaServerClient? client,
    DownloadProvider? downloads,
    MediaItem target,
    int generation,
  ) async {
    final key = target.globalKey;
    final request = Object();
    _playbackProbeRequests[key] = request;
    bool current() => _canUseDetail && generation == _playbackProbeGeneration && _playbackProbeRequests[key] == request;
    try {
      final offline = widget.isOffline;
      final fetched = offline ? target : _probedPlaybackItems[key] ?? await client!.fetchItem(target.id);
      if (!current()) return;
      if (fetched == null) throw StateError('Playback metadata is unavailable');
      final item = fetched.copyWith(
        serverId: target.serverId ?? fetched.serverId,
        serverName: target.serverName ?? fetched.serverName,
      );
      _probedPlaybackItems[key] = item;
      _recordProbedRatings(key, item.ratings);
      final choice = _detailPlaybackSelections.putIfAbsent(key, DetailPlaybackSelection.new);
      final explicitIndex = choice.versionIndex(item.mediaVersions);
      final downloaded = await downloads?.getCompletedDownload(key);
      if (!current()) return;
      final saved = await resolveSavedMediaVersionFor(item);
      if (!current()) return;
      final versions = item.mediaVersions ?? const <MediaVersion>[];
      final downloadedById = downloaded?.mediaSourceId == null
          ? -1
          : versions.indexWhere((version) => version.id == downloaded!.mediaSourceId);
      final downloadedIndex = downloaded == null
          ? null
          : (downloadedById >= 0 ? downloadedById : downloaded.mediaIndex);
      final selectedIndex = explicitIndex ?? downloadedIndex ?? saved?.index ?? 0;
      final selectedId = explicitIndex != null
          ? versions[explicitIndex].id
          : downloaded != null
          ? downloaded.mediaSourceId
          : saved?.sourceId;
      final signature = explicitIndex != null
          ? versions[explicitIndex].signature
          : downloaded != null
          ? null
          : saved?.signature;
      final useDownloaded = downloaded != null && (explicitIndex == null || explicitIndex == downloadedIndex);
      MediaSourceInfo? source;
      if (offline || useDownloaded) {
        final scope = downloaded?.clientScopeId ?? client?.cacheServerId ?? item.serverId;
        if (scope != null) {
          source = await CachedPlaybackMetadataService.fetchMediaSourceInfo(
            backend: item.backend,
            cacheServerId: scope,
            itemId: item.id,
            mediaIndex: selectedIndex,
            position: item.viewOffsetMs == null ? null : Duration(milliseconds: item.viewOffsetMs!),
          );
        }
      } else {
        source = await client!.fetchCachedMediaSourceInfo(
          item.id,
          mediaIndex: selectedIndex,
          mediaSourceId: selectedId,
          preferredVersionSignature: signature,
        );
      }
      if (!current()) return;
      final mediaIndex = source?.mediaIndex ?? selectedIndex;
      choice.bindSource(source);
      if (client case final PlaybackPreparationSupport preparer when !offline && !useDownloaded) {
        unawaited(
          preparer.preparePlaybackInitialization(
            PlaybackInitializationOptions(
              metadata: item,
              selectedMediaIndex: mediaIndex,
              selectedMediaSourceId: source?.mediaSourceId ?? selectedId,
              preferredVersionSignature: signature,
              startPosition: item.viewOffsetMs == null ? null : Duration(milliseconds: item.viewOffsetMs!),
            ),
          ),
        );
      }
      if (!current()) return;
      _playbackSources[key] = (item: item, source: source, mediaIndex: mediaIndex);
      // Only the status repaints: do not rebuild the rail or replace its
      // focused item with a cached probe snapshot.
      _playbackStatusRevision.value++;
    } catch (e, stackTrace) {
      if (current()) {
        _playbackProbeErrors.add(key);
        _playbackStatusRevision.value++;
      }
      appLogger.d('Playback track probe failed for ${target.id}', error: e, stackTrace: stackTrace);
    } finally {
      if (_playbackProbeRequests[key] == request) _playbackProbeRequests.remove(key);
    }
  }

  /// Repaints the TV hero only when the scores are new for the episode it
  /// shows; a re-probe after a refresh returns the same scores.
  void _recordProbedRatings(String key, List<MediaRatingSource>? ratings) {
    if (ratings == null || ratings.isEmpty) return;
    final isNew = !_probedRatings.containsKey(key);
    _probedRatings[key] = ratings;
    if (isNew && _tvDetailFocusedEpisode.value?.globalKey == key) _focusedEpisodeRatingsRevision.value++;
  }

  String? _playbackSummaryLabel(MediaItem metadata) {
    final target = _playbackTargetItem(metadata);
    final probed = target == null ? null : _playbackSources[target.globalKey];
    if (probed == null) return null;
    final source = probed.source;
    final preview = source == null
        ? null
        : previewPlaybackTracks(
            probed.item,
            source,
            profile: context.watch<AccountPreferencesController?>()?.activePreferences,
          );
    final choice = _detailPlaybackSelections[target!.globalKey];
    final audio = source?.audioTracks.where((track) => track.id == choice?.audioId).firstOrNull ?? preview?.audio;
    final subtitle = choice?.subtitlesOff == true
        ? null
        : source?.subtitleTracks.where((track) => track.id == choice?.subtitleId).firstOrNull ?? preview?.subtitle;
    final videoLabels = probed.mediaIndex == null
        ? const <String>[]
        : buildMediaVideoLabels(probed.item, versionIndex: probed.mediaIndex!, partIndex: source?.partIndex);
    if (preview == null && videoLabels.isEmpty) return null;
    final parts = [
      ...videoLabels,
      if (audio != null) [audio.label.primary, ?audio.label.secondary].join(' · '),
      if (preview != null)
        subtitle == null ? t.common.off : [subtitle.label.primary, ?subtitle.label.secondary].join(' · '),
    ];
    return '${t.videoControls.tracksButton}: ${parts.join(', ')}';
  }
}
