import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/services/playback_preparation_cache.dart';

void main() {
  test('shares in-flight preparation and consumes it once', () async {
    final cache = PlaybackPreparationCache<String, int>();
    final pending = Completer<int>();
    var calls = 0;
    final warm = cache.warm('item', () {
      calls++;
      return pending.future;
    });
    await cache.warm('item', () async {
      calls++;
      return 9;
    });
    final taken = cache.take('item');
    expect(cache.take('item'), isNull);
    pending.complete(5);
    await warm;
    expect(await taken, 5);
    expect(calls, 1);
  });

  test('expired, evicted and mismatching preparations cannot be reused', () async {
    var now = DateTime(2026);
    final cache = PlaybackPreparationCache<String, int>(capacity: 1, now: () => now);
    await cache.warm('old', () async => 1);
    await cache.warm('new', () async => 2);
    expect(cache.take('old'), isNull);
    expect(cache.take('different-source'), isNull);
    now = now.add(const Duration(seconds: 30));
    expect(cache.take('new'), isNull);
  });

  test('failed warmup permits a fresh request, late completion cannot revive eviction', () async {
    final cache = PlaybackPreparationCache<String, int>(capacity: 1);
    await cache.warm('failed', () async => throw StateError('offline'));
    expect(cache.take('failed'), isNull);
    await cache.warm('failed', () async => 3);
    expect(await cache.take('failed'), 3);
    final pending = Completer<int>();
    final warm = cache.warm('old', () => pending.future);
    await cache.warm('new', () async => 4);
    pending.complete(1);
    await warm;
    expect(cache.take('old'), isNull);
    expect(await cache.take('new'), 4);
  });
}
