import 'dart:async';

import '../danmaku/danmaku_session.dart';
import '../media/media_item.dart';
import '../media/media_kind.dart';
import '../utils/app_logger.dart';
import '../utils/episode_titles.dart';

/// Owns one route's session so late responses and old route disposal cannot
/// affect the next route's comments.
class DanmakuPlaybackBinding {
  DanmakuPlaybackBinding({DanmakuSession? session}) : _session = session ?? DanmakuSession.instance;

  final DanmakuSession _session;
  StreamSubscription<Duration>? _durationSubscription;
  int? _owner;
  int _revision = 0;
  String? _identity;
  bool _disposed = false;

  void bind(MediaItem item, {required String profileId, bool isLive = false}) {
    if (_disposed) return;
    final next = DanmakuMatchContext(
      profileId: profileId,
      serverId: item.serverId ?? '',
      itemId: item.id,
      title: item.grandparentTitle ?? item.title ?? '',
      seriesId: (item.kind == MediaKind.episode) ? item.grandparentId ?? item.grandparentTitle : null,
      seasonNumber: item.parentIndex,
      episodeNumber: (item.kind == MediaKind.episode) ? effectiveEpisodeIndex(item) : null,
      durationMs: item.durationMs,
    );
    if (!isLive && next.identity == _identity) return;
    final revision = ++_revision;
    _identity = isLive ? null : next.identity;
    if (_owner != null) _session.clear(ownerGeneration: _owner);
    _owner = null;
    if (isLive) return;
    _owner = _session.setMediaContext(next);
    unawaited(_restore(revision));
  }

  Future<void> _restore(int revision) async {
    try {
      await _session.initialize();
      if (_disposed || revision != _revision || _owner == null || !_session.ownsContext(_owner!)) return;
      if (_session.enabled) await _session.autoMatch();
    } catch (_) {
      // Network/settings errors remain on the session for its localized panel.
      appLogger.w('Danmaku initialization failed; video playback remains available');
    }
  }

  void listenToDuration(Stream<Duration> stream) {
    unawaited(_durationSubscription?.cancel());
    _durationSubscription = stream.listen((duration) {
      if (!_disposed && _owner != null && _session.ownsContext(_owner!)) {
        _session.setDuration(duration.inMilliseconds);
      }
    });
  }

  void dispose() {
    _disposed = true;
    ++_revision;
    unawaited(_durationSubscription?.cancel());
    if (_owner != null) _session.clear(ownerGeneration: _owner);
    _owner = null;
  }
}
