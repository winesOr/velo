part of 'download_provider.dart';

/// Invalidates cached snapshots at the mutation boundary, including changes
/// made before an async operation is ready to notify the UI.
class _DownloadMutationMap<K, V> extends MapBase<K, V> {
  _DownloadMutationMap(this._onChanged);

  final VoidCallback _onChanged;
  final Map<K, V> _values = {};

  @override
  V? operator [](Object? key) => _values[key];

  @override
  void operator []=(K key, V value) {
    if (_values.containsKey(key) && _values[key] == value) return;
    _values[key] = value;
    _onChanged();
  }

  @override
  Iterable<K> get keys => _values.keys;

  @override
  bool containsKey(Object? key) => _values.containsKey(key);

  @override
  bool containsValue(Object? value) => _values.containsValue(value);

  @override
  int get length => _values.length;

  @override
  V? remove(Object? key) {
    if (!_values.containsKey(key)) return null;
    final removed = _values.remove(key);
    _onChanged();
    return removed;
  }

  @override
  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    _onChanged();
  }
}

class _DownloadMutationSet<E> extends SetBase<E> {
  _DownloadMutationSet(this._onChanged);

  final VoidCallback _onChanged;
  final Set<E> _values = {};

  @override
  bool add(E value) {
    final changed = _values.add(value);
    if (changed) _onChanged();
    return changed;
  }

  @override
  bool remove(Object? value) {
    final changed = _values.remove(value);
    if (changed) _onChanged();
    return changed;
  }

  @override
  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    _onChanged();
  }

  @override
  bool contains(Object? element) => _values.contains(element);

  @override
  E? lookup(Object? element) => _values.lookup(element);

  @override
  Iterator<E> get iterator => _values.iterator;

  @override
  int get length => _values.length;

  @override
  Set<E> toSet() => Set<E>.of(_values);
}
