import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../mpv/models.dart';
import '../utils/codec_utils.dart';
import '../utils/platform_http_client_io.dart';

/// Downloads sidecars independently of the video demuxer. Each playback owns
/// one loader and its private temporary directory; URLs never become filenames.
class RemoteSubtitleLoader {
  RemoteSubtitleLoader({
    http.Client Function()? clientFactory,
    Future<Directory> Function()? temporaryDirectory,
    this.fastTimeout = const Duration(milliseconds: 1500),
    this.retryTimeout = const Duration(seconds: 20),
    this.maxBytes = 32 * 1024 * 1024,
  }) : _clientFactory = clientFactory ?? createPlatformClient,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final http.Client Function() _clientFactory;
  final Future<Directory> Function() _temporaryDirectory;
  final Duration fastTimeout;
  final Duration retryTimeout;
  final int maxBytes;
  final _cancelled = Completer<void>();
  final _aborts = <Completer<void>>{};
  final _downloads = <String, Future<String?>>{};
  Future<void> _tail = Future<void>.value();
  Future<Directory>? _directory;
  Future<void>? _disposal;
  int _fileIndex = 0;

  Future<void> get cancelled => _cancelled.future;

  static bool isRemote(SubtitleTrack track) {
    final uri = Uri.tryParse(track.uri ?? '');
    return uri?.scheme == 'http' || uri?.scheme == 'https';
  }

  /// Serial, deduplicated work bounds both memory and requests. Callers queue
  /// selected tracks first; nothing in this future gates opening the video.
  Future<String?> load(SubtitleTrack track) {
    if (_cancelled.isCompleted || !isRemote(track)) return Future<String?>.value();
    return _downloads.putIfAbsent(track.uri!, () {
      final result = _tail.then((_) async {
        if (_cancelled.isCompleted) return null;
        final fast = await _attempt(track, fastTimeout);
        if (fast != null || _cancelled.isCompleted) return fast;
        return _attempt(track, retryTimeout);
      });
      _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
      return result;
    });
  }

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
    for (final abort in _aborts.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    cancel();
    await _tail;
    try {
      final directory = await _directory;
      if (directory != null && await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {
      // Optional cache cleanup must not mask the player's teardown result.
    }
  }

  Future<String?> _attempt(SubtitleTrack track, Duration timeout) async {
    final abort = Completer<void>();
    http.Client? client;
    _aborts.add(abort);
    try {
      client = _clientFactory();
      return await Future.any([
        _download(client, abort, track),
        _cancelled.future.then<String?>((_) => null),
      ]).timeout(timeout);
    } catch (_) {
      // A missing/slow subtitle is optional; retry it without logging signed URLs.
      return null;
    } finally {
      if (!abort.isCompleted) abort.complete();
      _aborts.remove(abort);
      client?.close();
    }
  }

  Future<String?> _download(http.Client client, Completer<void> abort, SubtitleTrack track) async {
    File? partial;
    IOSink? sink;
    try {
      final response = await client.send(
        http.AbortableRequest('GET', Uri.parse(track.uri!), abortTrigger: abort.future),
      );
      if (response.statusCode != 200 || (response.contentLength ?? 0) > maxBytes) return null;
      if (_cancelled.isCompleted || abort.isCompleted) return null;
      final directory = await (_directory ??= _temporaryDirectory().then(
        (root) => root.createTemp('plezy-subtitles-'),
      ));
      if (_cancelled.isCompleted || abort.isCompleted) return null;
      final extension = track.isContainer ? 'mks' : CodecUtils.getSubtitleExtension(track.codec ?? 'srt');
      final safeExtension = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(extension) ? extension : 'srt';
      final destination = File(path.join(directory.path, '${_fileIndex++}.$safeExtension'));
      partial = File('${destination.path}.partial');
      sink = partial.openWrite();
      var bytes = 0;
      await for (final chunk in response.stream) {
        if (_cancelled.isCompleted || abort.isCompleted) return null;
        bytes += chunk.length;
        if (bytes > maxBytes) return null;
        sink.add(chunk);
      }
      await sink.close();
      sink = null;
      if (bytes == 0 || _cancelled.isCompleted || abort.isCompleted) return null;
      await partial.rename(destination.path);
      return destination.uri.toString();
    } finally {
      await sink?.close();
      if (partial != null && await partial.exists()) await partial.delete();
    }
  }
}
