import 'dart:math';

import '../media/media_item.dart';
import '../media/media_kind.dart';

String _identity(MediaItem item) => item.seriesGlobalKey ?? item.globalKey;

Map<String, MediaItem> _candidates(Iterable<MediaItem> items) {
  final result = <String, MediaItem>{};
  for (final item in items) {
    if (item.kind != MediaKind.movie &&
        item.kind != MediaKind.show &&
        item.kind != MediaKind.season &&
        item.kind != MediaKind.episode &&
        item.kind != MediaKind.clip) {
      continue;
    }
    result.putIfAbsent(_identity(item), () => item);
  }
  return result;
}

/// Sample a short banner from the active server's loaded media. Prefer titles
/// outside the previous batch; small libraries can still vary the order.
List<MediaItem> selectHomeHeroItems(Iterable<MediaItem> items, {Random? random, List<String> previousKeys = const []}) {
  final rng = random ?? Random();
  final pool = _candidates(items).values.toList()..shuffle(rng);
  final previous = previousKeys.toSet();
  final fresh = pool.where((item) => !previous.contains(_identity(item)));
  final recent = pool.where((item) => previous.contains(_identity(item)));
  final result = fresh.followedBy(recent).take(6).toList()..shuffle(rng);
  if (result.length > 1 &&
      result.length == previousKeys.length &&
      Iterable<int>.generate(result.length).every((i) => _identity(result[i]) == previousKeys[i])) {
    result.add(result.removeAt(0));
  }
  return List.unmodifiable(result);
}

/// Keep one sample stable through image decoding, progress updates and late
/// hub arrivals and Home re-entry. Only explicit refresh requests a new sample.
class HomeHeroSelection {
  HomeHeroSelection({Random? random}) : _random = random ?? Random();

  final Random _random;
  List<MediaItem> _items = const [];
  List<String> _previousKeys = const [];
  bool _needsResample = true;

  bool get needsResample => _needsResample;

  void reroll() {
    _previousKeys = _items.map(_identity).toList();
    _needsResample = true;
  }

  List<MediaItem> update(Iterable<MediaItem> candidates) {
    final pool = _candidates(candidates);
    if (_needsResample) {
      _items = selectHomeHeroItems(pool.values, random: _random, previousKeys: _previousKeys);
      _needsResample = _items.isEmpty;
    } else {
      final kept = <MediaItem>[for (final item in _items) ?pool[_identity(item)]];
      final keptKeys = kept.map(_identity).toSet();
      final extra = selectHomeHeroItems(
        pool.values.where((item) => !keptKeys.contains(_identity(item))),
        random: _random,
      );
      _items = List.unmodifiable([...kept, ...extra.take(6 - kept.length)]);
    }
    return _items;
  }
}
