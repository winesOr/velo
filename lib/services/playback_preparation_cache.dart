import 'dart:async';

/// A small, single-consumption cache for speculative, side-effect-free work.
/// Errors retire their entry; evicted/in-flight completions cannot repopulate it.
class PlaybackPreparationCache<K, V> {
  PlaybackPreparationCache({this.capacity = 4, this.ttl = const Duration(seconds: 30), DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final int capacity;
  final Duration ttl;
  final DateTime Function() _now;
  final Map<K, ({DateTime expires, Future<V> future})> _entries = {};

  Future<void> warm(K key, Future<V> Function() load) async {
    _prune();
    if (_entries.containsKey(key) || capacity <= 0) return;
    while (_entries.length >= capacity) {
      _entries.remove(_entries.keys.first);
    }
    final future = Future<V>.sync(load);
    _entries[key] = (expires: _now().add(ttl), future: future);
    try {
      await future;
    } catch (_) {
      if (identical(_entries[key]?.future, future)) _entries.remove(key);
    }
  }

  Future<V>? take(K key) {
    _prune();
    return _entries.remove(key)?.future;
  }

  void clear() => _entries.clear();

  void _prune() {
    final now = _now();
    _entries.removeWhere((_, entry) => !now.isBefore(entry.expires));
  }
}
