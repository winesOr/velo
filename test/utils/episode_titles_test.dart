import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/utils/episode_titles.dart';

import '../test_helpers/media_items.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  group('looksLikeReleaseFileName', () {
    test('flags release-group bracket names and file names', () {
      expect(
        looksLikeReleaseFileName('[GM-Team][国漫][一念永恒 第4季][Yi Nian Yong Heng 4th Season][2026][04][AVC][GB][1080P]'),
        isTrue,
      );
      expect(looksLikeReleaseFileName('Show.S01E02.1080p.WEB-DL.x264'), isTrue);
      expect(looksLikeReleaseFileName('episode-02.mkv'), isTrue);
    });

    test('keeps real episode names', () {
      expect(looksLikeReleaseFileName('新的旅程'), isFalse);
      expect(looksLikeReleaseFileName('The One Where It Begins'), isFalse);
      expect(looksLikeReleaseFileName('【正片】第4期上：团结的沙漠之旅'), isFalse);
      expect(looksLikeReleaseFileName(''), isFalse);
    });
  });

  group('episodeNumberFromReleaseName', () {
    test('takes the last short bracketed number, skipping the year', () {
      expect(
        episodeNumberFromReleaseName('[GM-Team][国漫][一念永恒 第4季][Yi Nian Yong Heng 4th Season][2026][04][AVC][GB][1080P]'),
        4,
      );
    });

    test('ignores real titles and names without a bracketed number', () {
      expect(episodeNumberFromReleaseName('第 4 集 [04]'), isNull);
      expect(episodeNumberFromReleaseName('Show.S01E02.1080p.WEB-DL.x264'), isNull);
      expect(episodeNumberFromReleaseName(null), isNull);
    });

    test('fills the number when the server has none', () {
      final ep = testMediaItem(kind: MediaKind.episode, title: '[GM-Team][一念永恒][2026][03][AVC][1080P]');
      expect(effectiveEpisodeIndex(ep), 3);
      expect(episodeDisplayTitle(ep), t.common.episodeNumber(number: 3));
    });
  });

  group('episodeDisplayTitle', () {
    test('prefixes the number to a real title', () {
      final ep = testMediaItem(kind: MediaKind.episode, title: 'Pilot', index: 1);
      expect(episodeDisplayTitle(ep), '1. Pilot');
    });

    test('replaces a release file name with the episode number', () {
      final ep = testMediaItem(kind: MediaKind.episode, title: '[GM-Team][国漫][一念永恒][04][AVC][1080P]', index: 4);
      expect(episodeDisplayTitle(ep), t.common.episodeNumber(number: 4));
    });

    test('keeps a file name when there is no number to show instead', () {
      final ep = testMediaItem(kind: MediaKind.episode, title: '[A][B][C]', index: null);
      expect(episodeDisplayTitle(ep), '[A][B][C]');
    });

    test('a genuine episode 0 keeps its number', () {
      final ep = testMediaItem(kind: MediaKind.episode, title: 'Prologue', index: 0);
      expect(episodeDisplayTitle(ep), '0. Prologue');
    });
  });

  group('compactEpisodeLabel', () {
    test('season and episode', () {
      expect(compactEpisodeLabel(season: 4, episode: 7), 'S4E7');
    });

    test('a missing episode number is not shown as 0', () {
      expect(compactEpisodeLabel(season: 4, episode: null), 'S4');
    });

    test('episode only, or nothing', () {
      expect(compactEpisodeLabel(season: null, episode: 3), t.common.episodeNumber(number: 3));
      expect(compactEpisodeLabel(), '');
    });
  });
}
