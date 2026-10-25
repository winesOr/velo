import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/danmaku/danmaku_comment.dart';
import 'package:plezy/danmaku/danmaku_filter.dart';
import 'package:plezy/danmaku/danmaku_session.dart';
import 'package:plezy/danmaku/danmaku_settings.dart';
import 'package:plezy/danmaku/danmaku_settings_repository.dart';

void main() {
  test('rolling dedup keeps first item, compares trimmed text and preserves modes', () {
    const data = [
      DanmakuComment(timeMs: 0, text: ' hello '),
      DanmakuComment(timeMs: 1000, text: 'hello'),
      DanmakuComment(timeMs: 1500, text: 'hello'),
      DanmakuComment(timeMs: 1500, text: 'hello', mode: 5),
      DanmakuComment(timeMs: 2501, text: 'hello'),
    ];
    final filtered = filterDanmaku(data, blockedKeywords: [], mergeDuplicates: true);
    expect(filtered.map((c) => (c.timeMs, c.mode)), [(0, 1), (1500, 5), (2501, 1)]);
    expect(data, hasLength(5));
  });

  test('keywords are literal substrings, not regular expressions', () {
    const data = [DanmakuComment(timeMs: 0, text: '[spoiler]'), DanmakuComment(timeMs: 1, text: 'safe')];
    expect(filterDanmaku(data, blockedKeywords: ['['], mergeDuplicates: false).single.text, 'safe');
  });

  test('v1 settings without new fields migrate to presentation defaults', () {
    final old = {'version': 1, 'sources': <Object>[]};
    final restored = DanmakuSettings.fromJson(old);
    expect(restored.speed, 1);
    expect(restored.preventOverlap, isTrue);
    expect(restored.mergeDuplicates, isFalse);
    expect(restored.blockedKeywords, isEmpty);
  });

  test('invalid persisted bounds reject corruption', () {
    for (final patch in [
      {'speed': 0},
      {'speed': double.nan},
      {'maxOnScreen': 0},
      {'scrollLines': 31},
      {'bottomLines': -1},
      {
        'blockedKeywords': [''],
      },
    ]) {
      expect(() => DanmakuSettings.fromJson({...const DanmakuSettings().toJson(), ...patch}), throwsFormatException);
    }
  });

  test('filters are reversible, persisted and do not conflate density with heatmap data', () async {
    String? stored;
    final repository = DanmakuSettingsRepository(
      read: () async => stored,
      write: (v) async => stored = v,
      protect: (v) async => v,
      reveal: (v) async => v,
    );
    final session = DanmakuSession.forTesting(repository: repository);
    await session.initialize();
    session.load(const [
      DanmakuComment(timeMs: 0, text: 'spam'),
      DanmakuComment(timeMs: 1000, text: 'hello'),
      DanmakuComment(timeMs: 1500, text: 'hello'),
    ], sourceLabel: 'local');
    await session.updateStyle(
      blockedKeywords: [' spam ', 'spam'],
      mergeDuplicates: true,
      speed: 1.5,
      maxOnScreen: 1,
      scrollLines: 2,
      topLines: 0,
      bottomLines: 1,
    );
    expect(session.comments, hasLength(1));
    expect(session.presentation.blockedKeywords, ['spam']);
    final version = session.dataVersion;
    await session.updateStyle(maxOnScreen: 20);
    expect(session.dataVersion, version);
    final restored = DanmakuSession.forTesting(repository: repository);
    await restored.initialize();
    expect(restored.presentation.speed, 1.5);
    expect(restored.presentation.topLines, 0);
    expect(restored.presentation.blockedKeywords, ['spam']);
    await session.updateStyle(blockedKeywords: [], mergeDuplicates: false);
    expect(session.comments, hasLength(3));
    expect(session.dataVersion, greaterThan(version));
    await session.updateStyle(offsetMs: -1000);
    expect(session.comments.map((c) => c.timeMs), [0, 500]);
  });

  test('failed settings writes preserve data and presentation', () async {
    var fail = false;
    final session = DanmakuSession.forTesting(
      repository: DanmakuSettingsRepository(
        read: () async => null,
        write: (_) async {
          if (fail) throw StateError('disk');
        },
        protect: (v) async => v,
        reveal: (v) async => v,
      ),
    );
    await session.initialize();
    session.load(const [DanmakuComment(timeMs: 0, text: 'keep')], sourceLabel: 'local');
    fail = true;
    await expectLater(session.updateStyle(blockedKeywords: ['keep']), throwsStateError);
    expect(session.comments.single.text, 'keep');
    expect(session.presentation.blockedKeywords, isEmpty);
    await expectLater(session.updateStyle(scrollLines: -1), throwsFormatException);
    expect(session.presentation.scrollLines, 12);
  });
}
