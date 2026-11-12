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
        final source = probed?.source;
        final choice = key == null ? null : _detailPlaybackSelections[key];
        final preview = source == null
            ? null
            : previewPlaybackTracks(
                item,
                source,
                profile: context.watch<AccountPreferencesController?>()?.activePreferences,
              );
        final placeholder = busy ? t.common.loading : t.detailPlayback.unavailable;
        final selectedIndex = probed?.mediaIndex;
        final selectedVersion = selectedIndex != null && selectedIndex >= 0 && selectedIndex < versions.length
            ? versions[selectedIndex].id
            : null;
        final scope = key == null || source == null ? null : detailTrackScope(key, source);
        final audioId = choice?.audioId ?? preview?.audio?.id;
        DetailTrackOption? trackOption(int? id) => scope == null ? null : (scope: scope, streamId: id);
        void updateChoice(DetailTrackOption option, void Function(DetailPlaybackSelection value) update) {
          if (!_canUseDetail || target == null || _playbackTargetItem(_metadata)?.globalKey != key) return;
          final currentSource = _playbackSources[key]?.source;
          if (currentSource == null || option.scope != detailTrackScope(key!, currentSource)) return;
          final current = _detailPlaybackSelections.putIfAbsent(key, DetailPlaybackSelection.new);
          update(current);
          _playbackStatusRevision.value++;
        }

        final controlsTheme = _DetailControlsTheme.of(context);
        final fields = <Widget>[
          AppSelectField<String>(
            key: const ValueKey('detail_source_version'),
            focusNode: _versionSelectFocusNode,
            label: t.detailPlayback.version,
            value: selectedVersion,
            placeholder: placeholder,
            busy: busy,
            enabled: !widget.isOffline && canProbe && !_playLaunchPending,
            options: [
              for (final (index, version) in versions.indexed)
                AppSelectOption(
                  value: version.id,
                  label: version.displayLabel,
                  subtitle: t.fileInfo.versionCounter(index: index + 1, count: versions.length),
                  enabled: version.isPlayable,
                ),
            ],
            onChanged: target == null ? null : (id) => unawaited(_selectDetailVersion(target, versions, id)),
          ),
          AppSelectField<DetailTrackOption>(
            key: const ValueKey('detail_audio_selector'),
            focusNode: _audioSelectFocusNode,
            label: t.fileInfo.audio,
            value: audioId == null ? null : trackOption(audioId),
            placeholder: placeholder,
            busy: busy,
            enabled: !_playLaunchPending,
            options: [
              if (scope != null)
                for (final track in source?.audioTracks ?? const <MediaAudioTrack>[])
                  AppSelectOption(
                    value: (scope: scope, streamId: track.id),
                    label: track.label.primary,
                    subtitle: track.label.secondary,
                  ),
            ],
            onChanged: (option) => updateChoice(option, (value) => value.audioId = option.streamId),
          ),
          AppSelectField<DetailTrackOption>(
            key: const ValueKey('detail_subtitle_selector'),
            focusNode: _subtitleSelectFocusNode,
            label: t.fileInfo.subtitles,
            value: choice?.subtitlesOff == true
                ? trackOption(null)
                : choice?.subtitleId != null
                ? trackOption(choice?.subtitleId)
                : preview == null
                ? null
                : trackOption(preview.subtitle?.id),
            placeholder: placeholder,
            busy: busy,
            enabled: source != null && mediaSourceHasTrackRows(source) && !_playLaunchPending,
            options: [
              if (scope != null && source != null && mediaSourceHasTrackRows(source))
                AppSelectOption(value: (scope: scope, streamId: null), label: t.common.off),
              if (scope != null)
                for (final track in source?.subtitleTracks ?? const <MediaSubtitleTrack>[])
                  AppSelectOption(
                    value: (scope: scope, streamId: track.id),
                    label: track.label.primary,
                    subtitle: track.label.secondary,
                  ),
            ],
            onChanged: (option) => updateChoice(option, (value) {
              value.subtitlesOff = option.streamId == null;
              value.subtitleId = option.streamId;
            }),
          ),
        ].map((field) => Theme(data: controlsTheme, child: field)).toList(growable: false);
        final fieldsContent = LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 680 && MediaQuery.textScalerOf(context).scale(1) <= 1.4;
            return Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                if (!event.isActionable) return KeyEventResult.ignored;
                final nodes = [
                  _versionSelectFocusNode,
                  _audioSelectFocusNode,
                  _subtitleSelectFocusNode,
                ].where((node) => node.canRequestFocus && node.context != null).toList();
                final index = nodes.indexWhere((node) => node.hasFocus);
                if (index < 0) return KeyEventResult.ignored;
                if (event.logicalKey.isUpKey) {
                  if (index == 0 || columns) {
                    _playButtonFocusNode.requestFocus();
                  } else {
                    nodes[index - 1].requestFocus();
                  }
                  return KeyEventResult.handled;
                }
                if (event.logicalKey.isDownKey) {
                  if (index == nodes.length - 1 || columns) {
                    _focusBelowPlaybackSelectors();
                  } else {
                    nodes[index + 1].requestFocus();
                  }
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Column(
                key: const ValueKey('detail_playback_selectors'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!columns)
                    Column(
                      children: [
                        for (final field in fields) Padding(padding: const EdgeInsets.only(bottom: 8), child: field),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (index, field) in fields.indexed) ...[
                          if (index > 0) const SizedBox(width: 12),
                          Expanded(child: field),
                        ],
                      ],
                    ),
                  if (failed)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
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
                    ),
                ],
              ),
            );
          },
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
