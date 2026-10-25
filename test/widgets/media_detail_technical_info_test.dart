import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_file_info.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/media_detail_technical_info.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  MediaFileInfo info(String path, {String id = 'source-1', String codec = 'hevc'}) => MediaFileInfo(
    versions: [
      MediaFileVersion(
        id: id,
        parts: [
          MediaFilePart(
            filePath: path,
            streams: [
              MediaStreamDetails(kind: MediaStreamKind.video, ordinal: 1, codec: codec, width: 3840, height: 2160),
            ],
          ),
        ],
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, MediaDetailTechnicalInfo child, {double scale = 1}) => tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: monoTheme(dark: true),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );

  testWidgets('target change clears old file and discards its late response', (tester) async {
    final first = Completer<MediaFileInfo?>();
    final second = Completer<MediaFileInfo?>();
    await pump(
      tester,
      MediaDetailTechnicalInfo(targetKey: 'server:episode-1', title: 'Episode 1', load: () => first.future),
    );
    await pump(
      tester,
      MediaDetailTechnicalInfo(targetKey: 'server:episode-2', title: 'Episode 2', load: () => second.future),
    );
    second.complete(info('/media/episode-2.mkv'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/media/episode-2.mkv'), findsOneWidget);
    first.complete(info('/media/episode-1.mkv'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/media/episode-1.mkv'), findsNothing);
    expect(find.textContaining('/media/episode-2.mkv'), findsOneWidget);
  });

  testWidgets('version selection follows source identity rather than reordered index', (tester) async {
    final data = MediaFileInfo(
      versions: [
        info('/media/old.mkv', id: 'old').versions.single,
        info('/media/chosen.mkv', id: 'chosen', codec: 'av1').versions.single,
      ],
    );
    await pump(
      tester,
      MediaDetailTechnicalInfo(
        targetKey: 'movie',
        title: 'Movie',
        sourceId: 'chosen',
        versionIndex: 0,
        load: () async => data,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('/media/chosen.mkv'), findsOneWidget);
    expect(find.textContaining('/media/old.mkv'), findsNothing);
    expect(find.textContaining('av1'), findsOneWidget);
    await pump(
      tester,
      MediaDetailTechnicalInfo(
        targetKey: 'movie',
        title: 'Movie',
        sourceId: 'missing',
        versionIndex: 0,
        load: () async => data,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.messages.fileInfoNotAvailable), findsOneWidget);
    expect(find.textContaining('/media/old.mkv'), findsNothing);
  });

  testWidgets('offline does not invoke loader and retires in-flight network result', (tester) async {
    final result = Completer<MediaFileInfo?>();
    var calls = 0;
    Future<MediaFileInfo?> load() {
      calls++;
      return result.future;
    }

    await pump(tester, MediaDetailTechnicalInfo(targetKey: 'movie', title: 'Movie', load: load));
    await pump(tester, MediaDetailTechnicalInfo(targetKey: 'movie', title: 'Movie', offline: true, load: load));
    result.complete(info('/network/file.mkv'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('/network/file.mkv'), findsNothing);
    expect(find.text(t.messages.fileInfoNotAvailable), findsOneWidget);
  });

  testWidgets('same target version change retires the previous file request', (tester) async {
    final old = Completer<MediaFileInfo?>();
    await pump(
      tester,
      MediaDetailTechnicalInfo(targetKey: 'movie', title: 'Movie', sourceId: 'old', load: () => old.future),
    );
    await pump(
      tester,
      MediaDetailTechnicalInfo(
        targetKey: 'movie',
        title: 'Movie',
        sourceId: 'new',
        load: () async => info('/media/new.mkv', id: 'new'),
      ),
    );
    await tester.pumpAndSettle();
    old.complete(info('/media/old.mkv', id: 'old'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/media/new.mkv'), findsOneWidget);
    expect(find.textContaining('/media/old.mkv'), findsNothing);
  });

  testWidgets('missing data is explicit and large text remains in scrollable cards', (tester) async {
    await pump(tester, MediaDetailTechnicalInfo(targetKey: 'movie', title: 'Movie', load: () async => null));
    await tester.pumpAndSettle();
    expect(find.text(t.messages.fileInfoNotAvailable), findsOneWidget);
    await pump(
      tester,
      MediaDetailTechnicalInfo(
        targetKey: 'movie',
        title: 'Movie',
        revision: 1,
        load: () async => info('/media/very-long-folder-name/a-file.mkv'),
      ),
      scale: 2,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('3840x2160'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
