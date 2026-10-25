import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/danmaku/danmaku_api_client.dart';
import 'package:plezy/danmaku/danmaku_matcher.dart';

DanmakuAnime _work(String id, String title) => DanmakuAnime(sourceId: 's', animeId: id, title: title);

void main() {
  test('query text carries the episode; the API keyword does not', () {
    expect(danmakuDisplayQuery('剧名 第2季', 5), '剧名 第2季 第5集');
    expect(danmakuDisplayQuery('Movie', null), 'Movie');
    expect(parseDanmakuQuery(' 剧名 第2季 第5集 '), (keyword: '剧名 第2季', episode: 5));
    expect(parseDanmakuQuery('剧名 第12话'), (keyword: '剧名', episode: 12));
    expect(parseDanmakuQuery('剧名'), (keyword: '剧名', episode: null));
    // Too little left for a keyword: keep the text as typed.
    expect(parseDanmakuQuery('第5集'), (keyword: '第5集', episode: null));
  });

  test('the matching season ranks first and wins without asking', () {
    final works = [_work('1', '进击的巨人'), _work('3', '进击的巨人 第三季'), _work('2', '进击的巨人 第2季')];
    final ranked = rankDanmakuWorks(works, '进击的巨人 第2季');
    expect(ranked.first.animeId, '2');
    expect(confidentDanmakuWork(works, '进击的巨人 第2季')?.animeId, '2');
    // Untitled season 1 matches the bare title.
    expect(confidentDanmakuWork(works, '进击的巨人 第1季')?.animeId, '1');
  });

  test('ambiguous or unrelated candidates are left to the user', () {
    expect(confidentDanmakuWork([_work('1', 'Alpha'), _work('2', 'Beta')], 'Gamma'), isNull);
    expect(confidentDanmakuWork([_work('1', 'Show'), _work('2', 'Show')], 'Show'), isNull);
    expect(confidentDanmakuWork([_work('1', 'Anything')], 'Show')?.animeId, '1');
    expect(confidentDanmakuWork(const [], 'Show'), isNull);
  });

  test('the plain work outranks its spin-off', () {
    final works = [_work('sp', 'Show 特别篇 总集篇'), _work('tv', 'Show')];
    expect(rankDanmakuWorks(works, 'Show').first.animeId, 'tv');
  });
}
