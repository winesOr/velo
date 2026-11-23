import '../i18n/strings.g.dart';
import '../media/media_file_info.dart';
import '../media/media_item.dart';
import '../media/media_stream.dart' show MediaStream;
import '../media/media_version.dart';
import 'codec_utils.dart';
import 'resolution_label.dart';
import 'formatters.dart';

enum MediaFormat {
  dolbyVision,
  hdr,
  hdr10,
  hdr10Plus,
  hlg,
  dolbyAtmos,
  dolbyAudio,
  dtsX;

  String get label => switch (this) {
    dolbyVision => t.fileInfo.dolbyVision,
    hdr => t.videoSettings.hdr,
    hdr10 => 'HDR10',
    hdr10Plus => 'HDR10+',
    hlg => 'HLG',
    dolbyAtmos => t.videoSettings.audioOutputDolbyAtmos,
    dolbyAudio => t.videoSettings.audioOutputDolbyAudio,
    dtsX => 'DTS:X',
  };

  /// Wordmark text on badges: brand names, never translated.
  String get shortLabel => switch (this) {
    dolbyVision => 'DV',
    hdr => 'HDR',
    hdr10 => 'HDR10',
    hdr10Plus => 'HDR10+',
    hlg => 'HLG',
    dolbyAtmos => 'ATMOS',
    dolbyAudio => 'DOLBY',
    dtsX => 'DTS:X',
  };

  /// The product word after "DOLBY" for Dolby formats; null for the others.
  String? get dolbyProduct => switch (this) {
    dolbyVision => 'VISION',
    dolbyAtmos => 'ATMOS',
    dolbyAudio => 'AUDIO',
    _ => null,
  };

  /// Formats worth a poster corner: everything except plain Dolby audio,
  /// which nearly every file carries.
  bool get isPremium => this != dolbyAudio;

  bool get isVideo => switch (this) {
    dolbyVision || hdr || hdr10 || hdr10Plus || hlg => true,
    dolbyAtmos || dolbyAudio || dtsX => false,
  };
}

/// Formats for a poster corner: the video format and a premium audio format
/// (Atmos / DTS:X), at most two. Plain Dolby audio is left off posters.
List<MediaFormat> mediaPosterFormats(MediaItem item) => [
  for (final format in mediaFormatsFor(item))
    if (format.isPremium) format,
];

List<MediaFormat> mediaFormatsFor(MediaItem item, {int versionIndex = 0, int? partIndex}) {
  if (!item.kind.isVideo) return const [];
  final version = _selectedVersion(item.mediaVersions, versionIndex);
  if (version == null) return const [];

  final video = _firstStreamOfKind(version, MediaStreamKind.video, partIndex: partIndex);
  final audio = _selectedAudioStream(version, partIndex: partIndex);
  return [
    if (video?.dolbyVision == true) MediaFormat.dolbyVision else if (video?.hdr == true) MediaFormat.hdr,
    if (audio != null) ?_audioFormat(audio.codec, [audio.title, audio.displayTitle]),
  ];
}

List<MediaFormat> fileVideoFormats(MediaStreamDetails? video) {
  if (video == null) return const [];
  final format = switch (video.videoRange) {
    MediaVideoRange.dolbyVision ||
    MediaVideoRange.dolbyVisionHdr10 ||
    MediaVideoRange.dolbyVisionHlg => MediaFormat.dolbyVision,
    MediaVideoRange.hdr => MediaFormat.hdr,
    MediaVideoRange.hdr10 => MediaFormat.hdr10,
    MediaVideoRange.hdr10Plus => MediaFormat.hdr10Plus,
    MediaVideoRange.hlg => MediaFormat.hlg,
    MediaVideoRange.sdr || MediaVideoRange.unknown => null,
  };
  if (video.hasHdr10Plus != true || format == MediaFormat.hdr10Plus) return [?format];
  return [if (format == MediaFormat.dolbyVision) MediaFormat.dolbyVision, MediaFormat.hdr10Plus];
}

MediaFormat? fileAudioFormat(MediaStreamDetails? audio) => audio == null
    ? null
    : _audioFormat(audio.codec, [audio.spatialFormat, audio.profile, audio.displayTitle, audio.title]);

MediaFormat? _audioFormat(String? codec, List<String?> descriptors) {
  final normalizedCodec = codec?.trim().toLowerCase();
  final formats = [normalizedCodec, ...descriptors].whereType<String>();
  if (_hasAtmos(formats) || normalizedCodec == 'eac3-joc') return MediaFormat.dolbyAtmos;
  if (normalizedCodec == 'dtsx' || formats.any((value) => value.toLowerCase().contains('dts:x'))) {
    return MediaFormat.dtsX;
  }
  return switch (normalizedCodec) {
    'ac3' || 'eac3' || 'ec3' || 'truehd' => MediaFormat.dolbyAudio,
    _ => null,
  };
}

