import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/services/jellyfin_media_info_mapper.dart';

/// Pins the parse of Emby's `GET /Episode/{id}/IntroTimestamps`, including
/// the seconds-vs-ticks unit heuristic — the two implementations sharing
/// this endpoint's lineage differ by 10⁷ and a wrong guess moves the skip
/// button by seasons, not seconds.
void main() {
  group('embyIntroTimestampsToMarkers', () {
    test('parses Emby-native seconds into an intro marker', () {
      final markers = embyIntroTimestampsToMarkers({
        'EpisodeId': 'ep-1',
        'Valid': true,
        'IntroStart': 34.54,
        'IntroEnd': 124.54,
        'ShowSkipPromptAt': 30,
        'HideSkipPromptAt': 120,
      });
      expect(markers, hasLength(1));
      expect(markers.single.type, 'intro');
      expect(markers.single.startTimeOffset, 34540);
      expect(markers.single.endTimeOffset, 124540);
      expect(markers.single.source, 'server');
    });

    test('normalizes .NET-tick responses from the Jellyfin-plugin lineage', () {
      final markers = embyIntroTimestampsToMarkers({
        'EpisodeId': 'ep-1',
        'Valid': true,
        'IntroStart': 345400000,
        'IntroEnd': 1245400000,
      });
      expect(markers, hasLength(1));
      expect(markers.single.startTimeOffset, 34540);
      expect(markers.single.endTimeOffset, 124540);
    });

    test('keeps zero start and whole-second values in seconds mode', () {
      final markers = embyIntroTimestampsToMarkers({'IntroStart': 0, 'IntroEnd': 90});
      expect(markers.single.startTimeOffset, 0);
      expect(markers.single.endTimeOffset, 90000);
    });

    test('returns no markers for missing, empty, inverted or null bodies', () {
      expect(embyIntroTimestampsToMarkers(null), isEmpty);
      expect(embyIntroTimestampsToMarkers(<String, dynamic>{}), isEmpty);
      expect(embyIntroTimestampsToMarkers('not a map'), isEmpty);
      expect(embyIntroTimestampsToMarkers({'IntroStart': 10, 'IntroEnd': 10}), isEmpty);
      expect(embyIntroTimestampsToMarkers({'IntroStart': 20, 'IntroEnd': 10}), isEmpty);
      expect(embyIntroTimestampsToMarkers({'IntroStart': 'x', 'IntroEnd': 'y'}), isEmpty);
    });
  });
}
