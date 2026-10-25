import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/services/jellyfin_mappers.dart';
import 'package:plezy/watch_together/providers/watch_together_provider.dart';
import 'package:plezy/widgets/video_controls/widgets/video_controls_header.dart';
import 'package:plezy/widgets/optimized_media_image.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    await initializeDateFormatting('en');
  });

  test('player logo preserves tag and uses bounded request parameters', () {
    final item = _mappedItem({
      'Id': 'episode',
      'Type': 'Episode',
      'ImageTags': {'Logo': 'own-logo-tag'},
      'ParentLogoItemId': 'series',
      'ParentLogoImageTag': 'parent-tag',
    });
    final uri = Uri.parse(playerLogoPath(item)!);
    expect(uri.path, '/Items/episode/Images/Logo');
    expect(uri.queryParameters['tag'], 'own-logo-tag');
    expect(uri.queryParameters['maxHeight'], '720');
    expect(uri.queryParameters['quality'], '90');
  });

  testWidgets('parent logo is beside back control and unresolved image falls back to series', (tester) async {
    final item = _mappedItem({
      'Id': 'episode',
      'Type': 'Episode',
      'Name': 'Episode',
      'SeriesName': 'Series fallback',
      'ParentLogoItemId': 'series',
      'ParentLogoImageTag': 'parent-tag',
    });
    await _pumpHeader(tester, metadata: item, style: VideoHeaderStyle.multiLine);
    final logo = tester.widget<ClearLogoImage>(find.byType(ClearLogoImage));
    expect(Uri.parse(logo.logoPath!).path, '/Items/series/Images/Logo');
    expect(Uri.parse(logo.logoPath!).queryParameters['tag'], 'parent-tag');
    expect(find.text('Series fallback'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(find.byType(ClearLogoImage), findsNothing);
  });

  testWidgets('title-less mapped movie builds with localized fallback in both layouts', (tester) async {
    final item = _mappedItem({'Id': 'movie-without-name', 'Type': 'Movie'});

    for (final style in VideoHeaderStyle.values) {
      await _pumpHeader(tester, metadata: item, style: style);

      expect(find.text(t.common.unknown), findsOneWidget, reason: style.name);
      expect(tester.takeException(), isNull, reason: style.name);
    }
  });

  testWidgets('portrait header keeps all six controls without squeezing the title', (tester) async {
    await _pumpHeader(
      tester,
      metadata: _mappedItem({'Id': 'movie', 'Type': 'Movie', 'Name': 'Movie title'}),
      style: VideoHeaderStyle.multiLine,
      width: 328,
      trailing: const SizedBox(width: 288, height: 48),
      trailingOnSeparateRow: true,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('Movie title')).width, greaterThan(100));
  });

  testWidgets('logo fallback fits a narrow header with large text', (tester) async {
    final item = _mappedItem({
      'Id': 'episode',
      'Type': 'Episode',
      'Name': 'A long episode title',
      'SeriesName': 'Series fallback',
      'ParentIndexNumber': 1,
      'IndexNumber': 2,
      'ParentLogoItemId': 'series',
      'ParentLogoImageTag': 'tag',
    });
    await _pumpHeader(tester, metadata: item, style: VideoHeaderStyle.multiLine, width: 320, textScale: 1.8);
    expect(find.text('Series fallback'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('title-less mapped episode keeps series identity and uses fallback in both layouts', (tester) async {
    final item = _mappedItem({
      'Id': 'episode-without-name',
      'Type': 'Episode',
      'SeriesName': 'Mapped Series',
      'ParentIndexNumber': 2,
      'IndexNumber': 3,
    });

    for (final style in VideoHeaderStyle.values) {
      await _pumpHeader(tester, metadata: item, style: style);

      final expectedEpisodeLine = switch (style) {
        VideoHeaderStyle.singleLine => 'Mapped Series · S2E3 · ${t.common.unknown}',
        VideoHeaderStyle.multiLine =>
          '${t.videoControls.seasonNumber(n: 2)} · ${t.videoControls.episodeNumber(n: 3)} · ${t.common.unknown}',
      };
      expect(find.text(expectedEpisodeLine), findsOneWidget, reason: style.name);
      expect(tester.takeException(), isNull, reason: style.name);
    }
  });

  testWidgets('ordinary mapped episode shows its number and title', (tester) async {
    final item = _mappedItem({
      'Id': 'titled-episode',
      'Type': 'Episode',
      'Name': 'The Arrival',
      'SeriesName': 'Mapped Series',
      'ParentIndexNumber': 1,
      'IndexNumber': 4,
    });

    for (final style in VideoHeaderStyle.values) {
      await _pumpHeader(tester, metadata: item, style: style);

      final expectedEpisodeLine = switch (style) {
        VideoHeaderStyle.singleLine => 'Mapped Series · S1E4 · The Arrival',
        // Season 1 is implied; no duration on the line.
        VideoHeaderStyle.multiLine => '${t.videoControls.episodeNumber(n: 4)} · The Arrival',
      };
      expect(find.text(expectedEpisodeLine), findsOneWidget, reason: style.name);
      expect(find.text(t.common.unknown), findsNothing, reason: style.name);
    }
  });
}

MediaItem _mappedItem(Map<String, dynamic> json) {
  return JellyfinMappers.mediaItem(
    json,
    serverId: ServerId('header-test-server'),
    serverName: 'Test Server',
    absolutizer: null,
  )!;
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required MediaItem metadata,
  required VideoHeaderStyle style,
  double width = 900,
  double textScale = 1,
  Widget? trailing,
  bool trailingOnSeparateRow = false,
}) async {
  final watchTogether = WatchTogetherProvider();
  addTearDown(watchTogether.dispose);

  await tester.pumpWidget(
    TranslationProvider(
      child: ChangeNotifierProvider<WatchTogetherProvider>.value(
        value: watchTogether,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox(
              width: width,
              child: VideoControlsHeader(
                metadata: metadata,
                style: style,
                showClock: width > 400,
                trailing: trailing,
                trailingOnSeparateRow: trailingOnSeparateRow,
                onBack: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
