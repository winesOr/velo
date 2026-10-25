import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plezy/mpv/models.dart';
import 'package:plezy/services/remote_subtitle_loader.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('subtitle-loader-test-');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  final track = SubtitleTrack.uri('https://example.invalid/sub.srt?token=private', codec: 'srt');

  test('downloads once to a private local URI and removes files after disposal', () async {
    var requests = 0;
    final loader = RemoteSubtitleLoader(
      temporaryDirectory: () async => root,
      clientFactory: () => MockClient((_) async {
        requests++;
        return http.Response('subtitle', 200);
      }),
    );
    final first = loader.load(track);
    expect(loader.load(track), same(first));
    final uri = Uri.parse((await first)!);
    expect(uri.scheme, 'file');
    expect(await File.fromUri(uri).readAsString(), 'subtitle');
    expect(uri.path, isNot(contains('private')));
    expect(requests, 1);
    await loader.dispose();
    expect(await File.fromUri(uri).exists(), isFalse);
  });

  test('fast deadline retries in background and ignores a late first response', () async {
    final lateResponse = Completer<http.Response>();
    var attempts = 0;
    final loader = RemoteSubtitleLoader(
      temporaryDirectory: () async => root,
      fastTimeout: const Duration(milliseconds: 5),
      clientFactory: () => MockClient((_) {
        attempts++;
        return attempts == 1 ? lateResponse.future : Future.value(http.Response('retry', 200));
      }),
    );
    final uri = Uri.parse((await loader.load(track))!);
    expect(attempts, 2);
    lateResponse.complete(http.Response('late', 200));
    await Future<void>.delayed(Duration.zero);
    expect(await File.fromUri(uri).readAsString(), 'retry');
    await loader.dispose();
  });

  test('cancel does not wait for a hung response or create files when it arrives', () async {
    final requested = Completer<void>();
    final response = Completer<http.Response>();
    final loader = RemoteSubtitleLoader(
      temporaryDirectory: () async => root,
      clientFactory: () => MockClient((_) {
        requested.complete();
        return response.future;
      }),
    );
    final download = loader.load(track);
    await requested.future;
    await loader.dispose();
    expect(await download, isNull);
    response.complete(http.Response('late', 200));
    await Future<void>.delayed(Duration.zero);
    expect(await root.list().toList(), isEmpty);
  });

  test('oversized and empty sidecars never get attached', () async {
    for (final body in ['oversized', '']) {
      final loader = RemoteSubtitleLoader(
        temporaryDirectory: () async => root,
        maxBytes: 3,
        clientFactory: () => MockClient((_) async => http.Response(body, 200)),
      );
      expect(await loader.load(track), isNull);
      await loader.dispose();
    }
  });

  test('unavailable temporary storage cannot fail video teardown', () async {
    final loader = RemoteSubtitleLoader(
      temporaryDirectory: () async => throw const FileSystemException('unavailable'),
      clientFactory: () => MockClient((_) async => http.Response('subtitle', 200)),
    );
    expect(await loader.load(track), isNull);
    await loader.dispose();
  });
}
