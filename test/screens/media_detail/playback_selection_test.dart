import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_source_info.dart';
import 'package:plezy/media/media_version.dart';
import 'package:plezy/screens/media_detail/playback_selection.dart';

void main() {
  MediaSourceInfo source(String id, {int part = 0}) => MediaSourceInfo(
    videoUrl: '',
    mediaSourceId: id,
    mediaIndex: 0,
    partIndex: part,
    audioTracks: [MediaAudioTrack(id: 7, languageCode: 'eng', selected: true)],
    subtitleTracks: [
      MediaSubtitleTrack(
        id: 19,
        languageCode: 'zho',
        selected: false,
        forced: false,
        key: 'https://stale.example/subtitle',
      ),
    ],
    chapters: [],
  );

  test('selection uses source ids and explicit Off instead of player-local indexes', () {
    final choice = DetailPlaybackSelection();
    final media = source('one');
    choice.bindSource(media);
    choice.audioId = 7;
    choice.subtitleId = 19;
    expect(choice.audioFor(media)?.id, 'source:7');
    expect(choice.subtitleFor(media)?.id, 'source:19');
    choice.subtitlesOff = true;
    choice.subtitleId = null;
    expect(choice.subtitleFor(media)?.id, 'no');
  });

  test('a source, part, or version change clears all old track intent', () {
    final choice = DetailPlaybackSelection();
    choice.bindSource(source('one'));
    choice.audioId = 7;
    choice.subtitlesOff = true;
    choice.bindSource(source('two'));
    expect(choice.hasTrackChoice, isFalse);
    choice.audioId = 7;
    choice.bindSource(source('two', part: 1));
    expect(choice.hasTrackChoice, isFalse);
    choice.subtitleId = 19;
    choice.chooseVersion(const MediaVersion(id: 'third'));
    expect(choice.hasTrackChoice, isFalse);
  });

  test('version survives list reordering but never substitutes a removed id', () {
    const first = MediaVersion(id: 'one', videoResolution: '1080');
    const second = MediaVersion(id: 'two', videoResolution: '4k');
    final choice = DetailPlaybackSelection()..chooseVersion(second);
    expect(choice.versionIndex([first, second]), 1);
    expect(choice.versionIndex([second, first]), 0);
    expect(choice.versionIndex([first]), isNull);
  });

  test('absent source rows never fabricate tracks or subtitle Off', () {
    final choice = DetailPlaybackSelection()
      ..audioId = 7
      ..subtitlesOff = true;
    choice.bindSource(null);
    expect(choice.audioFor(null), isNull);
    expect(choice.subtitleFor(null), isNull);
    expect(choice.hasTrackChoice, isFalse);
  });

  test('menu values bind reused stream ids to item, source and part, not list order', () {
    DetailTrackOption option(String item, String id, {int part = 0}) =>
        (scope: detailTrackScope(item, source(id, part: part)), streamId: 7);
    final original = option('movie', 'one');
    // Refetching/reordering the same source constructs new objects, but the
    // stable descriptor remains selectable while its menu is open.
    expect(option('movie', 'one'), original);
    expect(option('movie', 'two'), isNot(original));
    expect(option('other-episode', 'one'), isNot(original));
    expect(option('movie', 'one', part: 1), isNot(original));
    final off = (scope: original.scope, streamId: null);
    expect(off, isNot(original));
    expect(off, isNot((scope: option('movie', 'two').scope, streamId: null)));
  });
}
