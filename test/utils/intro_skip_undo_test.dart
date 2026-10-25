import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_source_info.dart';
import 'package:plezy/utils/intro_skip_undo.dart';

void main() {
  final intro = MediaMarker(id: 1, type: 'intro', startTimeOffset: 10000, endTimeOffset: 80000);
  test('undo restores the exact position once and suppresses that interval', () {
    final state = IntroSkipUndo();
    state.offer(intro, const Duration(seconds: 13));
    expect(state.available, isTrue);
    expect(state.take(), const Duration(seconds: 13));
    expect(state.take(), isNull);
    expect(state.suppresses(intro), isTrue);
    expect(state.suppresses(MediaMarker(id: 2, type: 'intro', startTimeOffset: 90000, endTimeOffset: 100000)), isFalse);
  });
  test('five-second expiry cannot undo and does not suppress', () {
    var now = DateTime.utc(2026);
    final state = IntroSkipUndo(now: () => now);
    state.offer(intro, const Duration(seconds: 13));
    now = now.add(const Duration(milliseconds: 4999));
    expect(state.available, isTrue);
    now = now.add(const Duration(milliseconds: 1));
    expect(state.available, isFalse);
    expect(state.take(), isNull);
    expect(state.suppresses(intro), isFalse);
  });
  test('item/session reset invalidates old actions and suppression', () {
    final state = IntroSkipUndo();
    state.offer(intro, const Duration(seconds: 13));
    state.take();
    state.offer(intro, const Duration(seconds: 14));
    state.reset();
    expect(state.take(), isNull);
    expect(state.suppresses(intro), isFalse);
  });
  test('credits and dismissed offers never create an undo action', () {
    final state = IntroSkipUndo();
    state.offer(MediaMarker(id: 2, type: 'credits', startTimeOffset: 10000, endTimeOffset: 80000), Duration.zero);
    expect(state.available, isFalse);
    state.offer(intro, const Duration(seconds: 13));
    state.dismiss();
    expect(state.take(), isNull);
  });
}
