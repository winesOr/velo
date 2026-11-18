import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../focus/focusable_wrapper.dart';
import '../i18n/strings.g.dart';
import '../media/media_file_info.dart';
import '../theme/mono_presentation.dart';
import '../utils/codec_utils.dart';
import '../utils/resolution_label.dart';
import 'app_icon.dart';

/// Read-only file data for the same target and version as the Play action.
/// A target change discards the old snapshot before the replacement resolves.
class MediaDetailTechnicalInfo extends StatefulWidget {
  const MediaDetailTechnicalInfo({
    super.key,
    required this.targetKey,
    required this.title,
    required this.load,
    this.sourceId,
    this.versionIndex,
    this.offline = false,
    this.revision = 0,
    this.showHeading = false,
    this.onNavigateUp,
  });

  final String targetKey;
  final String title;
  final Future<MediaFileInfo?> Function()? load;
  final String? sourceId;
  final int? versionIndex;
  final bool offline;
  final int revision;
  final bool showHeading;
  final VoidCallback? onNavigateUp;

  @override
  State<MediaDetailTechnicalInfo> createState() => MediaDetailTechnicalInfoState();
}

class MediaDetailTechnicalInfoState extends State<MediaDetailTechnicalInfo> {
  static const _cardWidth = 235.0;
  static const _cardGap = 11.0;
  final _streamScrollController = ScrollController();
  final _streamFocusNodes = [
    FocusNode(debugLabel: 'detail_technical_video'),
    FocusNode(debugLabel: 'detail_technical_audio'),
    FocusNode(debugLabel: 'detail_technical_subtitle'),
  ];
  final _fileFocusNode = FocusNode(debugLabel: 'detail_technical_file');
  MediaFileInfo? _info;
  bool _loading = false;
  int _generation = 0;

  bool requestFocus() {
    if (_streamFocusNodes.first.context == null) return false;
    _streamFocusNodes.first.requestFocus();
    return true;
  }

  @override
  void dispose() {
    _streamScrollController.dispose();
    for (final node in _streamFocusNodes) {
      node.dispose();
    }
    _fileFocusNode.dispose();
    super.dispose();
  }

