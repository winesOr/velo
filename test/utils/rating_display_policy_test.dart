import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_rating.dart';
import 'package:plezy/utils/rating_display_policy.dart';
import 'package:plezy/widgets/media_rating_badge.dart';

void main() {
  const scores = [
    MediaRatingSource(source: 'tmdb', value: 7.9),
    MediaRatingSource(source: 'imdb', value: 8.1),
    MediaRatingSource(source: 'rottenTomatoesAudience', value: 8.8),
    MediaRatingSource(source: 'rottenTomatoesCritic', value: 9.2),
    MediaRatingSource(source: 'simkl', value: 8.2),
  ];

  test('default order and surface limits use real available sources', () {
    final selected = const RatingDisplayPolicy().select(scores, limit: RatingDisplayPolicy.detailLimit);
    expect(selected.map((score) => score.source), ['rottenTomatoesCritic', 'rottenTomatoesAudience', 'imdb', 'tmdb']);
    expect(const RatingDisplayPolicy().select(scores, limit: RatingDisplayPolicy.heroLimit), hasLength(2));
  });

  test('custom order and disabled sources use the next available score', () {
    const policy = RatingDisplayPolicy(
      sourceOrder: ['tmdb', 'imdb'],
      disabledSources: ['tmdb', 'rottenTomatoesCritic'],
    );
    expect(policy.select(scores, limit: 1).single.source, 'imdb');
  });

  test('invalid numbers, aliases and duplicates cannot add misleading badges', () {
    final selected = const RatingDisplayPolicy().select([
      const MediaRatingSource(source: 'imdb', value: double.nan),
      const MediaRatingSource(source: 'imdb', value: 8.1),
      const MediaRatingSource(source: 'imdb', value: 9.1),
      const MediaRatingSource(source: 'tmdb', value: double.infinity),
      const MediaRatingSource(source: 'simkl', value: 10.1),
      const MediaRatingSource(source: 'mal', value: 0),
      const MediaRatingSource(source: 'anilist', value: -1),
      const MediaRatingSource(source: 'rottenTomatoes', value: 8.0),
      const MediaRatingSource(source: 'rottenTomatoesCritic', value: 9.0),
      const MediaRatingSource(source: 'future-source', value: 7.0),
    ]);
    expect(selected.map((score) => score.source), ['rottenTomatoesCritic', 'imdb', 'future-source']);
    expect(selected.map((score) => score.value), [8.0, 8.1, 7.0]);
    expect(const RatingDisplayPolicy(disabledSources: ['other']).select(selected), hasLength(2));
  });

  test('valid personal ratings win without changing their 0–10 unit', () {
    const item = MediaItem.plex(id: 'film', kind: MediaKind.movie, title: 'Film', userRating: 9, ratings: scores);
    final score = mediaCardRatingFor(item, policy: const RatingDisplayPolicy());
    expect(score?.source, 'personal');
    expect(score?.value, 9);
    expect(
      mediaCardRatingFor(item.copyWith(userRating: 12), policy: const RatingDisplayPolicy())?.source,
      'rottenTomatoesCritic',
    );
  });

  test('episode ratings never mix with show ratings, even after filtering', () {
    const show = MediaItem.plex(id: 'show', kind: MediaKind.show, title: 'Show', ratings: scores);
    const episode = MediaItem.plex(
      id: 'episode',
      kind: MediaKind.episode,
      title: 'Episode',
      ratings: [MediaRatingSource(source: 'imdb', value: 6.1)],
    );
    final own = mediaRatingsFor(episode, fallbackItem: show);
    expect(own.map((score) => score.value), [6.1]);
    expect(const RatingDisplayPolicy(disabledSources: ['imdb']).select(own), isEmpty);
    const empty = MediaItem.plex(id: 'empty', kind: MediaKind.episode, title: 'Empty');
    expect(mediaRatingsFor(empty, fallbackItem: show), hasLength(5));
  });
}
