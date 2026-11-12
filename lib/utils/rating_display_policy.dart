import '../media/media_rating.dart';

/// Presentation limits and defaults; no fetching or backend attribution lives here.
class RatingDisplayPolicy {
  // TODO(VELO-P3-01): Confirm source priority and slot limits with device testing.
  static const defaultSourceOrder = <String>[
    'rottenTomatoesCritic',
    'rottenTomatoesAudience',
    'imdb',
    'tmdb',
    'critic',
    'audience',
    'simkl',
    'mal',
    'anilist',
    'trakt',
    'other',
  ];
  static const detailLimit = 4;
  static const heroLimit = 2;

  const RatingDisplayPolicy({this.sourceOrder = defaultSourceOrder, this.disabledSources = const []});

  final List<String> sourceOrder;
  final List<String> disabledSources;

  static bool isValid(double? value) => value != null && value.isFinite && value > 0 && value <= 10;

  static String canonicalSource(String source) => source == 'rottenTomatoes' ? 'rottenTomatoesCritic' : source;

  static String sourceGroup(String source) {
    final canonical = canonicalSource(source);
    return defaultSourceOrder.contains(canonical) ? canonical : 'other';
  }

  List<String> get orderedSources => [
    ...sourceOrder.map(sourceGroup).toSet(),
    ...defaultSourceOrder.where((source) => !sourceOrder.map(sourceGroup).contains(source)),
  ];

  List<MediaRatingSource> select(List<MediaRatingSource> ratings, {int? limit}) {
    final order = orderedSources;
    final disabled = disabledSources.map(sourceGroup).toSet();
    final seen = <String>{};
    final valid = <MediaRatingSource>[];
    for (final rating in ratings) {
      final source = canonicalSource(rating.source);
      if (!isValid(rating.value) || disabled.contains(sourceGroup(source)) || !seen.add(source)) continue;
      valid.add(MediaRatingSource(source: source, value: rating.value, votes: rating.votes));
    }
    // The original index breaks ties so unknown sources keep their server order.
    final indexed = valid.indexed.toList();
    indexed.sort((a, b) {
      final priority = order.indexOf(sourceGroup(a.$2.source)).compareTo(order.indexOf(sourceGroup(b.$2.source)));
      return priority == 0 ? a.$1.compareTo(b.$1) : priority;
    });
    final sorted = indexed.map((entry) => entry.$2);
    return (limit == null ? sorted : sorted.take(limit < 0 ? 0 : limit)).toList(growable: false);
  }
}
