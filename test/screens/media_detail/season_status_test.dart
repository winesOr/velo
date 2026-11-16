import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/screens/media_detail/season_status.dart';

import '../../test_helpers/media_items.dart';

void main() {
  final now = DateTime.utc(2026, 11, 16);
  final show = testMediaItem(kind: MediaKind.show);
  final season = testMediaItem(kind: MediaKind.season, index: 1, leafCount: 12);

  test('uses explicit season or show completion metadata', () {
    for (final raw in [
      {'Status': 'Ended'},
      {'status': 'completed'},
      {'EndDate': '2026-10-01'},
    ]) {
      expect(
        detailSeasonHasEnded(
          season.copyWith(raw: raw),
          show: show,
          seasons: [season],
          now: now,
        ),
        isTrue,
      );
      expect(
        detailSeasonHasEnded(
          season,
          show: show.copyWith(raw: raw),
          seasons: [season],
          now: now,
        ),
        isTrue,
      );
    }
  });

  test('a later premiered regular season establishes the earlier season has ended', () {
    final next = testMediaItem(kind: MediaKind.season, index: 2, originallyAvailableAt: '2026-11-01');
    expect(detailSeasonHasEnded(season, show: show, seasons: [season, next], now: now), isTrue);
    expect(detailSeasonHasEnded(next, show: show, seasons: [season, next], now: now), isFalse);
  });

  test('future dates, specials and missing lifecycle data do not invent completion', () {
    final future = testMediaItem(kind: MediaKind.season, index: 2, originallyAvailableAt: '2027-01-01');
    final specials = testMediaItem(kind: MediaKind.season, index: 0, originallyAvailableAt: '2020-01-01');
    for (final raw in [
      null,
      {'Status': 'Continuing'},
      {'EndDate': '2027-01-01'},
    ]) {
      expect(
        detailSeasonHasEnded(
          season.copyWith(raw: raw),
          show: show,
          seasons: [season, future, specials],
          now: now,
        ),
        isFalse,
      );
    }
    expect(
      detailSeasonHasEnded(
        specials,
        show: show,
        seasons: [
          specials,
          season.copyWith(originallyAvailableAt: '2020-01-01'),
        ],
        now: now,
      ),
      isFalse,
    );
  });
}
