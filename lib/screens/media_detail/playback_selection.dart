import '../../media/media_source_info.dart';
import '../../media/media_version.dart';
import '../../mpv/models.dart';
import '../../services/playback_subtitle_resolver.dart';

/// A menu result is meaningful only for the item, encode and part that
/// advertised it. Stream ids alone are commonly reused by other sources.
typedef DetailTrackScope = ({String itemKey, String? sourceId, int? mediaIndex, int? partId, int? partIndex});
typedef DetailTrackOption = ({DetailTrackScope scope, int? streamId});

DetailTrackScope detailTrackScope(String itemKey, MediaSourceInfo source) => (
  itemKey: itemKey,
  sourceId: source.mediaSourceId,
  mediaIndex: source.mediaIndex,
  partId: source.partId,
  partIndex: source.partIndex,
);

/// Transient detail choices. Stream ids only belong to the source/part that
/// advertised them; they must never leak to another episode or version.
class DetailPlaybackSelection {
  String? versionId;
  String? versionSignature;
  String? _sourceKey;
  int? audioId;
  int? subtitleId;
  bool subtitlesOff = false;

  bool get hasTrackChoice => audioId != null || subtitleId != null || subtitlesOff;

  void chooseVersion(MediaVersion version) {
    versionId = version.id;
    versionSignature = version.signature;
    clearTracks();
    _sourceKey = null;
  }

  int? versionIndex(List<MediaVersion>? versions) {
    if (versions == null || versionId == null) return null;
    final byId = versions.indexWhere((version) => version.id == versionId);
    if (byId >= 0) return byId;
    // An id disappearing is not an invitation to select another encode.
    return null;
  }

  void bindSource(MediaSourceInfo? source) {
    if (source == null) {
      _sourceKey = null;
      clearTracks();
      return;
    }
    final key = '${source.mediaSourceId}:${source.mediaIndex}:${source.partId}:${source.partIndex}';
    if (_sourceKey != key) clearTracks();
    _sourceKey = key;
    if (audioId != null && !source.audioTracks.any((track) => track.id == audioId)) audioId = null;
    if (subtitleId != null && !source.subtitleTracks.any((track) => track.id == subtitleId)) subtitleId = null;
  }

  void clearTracks() {
    audioId = null;
    subtitleId = null;
    subtitlesOff = false;
  }

  AudioTrack? audioFor(MediaSourceInfo? source) {
    if (source == null || audioId == null) return null;
    for (final track in source.audioTracks) {
      if (track.id == audioId) return PlaybackSubtitleResolver.audioTrackForSource(track);
    }
    return null;
  }

  SubtitleTrack? subtitleFor(MediaSourceInfo? source) {
    if (source == null) return null;
    if (subtitlesOff) return SubtitleTrack.off;
    for (final track in source.subtitleTracks) {
      if (track.id == subtitleId) return PlaybackSubtitleResolver.subtitleTrackForSource(track);
    }
    return null;
  }
}