  void _revealStream(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_streamFocusNodes[index].hasFocus || !_streamScrollController.hasClients) return;
      _streamScrollController.animateTo(
        (index * (_cardWidth + _cardGap)).clamp(0.0, _streamScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(MediaDetailTechnicalInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey ||
        oldWidget.sourceId != widget.sourceId ||
        oldWidget.versionIndex != widget.versionIndex ||
        oldWidget.offline != widget.offline ||
        oldWidget.revision != widget.revision ||
        (oldWidget.load == null) != (widget.load == null)) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    _info = null;
    final load = widget.load;
    _loading = !widget.offline && load != null;
    if (!_loading) return;
    MediaFileInfo? info;
    try {
      info = await load!();
    } catch (_) {
      // Missing metadata leaves an honest empty state, never a stale file.
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  MediaFileVersion? get _selectedVersion {
    final versions = _info?.versions;
    if (versions == null || versions.isEmpty) return null;
    if (widget.sourceId != null) {
      for (final version in versions) {
        if (version.id == widget.sourceId) return version;
      }
      // A known source identity must never silently display another file.
      return null;
    }
    final index = widget.versionIndex ?? 0;
    return index >= 0 && index < versions.length ? versions[index] : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = _selectedVersion;
    final streams = [
      if (version != null)
        for (final part in version.parts)
          for (final stream in part.streams)
            if (stream.kind == MediaStreamKind.video ||
                stream.kind == MediaStreamKind.audio ||
                stream.kind == MediaStreamKind.subtitle)
              stream,
    ];
    return Column(
      key: const ValueKey('detail_technical_info'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeading) ...[
          Text(
            t.fileInfo.title,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
        ],
        if (_loading)
          const LinearProgressIndicator()
        else if (version == null)
          Text(t.messages.fileInfoNotAvailable, style: theme.textTheme.bodySmall)
        else ...[
          SingleChildScrollView(
            controller: _streamScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: _cardGap,
              children: [
                for (final kind in [MediaStreamKind.video, MediaStreamKind.audio, MediaStreamKind.subtitle])
                  _streamCard(context, kind, _preferredStream(streams, kind), version),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _fileCard(context, version, _preferredStream(streams, MediaStreamKind.video)),
        ],
      ],
    );
  }

  MediaStreamDetails? _preferredStream(List<MediaStreamDetails> streams, MediaStreamKind kind) {
    final tracks = streams.where((stream) => stream.kind == kind).toList(growable: false);
    return tracks.where((stream) => stream.isSelected == true).firstOrNull ??
        tracks.where((stream) => stream.isDefault == true).firstOrNull ??
        tracks.firstOrNull;
  }

  String? _quality(MediaFileVersion version, MediaStreamDetails? video) {
    final rawResolution = version.videoResolutionLabel;
    final resolution = rawResolution != null && rawResolution.isNotEmpty
        ? resolutionDisplayLabel(rawResolution)
        : resolutionLabelFromDimensions(video?.width ?? version.width, video?.height ?? version.height);
    final codec = video?.codec ?? version.videoCodec;
    final labels = [?resolution, if (codec != null) CodecUtils.formatVideoCodec(codec)];
    return labels.isEmpty ? null : labels.join(' ');
  }

  Widget _streamCard(BuildContext context, MediaStreamKind kind, MediaStreamDetails? stream, MediaFileVersion version) {
    final (title, icon) = switch (kind) {
      MediaStreamKind.video => (t.fileInfo.video, Symbols.videocam_rounded),
      MediaStreamKind.audio => (t.fileInfo.audio, Symbols.music_note_rounded),
      _ => (t.fileInfo.subtitles, Symbols.subtitles_rounded),
    };
    final audioCodec = stream?.codec ?? version.audioCodec;
    final audioTitle = [
      if (audioCodec != null) CodecUtils.formatAudioCodec(audioCodec),
      ?stream?.channelLayout,
    ].join(' ');
    final rows = switch (kind) {
      MediaStreamKind.video => <String, String?>{
        t.explore.detail.technicalTitle: stream?.displayTitle ?? stream?.title ?? _quality(version, stream),
        t.fileInfo.codec: stream?.codec ?? version.videoCodec,
        t.fileInfo.resolution:
            stream?.resolutionFormatted?.replaceAll('x', ' × ') ?? version.resolutionFormatted?.replaceAll('x', ' × '),
        t.fileInfo.aspectRatio: stream?.aspectRatio ?? version.aspectRatioFormatted,
        t.fileInfo.frameRate: stream?.frameRate?.toStringAsFixed(3) ?? version.videoFrameRateLabel,
        t.fileInfo.dynamicRange: stream?.videoRange.label,
        t.fileInfo.colorSpace: stream?.colorSpace,
        t.fileInfo.bitDepth: stream?.bitDepthFormatted,
        t.fileInfo.pixelFormat: stream?.pixelFormat,
      },
      MediaStreamKind.audio => <String, String?>{
        t.explore.detail.technicalTitle: stream?.displayTitle ?? stream?.title ?? audioTitle,
        t.fileInfo.language: stream?.language ?? stream?.languageCode,
        t.explore.detail.channelLayout: stream?.channelLayout,
        t.explore.detail.channelCount: stream?.channels == null ? null : '${stream!.channels} ch',
        t.fileInfo.sampleRate: stream?.sampleRate == null ? null : '${stream!.sampleRate} Hz',
        t.fileInfo.profile: stream?.profile ?? version.audioProfile,
        t.fileInfo.bitrate: stream?.bitrateFormatted,
        t.fileInfo.flagDefault: _boolean(stream?.isDefault),
      },
      _ => <String, String?>{
        t.explore.detail.technicalTitle: stream?.displayTitle ?? stream?.title,
        t.fileInfo.language: stream?.language ?? stream?.languageCode,
        t.explore.detail.subtitleFormat: stream?.codec == null ? null : CodecUtils.formatSubtitleCodec(stream!.codec!),
        t.fileInfo.flagDefault: _boolean(stream?.isDefault),
        t.explore.detail.externalSubtitles: _boolean(stream?.isExternal),
      },
    };
    final index = switch (kind) {
      MediaStreamKind.video => 0,
      MediaStreamKind.audio => 1,
      _ => 2,
    };
    return FocusableWrapper(
      focusNode: _streamFocusNodes[index],
      disableScale: true,
      borderRadius: 16,
      onFocusChange: (focused) {
        if (focused) _revealStream(index);
      },
      onNavigateLeft: () => _streamFocusNodes[index > 0 ? index - 1 : 0].requestFocus(),
      onNavigateRight: () => _streamFocusNodes[index < 2 ? index + 1 : 2].requestFocus(),
      onNavigateDown: _fileFocusNode.requestFocus,
      onNavigateUp: widget.onNavigateUp,
      child: _card(context, title, icon, rows),
    );
  }

  String? _boolean(bool? value) => value == null
      ? null
      : value
      ? t.common.yes
      : t.common.no;

  Widget _fileCard(BuildContext context, MediaFileVersion version, MediaStreamDetails? video) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainerLow;
    final ink = MonoPresentation.artworkTextColors(surface);
    final caption = theme.textTheme.bodySmall?.copyWith(fontSize: 10, height: 1.8, color: ink.caption);
    final summary = [
      ?version.durationFormatted ?? version.parts.firstOrNull?.durationFormatted,
      ?version.totalFileSizeFormatted,
      ?_quality(version, video),
    ].join(' · ');
    return FocusableWrapper(
      focusNode: _fileFocusNode,
      disableScale: true,
      onNavigateUp: _streamFocusNodes.first.requestFocus,
      onNavigateDown: () {},
      child: Container(
        key: const ValueKey('detail_file_info'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: caption?.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: ink.foreground),
            ),
            const SizedBox(height: 7),
            for (final part in version.parts)
              if (part.filePath?.isNotEmpty == true) Text(part.filePath!, textAlign: TextAlign.center, style: caption),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(summary, textAlign: TextAlign.center, style: caption),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, IconData icon, Map<String, String?> rows) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainerLow;
    final ink = MonoPresentation.artworkTextColors(surface);
    final text = theme.textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.9, color: ink.caption);
    return Container(
      width: _cardWidth,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ink.foreground.withValues(alpha: .20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(icon, size: 17, color: ink.foreground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: text?.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.5, color: ink.foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in rows.entries)
            if (entry.value?.isNotEmpty == true) Text('${entry.key}: ${entry.value}', style: text),
          if (rows.values.every((value) => value?.isNotEmpty != true))
            Text(t.messages.fileInfoNotAvailable, style: text),
        ],
      ),
    );
  }
}
