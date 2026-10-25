import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../focus/focusable_wrapper.dart';
import '../i18n/strings.g.dart';
import '../media/media_file_info.dart';
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
    this.showHeading = true,
  });

  final String targetKey;
  final String title;
  final Future<MediaFileInfo?> Function()? load;
  final String? sourceId;
  final int? versionIndex;
  final bool offline;
  final int revision;
  final bool showHeading;

  @override
  State<MediaDetailTechnicalInfo> createState() => _MediaDetailTechnicalInfoState();
}

class _MediaDetailTechnicalInfoState extends State<MediaDetailTechnicalInfo> {
  MediaFileInfo? _info;
  bool _loading = false;
  int _generation = 0;

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
        Text(widget.title, style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        if (_loading)
          const LinearProgressIndicator()
        else if (version == null)
          Text(t.messages.fileInfoNotAvailable, style: theme.textTheme.bodySmall)
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final streams = [
                for (final part in version.parts)
                  for (final stream in part.streams)
                    if (stream.kind == MediaStreamKind.video ||
                        stream.kind == MediaStreamKind.audio ||
                        stream.kind == MediaStreamKind.subtitle)
                      stream,
              ];
              if (streams.isEmpty) {
                return _card(context, t.fileInfo.video, Symbols.videocam_rounded, {
                  t.fileInfo.codec: version.videoCodec,
                  t.fileInfo.resolution: version.resolutionFormatted,
                  t.fileInfo.bitrate: version.bitrateFormatted,
                  t.fileInfo.profile: version.videoProfile,
                }, fullWidth: true);
              }
              final columns = constraints.maxWidth >= 520
                  ? 3
                  : constraints.maxWidth >= 330
                  ? 2
                  : 1;
              final cardWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final stream in streams) _streamCard(context, stream, width: cardWidth)],
              );
            },
          ),
          const SizedBox(height: 14),
          for (final part in version.parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _card(context, part.fileName ?? t.fileInfo.file, Symbols.description_rounded, {
                t.fileInfo.file: part.filePath,
                t.fileInfo.container: part.container ?? version.container,
                t.fileInfo.size: part.fileSizeFormatted,
                t.fileInfo.duration: part.durationFormatted ?? version.durationFormatted,
              }, fullWidth: true),
            ),
        ],
      ],
    );
  }

  Widget _streamCard(BuildContext context, MediaStreamDetails stream, {double? width}) {
    final (title, icon) = switch (stream.kind) {
      MediaStreamKind.video => (t.fileInfo.video, Symbols.videocam_rounded),
      MediaStreamKind.audio => (t.fileInfo.audio, Symbols.music_note_rounded),
      _ => (t.fileInfo.subtitles, Symbols.subtitles_rounded),
    };
    return _card(context, stream.displayTitle ?? '$title ${stream.ordinal}', icon, {
      t.fileInfo.codec: stream.codec,
      t.fileInfo.language: stream.language ?? stream.languageCode,
      t.fileInfo.resolution: stream.resolutionFormatted,
      t.fileInfo.frameRate: stream.frameRateFormatted,
      t.fileInfo.aspectRatio: stream.aspectRatio,
      t.fileInfo.profile: stream.profile,
      t.fileInfo.bitrate: stream.bitrateFormatted,
      t.fileInfo.bitDepth: stream.bitDepthFormatted,
      t.fileInfo.pixelFormat: stream.pixelFormat,
      t.fileInfo.dynamicRange: stream.videoRange.label,
      t.fileInfo.colorSpace: stream.colorSpace,
      t.fileInfo.colorPrimaries: stream.colorPrimaries,
      t.fileInfo.colorTransfer: stream.colorTransfer,
      t.fileInfo.channels: stream.channelsFormatted,
      t.fileInfo.sampleRate: stream.sampleRateFormatted,
      t.fileInfo.flagDefault: stream.isDefault == null ? null : (stream.isDefault! ? t.common.yes : t.common.no),
    }, width: width);
  }

  Widget _card(
    BuildContext context,
    String title,
    IconData icon,
    Map<String, String?> rows, {
    bool fullWidth = false,
    double? width,
  }) {
    final theme = Theme.of(context);
    final text = theme.textTheme.bodySmall?.copyWith(height: 1.7);
    return FocusableWrapper(
      disableScale: true,
      child: Container(
        width: fullWidth ? double.infinity : (width ?? 235),
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: .065),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: .045)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(icon, size: 17),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: text)),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              if (entry.value?.isNotEmpty == true) Text('${entry.key}: ${entry.value}', style: text),
          ],
        ),
      ),
    );
  }
}