List<String> buildMediaQualityLabels(MediaItem item, {int versionIndex = 0}) {
  final version = _selectedVersion(item.mediaVersions, versionIndex);
  if (version == null) return const [];

  final labels = <String>[];
  final resolution = _formatResolution(version);
  if (resolution != null) labels.add(resolution);

  final video = _firstStreamOfKind(version, MediaStreamKind.video);
  if (video?.dolbyVision == true) {
    labels.add(_formatDolbyVision(video!));
  } else if (video?.hdr == true) {
    labels.add('HDR');
  }

  final audio = _selectedAudioStream(version);
  final audioLabel = _formatAudio(audio);
  if (audioLabel != null) labels.add(audioLabel);

  return labels;
}

/// Resolution, video codec, and dynamic range — the picture half of
/// [buildMediaQualityLabels], for a line that names the audio track separately.
List<String> buildMediaVideoLabels(
  MediaItem item, {
  int versionIndex = 0,
  int? partIndex,
  bool includeDynamicRange = true,
}) {
  final version = _selectedVersion(item.mediaVersions, versionIndex);
  if (version == null) return const [];

  final labels = <String>[];
  final resolution = _formatResolution(version);
  if (resolution != null) labels.add(resolution);

  final video = _firstStreamOfKind(version, MediaStreamKind.video, partIndex: partIndex);
  final codec = (video?.codec ?? version.videoCodec)?.trim();
  if (codec != null && codec.isNotEmpty) labels.add(CodecUtils.formatVideoCodec(codec));

  if (includeDynamicRange && video?.dolbyVision == true) {
    labels.add(_formatDolbyVision(video!));
  } else if (includeDynamicRange && video?.hdr == true) {
    labels.add('HDR');
  }

  return labels;
}

String? buildMediaSizeLabel(MediaItem item, {int versionIndex = 0}) {
  final version = _selectedVersion(item.mediaVersions, versionIndex);
  if (version == null || version.parts.isEmpty) return null;

  var totalBytes = 0;
  for (final part in version.parts) {
    final sizeBytes = part.sizeBytes;
    if (sizeBytes == null || sizeBytes <= 0) return null;
    totalBytes += sizeBytes;
  }

  return ByteFormatter.formatBytes(totalBytes);
}

String _formatDolbyVision(MediaStream stream) {
  final profile = stream.dolbyVisionProfile;
  return profile == null || profile <= 0 ? 'DV' : 'DV P$profile';
}

MediaVersion? _selectedVersion(List<MediaVersion>? versions, int versionIndex) {
  if (versions == null || versions.isEmpty) return null;
  if (versionIndex >= 0 && versionIndex < versions.length) {
    return versions[versionIndex];
  }
  return versions.first;
}

String? _formatResolution(MediaVersion version) {
  final raw = version.videoResolution?.trim();
  if (raw != null && raw.isNotEmpty) return resolutionDisplayLabel(raw);

  final fallback = resolutionLabelFromDimensions(version.width, version.height);
  return fallback == null ? null : resolutionDisplayLabel(fallback);
}

MediaStream? _firstStreamOfKind(MediaVersion version, MediaStreamKind kind, {int? partIndex}) {
  if (partIndex != null && partIndex >= 0 && partIndex < version.parts.length) {
    for (final stream in version.parts[partIndex].streams) {
      if (stream.kind == kind) return stream;
    }
    return null;
  }
  for (final part in version.parts) {
    for (final stream in part.streams) {
      if (stream.kind == kind) return stream;
    }
  }
  return null;
}

MediaStream? _selectedAudioStream(MediaVersion version, {int? partIndex}) {
  MediaStream? first;
  MediaStream? containerDefault;
  final parts = version.parts;
  for (final part in partIndex != null && partIndex >= 0 && partIndex < parts.length ? [parts[partIndex]] : parts) {
    for (final stream in part.streams) {
      if (stream.kind != MediaStreamKind.audio) continue;
      first ??= stream;
      if (stream.selected) return stream;
      if (stream.isDefault) containerDefault ??= stream;
    }
  }
  return containerDefault ?? first;
}

String? _formatAudio(MediaStream? stream) {
  if (stream == null) return null;

  final parts = <String>[];
  final codec = stream.codec?.trim();
  if (codec != null && codec.isNotEmpty) parts.add(_formatAudioCodec(codec));

  if (_isAtmos(stream)) {
    parts.add('Atmos');
  } else {
    final channels = CodecUtils.formatAudioChannels(stream.channels);
    if (channels != null) parts.add(channels);
  }

  return parts.isEmpty ? null : parts.join(' ');
}

String _formatAudioCodec(String codec) {
  return switch (codec.toLowerCase()) {
    'eac3' || 'ec3' => 'EAC3',
    'ac3' => 'AC3',
    _ => CodecUtils.formatAudioCodec(codec),
  };
}

bool _isAtmos(MediaStream stream) {
  return _hasAtmos([stream.codec, stream.title, stream.displayTitle].whereType<String>());
}

bool _hasAtmos(Iterable<String> values) => values.any((value) => value.toLowerCase().contains('atmos'));
