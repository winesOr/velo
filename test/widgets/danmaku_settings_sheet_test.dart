import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plezy/danmaku/danmaku_api_client.dart';
import 'package:plezy/danmaku/danmaku_comment.dart';
import 'package:plezy/danmaku/danmaku_session.dart';
import 'package:plezy/danmaku/danmaku_settings_repository.dart';
import 'package:plezy/danmaku/danmaku_source.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/services/file_picker_service.dart';
import 'package:plezy/widgets/focusable_list_tile.dart';
import 'package:plezy/widgets/video_controls/sheets/danmaku_settings_sheet.dart';
import 'package:plezy/widgets/video_controls/sheets/base_video_control_sheet.dart';
import 'package:plezy/widgets/video_controls/sheets/danmaku_sources_sheet.dart';

class _MemoryStore {
  String? value;
  bool failWrites = false;

  DanmakuSettingsRepository get repository => DanmakuSettingsRepository(
    read: () async => value,
    write: (next) async {
      if (failWrites) throw StateError('unavailable');
      value = next;
    },
    protect: (clear) async => clear,
    reveal: (stored) async => stored,
  );
}

class _Picker implements FilePickerDelegate {
  final String contents;
  final Future<void>? ready;
  _Picker(this.contents, {this.ready});

  @override
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool withData = false,
  }) async {
    await ready;
    final bytes = Uint8List.fromList(utf8.encode(contents));
    return FilePickerResult([PlatformFile(name: 'local.xml', size: bytes.length, bytes: bytes)]);
  }

  @override
  Future<String?> getDirectoryPath({String? dialogTitle}) async => null;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    Uint8List? bytes,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async => null;
}

