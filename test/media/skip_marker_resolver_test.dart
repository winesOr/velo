import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_source_info.dart';
import 'package:plezy/media/skip_marker_resolver.dart';

void main() {
  MediaMarker marker(String type, int startMs, int endMs, {String source = 'server'}) =>
      MediaMarker(id: 0, type: type, startTimeOffset: startMs, endTimeOffset: endMs, source: source);

  group('resolveSkipMarkers priority', () {
    test('server marker wins over aniskip and custom for the same type', () {
      final resolved = resolveSkipMarkers(
        serverMarkers: [marker('intro', 30000, 120000)],
        aniskipMarkers: [marker('intro', 34540, 124540, source: 'aniskip')],
        customIntroSeconds: 90,
        durationMs: 1420000,
      );
      expect(resolved.where((m) => m.type == 'intro').single.source, 'server');
      expect(resolved.where((m) => m.type == 'intro').single.startTimeOffset, 30000);
    });

    test('aniskip fills a type the server did not provide', () {
      final resolved = resolveSkipMarkers(
        serverMarkers: [marker('intro', 30000, 120000)],
        aniskipMarkers: [marker('credits', 1330583, 1421210, source: 'aniskip')],
      );
      expect(resolved.where((m) => m.type == 'credits').single.source, 'aniskip');
    });

    test('aniskip wins over custom seconds, custom beats nothing', () {
      final resolved = resolveSkipMarkers(
        aniskipMarkers: [marker('intro', 34540, 124540, source: 'aniskip')],
        customIntroSeconds: 90,
        customEndSeconds: 30,
        durationMs: 1420000,
      );
      expect(resolved.where((m) => m.type == 'intro').single.source, 'aniskip');
      expect(resolved.where((m) => m.type == 'credits').single.source, 'custom');
    });

    test('aniskip-only types pass through untouched', () {
      final resolved = resolveSkipMarkers(
        serverMarkers: [marker('intro', 30000, 120000)],
        aniskipMarkers: [marker('recap', 0, 20000, source: 'aniskip')],
      );
      expect(resolved.where((m) => m.type == 'recap'), hasLength(1));
    });

    test('all-empty input returns the server list unchanged', () {
      const server = <MediaMarker>[];
      expect(resolveSkipMarkers(serverMarkers: server), isEmpty);
      expect(resolveSkipMarkers(serverMarkers: server), same(server));
    });

    test('result is sorted by start time across types', () {
      final resolved = resolveSkipMarkers(
        serverMarkers: [marker('credits', 1300000, 1400000)],
        customIntroSeconds: 60,
        durationMs: 1400000,
      );
      expect(resolved.map((m) => m.startTimeOffset), [0, 1300000]);
    });
  });

  group('customSkipMarkers synthesis', () {
    test('intro spans [0, N) and credits spans [duration - M, duration)', () {
      final markers = customSkipMarkers(introSeconds: 90, endSeconds: 30, durationMs: 1420000);
      expect(markers, hasLength(2));
      expect(markers[0].type, 'intro');
      expect(markers[0].source, 'custom');
      expect(markers[0].startTimeOffset, 0);
      expect(markers[0].endTimeOffset, 90000);
      expect(markers[1].type, 'credits');
      expect(markers[1].startTimeOffset, 1420000 - 30000);
      expect(markers[1].endTimeOffset, 1420000);
    });

    test('zero seconds produce no marker on that side', () {
      expect(customSkipMarkers(introSeconds: 0, endSeconds: 0, durationMs: 1000), isEmpty);
      expect(customSkipMarkers(introSeconds: 90, endSeconds: 0, durationMs: 1000), hasLength(1));
      expect(customSkipMarkers(introSeconds: 0, endSeconds: 30, durationMs: 1000), hasLength(1));
    });

    test('credits needs a known duration', () {
      expect(customSkipMarkers(introSeconds: 0, endSeconds: 30), isEmpty);
    });

    test('clamps when seconds exceed the duration', () {
      final markers = customSkipMarkers(introSeconds: 500, endSeconds: 500, durationMs: 60000);
      expect(markers[0].endTimeOffset, 60000);
      expect(markers[1].startTimeOffset, 0);
      expect(markers[1].endTimeOffset, 60000);
    });

    test('synthetic ids never collide with server index ids', () {
      final markers = customSkipMarkers(introSeconds: 10, endSeconds: 10, durationMs: 60000);
      expect(markers.every((m) => m.id < 0), isTrue);
    });
  });
}
