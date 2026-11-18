part of '../media_detail_screen.dart';

/// Artwork owns the page ink, while enclosed controls keep the user's
/// appearance and its paired surface, foreground and popup roles.
class _DetailControlsTheme extends InheritedWidget {
  const _DetailControlsTheme({required this.theme, required super.child});

  final ThemeData theme;

  static ThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DetailControlsTheme>()!.theme;

  @override
  bool updateShouldNotify(_DetailControlsTheme oldWidget) => theme != oldWidget.theme;
}

extension _MediaDetailPlaybackSelectors on _MediaDetailScreenState {
  Widget _buildPlaybackSelectors(BuildContext context, MediaItem metadata) {
    return ValueListenableBuilder<int>(
      valueListenable: _playbackStatusRevision,
      builder: (context, _, _) {
        final target = _playbackTargetItem(metadata);
        final key = target?.globalKey;
        final probed = _playbackSources[key];
        final failed = _playbackProbeErrors.contains(key);
        final canProbe = widget.isOffline || _getMediaClientForMetadata(context) != null;
        if (target != null && probed == null && !failed && canProbe) _scheduleTargetProbe(context, target);
        final busy = target != null && probed == null && !failed && canProbe;
        final item = probed?.item ?? target ?? metadata;
        final versions = item.mediaVersions ?? const <MediaVersion>[];
        final placeholder = busy ? t.common.loading : t.detailPlayback.unavailable;
        final selectedIndex = probed?.mediaIndex;
        final selected = selectedIndex != null && selectedIndex >= 0 && selectedIndex < versions.length
            ? versions[selectedIndex]
            : null;
        final backendName = switch (item.backend) {
          MediaBackend.plex => 'Plex',
          MediaBackend.jellyfin => 'Jellyfin',
          MediaBackend.emby => 'Emby',
        };
        final controlsTheme = _DetailControlsTheme.of(context);
        final fieldsContent = Theme(
          data: controlsTheme,
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (!event.isActionable || !_versionSelectFocusNode.hasFocus) return KeyEventResult.ignored;
              if (event.logicalKey.isUpKey) {
                _playButtonFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              if (event.logicalKey.isDownKey) {
                _focusBelowPlaybackSelectors();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              key: const ValueKey('detail_playback_selectors'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: IntrinsicWidth(
                    child: AppSelectField<String>(
                      key: const ValueKey('detail_source_version'),
                      focusNode: _versionSelectFocusNode,
                      label: t.detailPlayback.selectVersion,
                      value: selected?.id,
                      selectedLabel: selected == null
                          ? placeholder
                          : _detailVersionSummary(selected, versions.length, movie: item.isMovie),
                      leading: BackendBadge(backend: item.backend, size: 17),
                      inlineContent: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '$backendName  '),
                            TextSpan(
                              text: selected == null
                                  ? placeholder
                                  : _detailVersionQuality(selected, movie: item.isMovie),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: controlsTheme.colorScheme.onSurface,
                              ),
                            ),
                            if (versions.isNotEmpty)
                              TextSpan(text: '  ${t.detailPlayback.versionCount(n: versions.length)}'),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: controlsTheme.colorScheme.onSurfaceVariant),
                      ),
                      optionMaxLines: 2,
                      showChevron: true,
                      placeholder: placeholder,
                      busy: busy,
                      enabled: !widget.isOffline && canProbe && !_playLaunchPending,
                      options: [
                        for (final (index, version) in versions.indexed)
                          AppSelectOption(
                            value: version.id,
                            label: '$backendName · ${_detailVersionQuality(version, separator: ' ')}',
                            subtitle: _detailVersionOptionSubtitle(version, index, versions.length),
                            leading: BackendBadge(backend: item.backend, size: 20),
                            enabled: version.isPlayable,
                          ),
                      ],
                      onChanged: target == null ? null : (id) => unawaited(_selectDetailVersion(target, versions, id)),
                    ),
                  ),
                ),
                if (failed)
                  TextButton.icon(
                    key: const ValueKey('detail_playback_retry'),
                    onPressed: () {
                      if (target == null) return;
                      _playbackProbeErrors.remove(key);
                      _playbackStatusRevision.value++;
                      _scheduleTargetProbe(context, target);
                    },
                    icon: const AppIcon(Symbols.refresh_rounded),
                    label: Text('${t.detailPlayback.loadFailed} · ${t.common.retry}'),
                  ),
              ],
            ),
          ),
        );
        final label = _playbackSummaryLabel(metadata);
        return label == null
            ? fieldsContent
            : Semantics(
                key: const ValueKey('detail_playback_tracks'),
                label: label,
                container: true,
                child: fieldsContent,
              );
      },
    );
  }

  String _detailVersionQuality(MediaVersion version, {bool movie = false, String separator = ' · '}) {
    final resolution = version.videoResolution?.trim();
    final codec = version.videoCodec?.trim();
    final parts = <String>[
      if (resolution != null && resolution.isNotEmpty)
        resolutionDisplayLabel(resolution)
      else if (version.height != null && version.height! > 0)
        '${version.height}p',
      if (movie)
        t.detailPlayback.originalQuality
      else if (codec != null && codec.isNotEmpty)
        CodecUtils.formatVideoCodec(codec).replaceAll('H.', 'H'),
    ];
    return parts.isEmpty ? version.displayLabel : parts.join(separator);
  }

  String _detailVersionSummary(MediaVersion version, int count, {bool movie = false}) => [
    _detailVersionQuality(version, movie: movie),
    if (count > 0) t.detailPlayback.versionCount(n: count),
  ].join(' · ');

  String _detailVersionOptionSubtitle(MediaVersion version, int index, int count) {
    // Only report a version's size when every physical part has a known size.
    final completeSize =
        version.parts.isNotEmpty && version.parts.every((part) => part.sizeBytes != null && part.sizeBytes! > 0);
    return [
      index == 0 ? t.detailPlayback.defaultRoute : t.detailPlayback.alternateVersion,
      if (version.name?.trim() case final name? when name.isNotEmpty && name != _detailVersionQuality(version)) name,
      if (completeSize)
        ByteFormatter.formatBytes(version.parts.fold<int>(0, (total, part) => total + part.sizeBytes!), decimals: 2),
    ].join(' · ');
  }

  Future<void> _selectDetailVersion(MediaItem target, List<MediaVersion> versions, String id) async {
    final index = versions.indexWhere((version) => version.id == id);
    if (!_canUseDetail ||
        index < 0 ||
        widget.isOffline ||
        _playbackTargetItem(_metadata)?.globalKey != target.globalKey) {
      return;
    }
    _detailPlaybackSelections.putIfAbsent(target.globalKey, DetailPlaybackSelection.new).chooseVersion(versions[index]);
    _invalidatePlaybackProbes(refreshItems: false);
    try {
      await saveMediaVersionPreferenceFor(target, index: index, versions: versions);
    } catch (error) {
      if (_canUseDetail && mounted) {
        showErrorSnackBar(context, t.messages.errorLoading(error: localizedErrorReason(error)));
      }
    }
  }
}
