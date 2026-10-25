import 'dart:io';

import '../../media/media_item.dart';
import '../../media/media_server_client.dart';
import 'dlna_device.dart';
import 'dlna_http.dart';
import 'dlna_sender.dart';

/// Resolves the original server file, never the phone's active playback URL.
/// No transcode session or local HTTP proxy is created for the receiver.
class CastMediaResolver {
  const CastMediaResolver();

  Future<DlnaMedia> resolve({
    required MediaServerClient client,
    required MediaItem item,
    required Duration position,
    int mediaIndex = 0,
    String? mediaSourceId,
  }) async {
    final target = await client.resolveExternalPlayback(
      item,
      mediaIndex: mediaIndex,
      mediaSourceId: mediaSourceId,
      position: position,
    );
    if (target == null || target.partTimeline != null) throw const DlnaException(DlnaFailure.unsupportedSource);
    final url = Uri.tryParse(target.url);
    if (url == null || !isIndependentCastUrl(url)) throw const DlnaException(DlnaFailure.unsupportedSource);
    return DlnaMedia(
      url: url,
      title: item.displayTitle,
      position: position.isNegative ? Duration.zero : position,
      duration: item.durationMs == null ? null : Duration(milliseconds: item.durationMs!),
    );
  }
}

bool isIndependentCastUrl(Uri uri) {
  if (!isDlnaHttpUri(uri)) return false;
  final host = uri.host.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), '');
  final address = InternetAddress.tryParse(host);
  if (host == 'localhost' || host.endsWith('.localhost') || address?.isLoopback == true) return false;
  if (host == '0.0.0.0' || host == '::' || host.startsWith('::ffff:127.')) return false;
  final path = uri.path.toLowerCase();
  if (path.contains('/transcode/') || path.endsWith('.m3u8') || path.endsWith('.mpd')) return false;
  if (RegExp(r'\.(iso|img|bdmv)$').hasMatch(path)) return false;
  return true;
}