Future<void> _pump(WidgetTester tester, Widget sheet, {Size size = const Size(520, 900), double textScale = 1}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    InputModeTracker(
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(width: size.width, child: sheet),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 300, scrollable: scrollable);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final field = find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

const _one = DanmakuSource(id: 'one', name: 'First gateway', baseUrl: 'https://one.example/private-token');
const _two = DanmakuSource(id: 'two', name: 'Second gateway', baseUrl: 'https://two.example/prefix/api/v2');
const _item = MediaItem.plex(
  id: 'episode',
  kind: MediaKind.episode,
  title: 'Second episode',
  grandparentTitle: 'Example show',
  grandparentId: 'series',
  parentIndex: 2,
  index: 2,
  serverId: 'server',
);
const _context = DanmakuMatchContext(
  profileId: 'profile',
  serverId: 'server',
  itemId: 'episode',
  title: 'Example show',
  seriesId: 'series',
  seasonNumber: 2,
  episodeNumber: 2,
  durationMs: 60000,
);

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));
  tearDown(() => FilePickerService.setDelegateForTesting(null));

  testWidgets('drawer online search opens its input and returns after loading the chosen episode', (tester) async {
    final requested = <Uri>[];
    final session = DanmakuSession.forTesting(
      repository: _MemoryStore().repository,
      clientFactory: (source, credentials) => DanmakuApiClient(
        baseUrl: source.baseUrl,
        sourceId: source.id,
        httpClient: MockClient((request) async {
          requested.add(request.url);
          if (request.url.path.endsWith('/search/anime')) {
            return http.Response(
              jsonEncode({
                'animes': [
                  {'animeId': 9, 'animeTitle': 'Example show'},
                ],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/bangumi/9')) {
            return http.Response(
              jsonEncode({
                'bangumi': {
                  'episodes': [
                    {'episodeId': 92, 'episodeTitle': 'Second', 'episodeNumber': 2},
                  ],
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'comments': [
                {'p': '1,1,25,16777215', 'm': 'loaded'},
              ],
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(session.dispose);
    await session.saveSource(_one);
    session.setMediaContext(_context);
    await _pump(
      tester,
      EmbeddedVideoControlSheet(
        child: DanmakuSettingsSheet(metadata: _item, session: session),
      ),
      size: const Size(318, 370),
    );
    expect(find.text(t.danmaku.changeTitle), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('danmaku-open-search')));
    final query = find.byKey(const ValueKey('danmaku-search-query'));
    expect(query, findsOneWidget);
    expect(tester.getRect(query).bottom, lessThanOrEqualTo(370));
    final text = tester.widget<TextField>(find.descendant(of: query, matching: find.byType(TextField)));
    expect(text.focusNode!.hasFocus, isTrue);
    await _tap(tester, find.text(t.danmaku.searchTitles));
    expect(requested.first.queryParameters['keyword'], 'Example show 第2季');
    await _tap(tester, find.text('Example show · Second'));
    expect(session.comments.single.text, 'loaded');
    expect(find.byKey(const ValueKey('danmaku-open-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('danmaku-search-query')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawer display area is directly reachable and its top-row preset persists', (tester) async {
    final store = _MemoryStore();
    final session = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(session.dispose);
    await session.initialize();
    session.load(const [DanmakuComment(timeMs: 1000, text: 'keep')], sourceLabel: 'local');
    await _pump(
      tester,
      EmbeddedVideoControlSheet(
        child: DanmakuSettingsSheet(metadata: _item, session: session),
      ),
      size: const Size(318, 370),
    );
    await _tap(tester, find.byKey(const ValueKey('danmaku-open-area')));
    expect(find.byKey(const ValueKey('danmaku-area-preview')), findsOneWidget);
    await _tap(tester, find.text(t.danmaku.topRows(n: 4)));
    expect(session.presentation.scrollLines, 4);
    await _tap(tester, find.byIcon(Symbols.arrow_back_rounded));
    expect(find.text(t.danmaku.topRows(n: 4)), findsOneWidget);
    final restored = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.presentation.scrollLines, 4);
    expect(session.comments.single.text, 'keep');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty source guide cancels to settings and local import without a network request', (tester) async {
    var requests = 0;
    final store = _MemoryStore();
    final session = DanmakuSession.forTesting(
      repository: store.repository,
      clientFactory: (source, credentials) {
        requests++;
        return DanmakuApiClient(baseUrl: source.baseUrl, sourceId: source.id);
      },
    );
    addTearDown(session.dispose);
    FilePickerService.setDelegateForTesting(_Picker('<i><d p="1,1,25,16777215">Hello</d></i>'));
    await _pump(tester, DanmakuSettingsSheet(session: session));
    expect(find.text(t.danmaku.noSourcesTitle), findsOneWidget);
    await _tap(tester, find.text(t.common.cancel));
    expect(find.byKey(const ValueKey('danmaku-local-import')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('danmaku-enabled')));
    expect(session.enabled, isFalse);
    await _tap(tester, find.byKey(const ValueKey('danmaku-local-import')));
    expect(session.comments.single.text, 'Hello');
    expect(session.sourceLabel, 'local.xml');
    expect(session.sources, isEmpty);
    expect(session.enabled, isTrue);
    expect(requests, 0);
  });

  testWidgets('source validation and failed writes retain input and allow retry', (tester) async {
    final store = _MemoryStore()..failWrites = true;
    final session = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(session.dispose);
    var saves = 0;
    await _pump(tester, DanmakuSourceEditor(session: session, onSaved: () => saves++, onCancel: () {}));
    await _enter(tester, 'danmaku-source-name', 'Home');
    await _enter(tester, 'danmaku-source-url', 'https://gateway.example/prefix?token=private');
    await _tap(tester, find.text(t.common.save));
    expect(find.text(t.danmaku.sourceUrlInvalid), findsOneWidget);
    await _enter(tester, 'danmaku-source-url', 'https://gateway.example/prefix/private-token');
    await _tap(tester, find.text(t.common.save));
    expect(find.text(t.danmaku.saveFailed), findsOneWidget);
    expect(session.sources, isEmpty);
    final field = tester.widget<TextField>(
      find.descendant(of: find.byKey(const ValueKey('danmaku-source-url')), matching: find.byType(TextField)),
    );
    expect(field.controller!.text, 'https://gateway.example/prefix/private-token');
    store.failWrites = false;
    await _tap(tester, find.text(t.common.save));
    expect(saves, 1);
    expect(session.sources.single.name, 'Home');
    expect(session.sources.single.baseUrl, 'https://gateway.example/prefix/private-token');
  });

  testWidgets('keyboard enable opens the first source guide and keyboard cancel preserves local import', (
    tester,
  ) async {
    final session = DanmakuSession.forTesting(repository: _MemoryStore().repository);
    addTearDown(session.dispose);
    await session.updateStyle(enabled: false);
    await _pump(tester, DanmakuSettingsSheet(session: session));
    final enabled = tester.widget<SwitchListTile>(
      find.descendant(of: find.byKey(const ValueKey('danmaku-enabled')), matching: find.byType(SwitchListTile)),
    );
    enabled.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text(t.danmaku.noSourcesTitle), findsOneWidget);
    final cancel = find.ancestor(of: find.text(t.common.cancel), matching: find.byType(DanmakuActionButton));
    final cancelFocus = tester.widget<Focus>(find.descendant(of: cancel, matching: find.byType(Focus)).first);
    cancelFocus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(session.enabled, isTrue);
    expect(session.sources, isEmpty);
    expect(find.byKey(const ValueKey('danmaku-local-import')), findsOneWidget);
  });

  testWidgets('official credential fields appear only for the exact official origin', (tester) async {
    final session = DanmakuSession.forTesting(repository: _MemoryStore().repository);
    addTearDown(session.dispose);
    await _pump(tester, DanmakuSourceEditor(session: session, onSaved: () {}, onCancel: () {}));
    await _enter(tester, 'danmaku-source-name', 'Official');
    await _enter(tester, 'danmaku-source-url', 'https://api.dandanplay.net.evil.example');
    expect(find.byKey(const ValueKey('danmaku-app-secret')), findsNothing);
    await _enter(tester, 'danmaku-source-url', 'https://api.dandanplay.net');
    expect(find.byKey(const ValueKey('danmaku-app-secret')), findsOneWidget);
    await _tap(tester, find.text(t.common.save));
    expect(find.text(t.danmaku.credentialsRequired), findsOneWidget);
    await _enter(tester, 'danmaku-app-id', 'own-id');
    await _enter(tester, 'danmaku-app-secret', 'own-secret');
    final secret = tester.widget<TextField>(
      find.descendant(of: find.byKey(const ValueKey('danmaku-app-secret')), matching: find.byType(TextField)),
    );
    expect(secret.obscureText, isTrue);
    await _tap(tester, find.text(t.common.save));
    expect(await session.hasSourceCredentials(session.sources.single.id), isTrue);
  });

  testWidgets('source management persists enable, order, edits and delete', (tester) async {
    final store = _MemoryStore();
    final session = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(session.dispose);
    await session.saveSource(_one);
    await session.saveSource(_two);
    await _pump(tester, DanmakuSourcesSheet(session: session, onBack: () {}));
    await _tap(tester, find.text(t.danmaku.moveUp).last);
    expect(session.sources.map((source) => source.id), ['two', 'one']);
    await _tap(tester, find.byKey(const ValueKey('enable-source-two')));
    expect(session.sources.first.enabled, isFalse);
    await _tap(tester, find.text(t.common.edit).first);
    await _enter(tester, 'danmaku-source-name', 'Renamed');
    await _tap(tester, find.text(t.common.save));
    expect(session.sources.first.name, 'Renamed');
    await _tap(tester, find.text(t.common.delete).first);
    await _tap(tester, find.widgetWithText(TextButton, t.common.delete).last);
    expect(session.sources.single.id, 'one');
    final restored = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.sources.single.id, 'one');
  });

  testWidgets('connection result reports search scope, latency and safe HTTP reason', (tester) async {
    final store = _MemoryStore();
    final session = DanmakuSession.forTesting(
      repository: store.repository,
      clientFactory: (source, credentials) => DanmakuApiClient(
        baseUrl: source.baseUrl,
        sourceId: source.id,
        httpClient: MockClient(
          (request) async =>
              http.Response(source.id == 'one' ? '{"animes":[]}' : 'private-token', source.id == 'one' ? 200 : 401),
        ),
      ),
    );
    addTearDown(session.dispose);
    await session.saveSource(_one);
    await session.saveSource(_two);
    await _pump(tester, DanmakuSourcesSheet(session: session, onBack: () {}));
    await _tap(tester, find.text(t.danmaku.testConnection).first);
    expect(find.textContaining('Search endpoint available'), findsOneWidget);
    await _tap(tester, find.text(t.danmaku.testConnection).last);
    expect(find.textContaining('HTTP 401'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    expect(find.text(t.danmaku.connectionScope), findsOneWidget);
  });

  testWidgets('a connection result from before an edit cannot describe the replacement endpoint', (tester) async {
    final response = Completer<http.Response>();
    final session = DanmakuSession.forTesting(
      repository: _MemoryStore().repository,
      clientFactory: (source, credentials) => DanmakuApiClient(
        baseUrl: source.baseUrl,
        sourceId: source.id,
        httpClient: MockClient((request) => response.future),
      ),
    );
    addTearDown(session.dispose);
    await session.saveSource(_one);
    await _pump(tester, DanmakuSourcesSheet(session: session, onBack: () {}));
    await _tap(tester, find.text(t.danmaku.testConnection));
    await _tap(tester, find.text(t.common.edit));
    await _enter(tester, 'danmaku-source-url', 'https://replacement.example/api/v2');
    await _tap(tester, find.text(t.common.save));
    response.complete(http.Response('{"animes":[]}', 200));
    await tester.pumpAndSettle();
    expect(session.sources.single.baseUrl, 'https://replacement.example/api/v2');
    expect(find.textContaining('Search endpoint available'), findsNothing);
    expect(find.text(t.danmaku.testConnection), findsOneWidget);
  });

  testWidgets('fallback titles and manual episode selection use current source and request preferences', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final store = _MemoryStore();
    final session = DanmakuSession.forTesting(
      repository: store.repository,
      clientFactory: (source, credentials) => DanmakuApiClient(
        baseUrl: source.baseUrl,
        sourceId: source.id,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/search/anime')) {
            return http.Response(
              jsonEncode({
                'animes': source.id == 'one'
                    ? []
                    : [
                        {'animeId': 10, 'animeTitle': 'Example TV'},
                        {'animeId': 11, 'animeTitle': 'Example special'},
                      ],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/bangumi/11')) {
            return http.Response(
              jsonEncode({
                'bangumi': {
                  'episodes': [
                    {'episodeId': 100, 'episodeNumber': 1, 'episodeTitle': 'First'},
                    {'episodeId': 101, 'episodeNumber': 2, 'episodeTitle': 'Second', 'commentCount': 17},
                  ],
                },
              }),
              200,
            );
          }
          return http.Response('{"comments":[{"p":"1,1,16777215","m":"Hello"}]}', 200);
        }),
      ),
    );
    addTearDown(session.dispose);
    await session.saveSource(_one);
    await session.saveSource(_two);
    session.setMediaContext(_context);
    await _pump(tester, DanmakuSettingsSheet(metadata: _item, session: session));
    await _tap(tester, find.text(t.danmaku.withRelated));
    await _tap(tester, find.text(t.danmaku.conversion));
    await _tap(tester, find.text(t.danmaku.conversion));
    await _tap(tester, find.text(t.danmaku.searchTitles));
    expect(requests.first.url.queryParameters['keyword'], 'Example show 第2季');
    expect(find.text('Example TV'), findsOneWidget);
    expect(find.text('Example special'), findsOneWidget);
    expect(find.textContaining(t.danmaku.failureEmpty), findsOneWidget);
    expect(requests.where((request) => request.url.path.contains('/bangumi/')), isEmpty);
    await _tap(tester, find.text('Example special'));
    expect(find.text(t.danmaku.recommended), findsOneWidget);
    expect(find.text(t.danmaku.commentCount(count: 17)), findsOneWidget);
    expect(find.text(t.danmaku.commentCount(count: 0)), findsNothing);
    await _tap(tester, find.text('Example special · Second'));
    final commentRequest = requests.last;
    expect(commentRequest.url.host, 'two.example');
    expect(commentRequest.url.path, '/prefix/api/v2/comment/101');
    expect(commentRequest.url.queryParameters['withRelated'], 'false');
    expect(commentRequest.url.queryParameters['chConvert'], '2');
    expect(session.comments.single.text, 'Hello');
    expect(commentRequest.headers.keys.any((key) => key.toLowerCase().startsWith('x-')), isFalse);
    final episodeOffset = find.byKey(const ValueKey('danmaku-episode-offset'));
    await tester.ensureVisible(episodeOffset);
    await tester.pumpAndSettle();
    final offsetFocus = tester.widget<Focus>(find.descendant(of: episodeOffset, matching: find.byType(Focus)).first);
    offsetFocus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(session.episodeOffset, 1);
    final restored = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(restored.dispose);
    await restored.initialize();
    restored.setMediaContext(_context);
    expect(restored.episodeOffset, 1);
    expect(find.descendant(of: episodeOffset, matching: find.byType(Slider)), findsNothing);
    await tester.ensureVisible(find.byTooltip(t.common.reset));
    await tester.tap(find.byTooltip(t.common.reset));
    await tester.pumpAndSettle();
    expect(session.episodeOffset, 0);
    final reset = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(reset.dispose);
    await reset.initialize();
    reset.setMediaContext(_context);
    expect(reset.episodeOffset, 0);
  });

  testWidgets('left and right on focused time offset adjust the shared effective time', (tester) async {
    final session = DanmakuSession.forTesting(repository: _MemoryStore().repository);
    addTearDown(session.dispose);
    await session.saveSource(_one);
    session.setMediaContext(_context);
    session.load([const DanmakuComment(timeMs: 1000, text: 'Hello')], sourceLabel: 'Local');
    await _pump(tester, DanmakuSettingsSheet(metadata: _item, session: session));
    final slider = find.byKey(const ValueKey('danmaku-time-offset'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final focus = tester.widget<Focus>(find.descendant(of: slider, matching: find.byType(Focus)).first);
    focus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(session.offsetMs, 500);
    expect(session.comments.single.timeMs, 1500);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(session.offsetMs, 0);
    expect(session.comments.single.timeMs, 1000);
  });

  testWidgets('failed style and offset writes retain prior values and give immediate feedback', (tester) async {
    final store = _MemoryStore();
    final session = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(session.dispose);
    await session.saveSource(_one);
    session.setMediaContext(_context);
    session.load([const DanmakuComment(timeMs: 1000, text: 'Keep me')], sourceLabel: 'Local');
    final fontSize = session.fontSize;
    final opacity = session.opacity;
    await _pump(tester, DanmakuSettingsSheet(metadata: _item, session: session));
    store.failWrites = true;
    await _tap(tester, find.byKey(const ValueKey('danmaku-heatmap')));
    expect(session.heatmapEnabled, isTrue);
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text(t.danmaku.saveFailed)), findsOneWidget);
    for (final key in ['danmaku-opacity', 'danmaku-font-size', 'danmaku-time-offset']) {
      final slider = find.byKey(ValueKey(key));
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      final focus = tester.widget<Focus>(find.descendant(of: slider, matching: find.byType(Focus)).first);
      focus.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    expect(session.fontSize, fontSize);
    expect(session.opacity, opacity);
    expect(session.offsetMs, 0);
    expect(session.comments.single.timeMs, 1000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('external context change clears old work and episode candidates', (tester) async {
    final session = DanmakuSession.forTesting(
      repository: _MemoryStore().repository,
      clientFactory: (source, credentials) => DanmakuApiClient(
        baseUrl: source.baseUrl,
        sourceId: source.id,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/search/anime')) {
            return http.Response('{"animes":[{"animeId":10,"animeTitle":"Old work"}]}', 200);
          }
          return http.Response('{"bangumi":{"episodes":[{"episodeId":100,"episodeTitle":"Old episode"}]}}', 200);
        }),
      ),
    );
    addTearDown(session.dispose);
    await session.saveSource(_one);
    session.setMediaContext(_context);
    await _pump(tester, DanmakuSettingsSheet(metadata: _item, session: session));
    await _tap(tester, find.text(t.danmaku.searchTitles));
    // A single candidate opens its episode list without another tap.
    expect(find.text('Old work · Old episode'), findsOneWidget);
    session.setMediaContext(
      const DanmakuMatchContext(
        profileId: 'profile',
        serverId: 'server',
        itemId: 'new-episode',
        title: 'New work',
        seasonNumber: 3,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old work'), findsNothing);
    expect(find.text('Old work · Old episode'), findsNothing);
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('danmaku-search-query')), 250, scrollable: scrollable);
    final query = tester.widget<TextField>(
      find.descendant(of: find.byKey(const ValueKey('danmaku-search-query')), matching: find.byType(TextField)),
    );
    expect(query.controller!.text, 'New work 第3季');
  });

  testWidgets('failed local parse preserves existing comments', (tester) async {
    final session = DanmakuSession.forTesting(repository: _MemoryStore().repository);
    addTearDown(session.dispose);
    await session.saveSource(_one);
    session.load([const DanmakuComment(timeMs: 1000, text: 'Keep me')], sourceLabel: 'Previous');
    FilePickerService.setDelegateForTesting(_Picker('not json or xml'));
    await _pump(tester, DanmakuSettingsSheet(session: session));
    await _tap(tester, find.byKey(const ValueKey('danmaku-local-import')));
    expect(session.comments.single.text, 'Keep me');
    expect(session.sourceLabel, 'Previous');
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text(t.danmaku.localImportFailed), findsOneWidget);
  });

  testWidgets('a local file chosen after a context switch cannot replace the new episode comments', (tester) async {
    final session = DanmakuSession.forTesting(repository: _MemoryStore().repository);
    addTearDown(session.dispose);
    await session.saveSource(_one);
    session.setMediaContext(_context);
    final selected = Completer<void>();
    FilePickerService.setDelegateForTesting(
      _Picker('<i><d p="1,1,25,16777215">Old episode</d></i>', ready: selected.future),
    );
    await _pump(tester, DanmakuSettingsSheet(metadata: _item, session: session));
    await _tap(tester, find.byKey(const ValueKey('danmaku-local-import')));
    session.setMediaContext(
      const DanmakuMatchContext(profileId: 'profile', serverId: 'server', itemId: 'new-episode', title: 'New episode'),
    );
    session.load([const DanmakuComment(timeMs: 1000, text: 'New episode')], sourceLabel: 'New');
    selected.complete();
    await tester.pumpAndSettle();
    expect(session.comments.single.text, 'New episode');
    expect(session.sourceLabel, 'New');
  });

  testWidgets('source editor and settings fit a narrow large text surface', (tester) async {
    final session = DanmakuSession.forTesting(repository: _MemoryStore().repository);
    addTearDown(session.dispose);
    await _pump(tester, DanmakuSettingsSheet(session: session), size: const Size(320, 640), textScale: 1.8);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text(t.common.cancel));
    expect(find.byType(FocusableSwitchListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('presentation rows support remote adjustment and saved keywords synchronize', (tester) async {
    final store = _MemoryStore();
    final session = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(session.dispose);
    await session.saveSource(_one);
    await _pump(tester, DanmakuSettingsSheet(session: session), size: const Size(390, 844), textScale: 1.5);
    for (final key in ['speed', 'max-on-screen', 'scroll-lines', 'top-lines', 'bottom-lines']) {
      final slider = find.byKey(ValueKey('danmaku-$key'));
      await tester.scrollUntilVisible(slider, 250, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      final focus = tester.widget<Focus>(find.descendant(of: slider, matching: find.byType(Focus)).first);
      focus.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    expect(session.presentation.speed, 1.25);
    expect(session.presentation.maxOnScreen, 61);
    expect(session.presentation.scrollLines, 13);
    expect(session.presentation.topLines, 4);
    expect(session.presentation.bottomLines, 4);
    final keywords = find.byKey(const ValueKey('danmaku-blocked-keywords'));
    await tester.scrollUntilVisible(keywords, 250, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(keywords);
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: keywords, matching: find.byType(TextField)), 'spoiler\nspam');
    await _tap(tester, find.text(t.common.save));
    expect(session.presentation.blockedKeywords, ['spoiler', 'spam']);
    await session.updateStyle(blockedKeywords: ['external']);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.descendant(of: keywords, matching: find.byType(TextField)));
    expect(field.controller!.text, 'external');
    final restored = DanmakuSession.forTesting(repository: store.repository);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.presentation.speed, 1.25);
    expect(restored.presentation.blockedKeywords, ['external']);
    expect(tester.takeException(), isNull);
  });
}
