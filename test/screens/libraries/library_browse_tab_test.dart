import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_library.dart';
import 'package:plezy/models/plex/plex_config.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/screens/libraries/tabs/library_browse_tab.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/services/plex_api_cache.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/services/storage_service.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/focusable_media_card.dart';
import 'package:plezy/widgets/focusable_list_tile.dart';
import 'package:plezy/theme/mono_theme.dart';

import '../../test_helpers/backend_client_fixtures.dart';
import '../../test_helpers/library_tab_scaffold.dart';
import '../../test_helpers/multi_server_fixtures.dart';
import '../../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    await StorageService.getInstance();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('phone poster fixture fits at text scale $scale', (tester) async {
      final font = FontLoader('FusionFixture')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'));
      await font.load();
      await (FontLoader(
        'packages/material_symbols_icons/MaterialSymbolsRounded',
      )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final harness = _PlexBrowseHarness();
      addTearDown(harness.dispose);
      final boundary = GlobalKey();
      await pumpLibraryTab(
        tester,
        provider: harness.provider,
        size: const Size(390, 844),
        devicePixelRatio: 3,
        tab: RepaintBoundary(
          key: boundary,
          child: MediaQuery(
            data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(scale)),
            child: Theme(
              data: monoTheme(
                dark: true,
              ).copyWith(textTheme: monoTheme(dark: true).textTheme.apply(fontFamily: 'FusionFixture')),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: 'FusionFixture'),
                child: LibraryBrowseTab(library: harness.library, canGroupByFolders: true, isActive: true),
              ),
            ),
          ),
        ),
      );
      await pumpRequestFrames(tester);
      await tester.pumpAndSettle();
      final cards = find
          .byType(FocusableMediaCard)
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)))
          .toList();
      final firstRow = cards.where((rect) => (rect.top - cards.first.top).abs() < 1).toList();
      expect(firstRow.length, scale == 1 ? 3 : 1);
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(boundary), matchesGoldenFile('goldens/fusion_library_phone_${scale.toInt()}x.png'));
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('TV source sidebar and poster wall keep focus on a real item across paging', (tester) async {
    TvDetectionService.debugSetAppleTVOverride(true);
    addTearDown(() => TvDetectionService.debugSetAppleTVOverride(null));
    await (FontLoader('FusionFixture')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
    await (FontLoader(
      'packages/material_symbols_icons/MaterialSymbolsRounded',
    )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
    final harness = _PlexBrowseHarness(itemCount: 240);
    addTearDown(harness.dispose);
    final boundary = GlobalKey();
    await pumpLibraryTab(
      tester,
      provider: harness.provider,
      size: const Size(960, 540),
      tab: RepaintBoundary(
        key: boundary,
        child: Theme(
          data: monoTheme(
            dark: true,
          ).copyWith(textTheme: monoTheme(dark: true).textTheme.apply(fontFamily: 'FusionFixture')),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'FusionFixture'),
            child: LibraryBrowseTab(library: harness.library, canGroupByFolders: true, isActive: true),
          ),
        ),
      ),
    );
    await pumpRequestFrames(tester);
    await tester.pumpAndSettle();
    final category = tester.widget<FocusableListTile>(
      find.byWidgetPredicate((w) => w is FocusableListTile && w.focusNode?.debugLabel == 'grouping_chip'),
    );
    category.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_cardFor(tester, 'Movie 0').focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(category.focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    for (var i = 0; i < 14; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pumpAndSettle();
    expect(harness.pageRequestCount, greaterThan(1));
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FocusableMediaCard>(), isNotNull);
    category.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(boundary), matchesGoldenFile('goldens/fusion_library_tv.png'));
  });
}

FocusableMediaCard _cardFor(WidgetTester tester, String title) => tester.widget<FocusableMediaCard>(
  find.byWidgetPredicate((w) => w is FocusableMediaCard && (w.item as MediaItem).title == title),
);

class _PlexBrowseHarness {
  final int itemCount;
  static final _serverId = ServerId('plex-server');

  final AppDatabase database;
  late final MediaLibrary library;
  late final MultiServerManager manager;
  late final MultiServerProvider provider;
  var pageRequestCount = 0;
  var firstCharacterRequestCount = 0;
  var folderRequestCount = 0;
  var filterMetadataRequestCount = 0;
  final filterMetadataRequests = <Uri>[];

  _PlexBrowseHarness({this.itemCount = 100}) : database = AppDatabase.forTesting(NativeDatabase.memory()) {
    PlexApiCache.initialize(database);
    library = MediaLibrary(
      id: 'movies',
      backend: MediaBackend.plex,
      title: 'Movies',
      kind: MediaKind.movie,
      serverId: _serverId,
    );
    final client = testPlexClient(
      config: PlexConfig(
        baseUrl: 'https://plex.example.com',
        token: 'token',
        clientIdentifier: 'client-id',
        product: 'Plezy',
        version: 'test',
      ),
      serverId: _serverId,
      httpClient: MockClient(_handle),
    );
    manager = MultiServerManager()..debugRegisterClientForTesting(client);
    provider = testMultiServerProvider(manager);
  }

  Future<http.Response> _handle(http.Request request) async {
    Map<String, Object?> container;
    switch (request.url.path) {
      case '/library/sections/movies/all':
        // Filter discovery reads the same endpoint with `includeMeta=1` and
        // an explicit zero page size: it asks for the field/operator schema,
        // never for items, so it is not a page request.
        if (request.url.queryParameters['includeMeta'] == '1') {
          filterMetadataRequestCount++;
          filterMetadataRequests.add(request.url);
          return http.Response(
            jsonEncode({
              'MediaContainer': {
                'size': 0,
                'totalSize': itemCount,
                'Meta': {
                  'Type': [
                    {
                      'type': 'movie',
                      'active': true,
                      'Field': [
                        {'key': 'genre', 'title': 'Genre', 'type': 'tag'},
                        {'key': 'year', 'title': 'Year', 'type': 'integer'},
                        {'key': 'unwatched', 'title': 'Unwatched', 'type': 'boolean'},
                      ],
                    },
                  ],
                  'FieldType': [
                    {
                      'type': 'tag',
                      'Operator': [
                        {'key': '=', 'title': 'is'},
                        {'key': '!=', 'title': 'is not'},
                      ],
                    },
                    {
                      'type': 'integer',
                      'Operator': [
                        {'key': '=', 'title': 'is'},
                        {'key': '>>=', 'title': 'is greater than'},
                        {'key': '<<=', 'title': 'is less than'},
                      ],
                    },
                    {
                      'type': 'boolean',
                      'Operator': [
                        {'key': '=', 'title': 'is'},
                        {'key': '!=', 'title': 'is not'},
                      ],
                    },
                  ],
                },
              },
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        pageRequestCount++;
        final start = int.tryParse(request.url.queryParameters['X-Plex-Container-Start'] ?? '') ?? 0;
        final requested = int.tryParse(request.url.queryParameters['X-Plex-Container-Size'] ?? '') ?? itemCount;
        final end = (start + requested).clamp(0, itemCount);
        container = {
          'size': end - start,
          'totalSize': itemCount,
          'offset': start,
          'Metadata': [
            for (var i = start; i < end; i++)
              {
                'ratingKey': 'movie-$i',
                'type': 'movie',
                'title': 'Movie $i',
                'year': 2025 - i % 10,
                'rating': 8.5,
                'viewCount': i % 3 == 0 ? 1 : 0,
              },
          ],
        };
      case '/library/sections/movies/firstCharacter':
        firstCharacterRequestCount++;
        container = {
          'Directory': [
            for (final letter in const ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'])
              {'key': letter, 'title': letter, 'size': '${itemCount ~/ 8}'},
          ],
        };
      case '/library/sections/movies/folder':
        folderRequestCount++;
        container = {
          'Directory': [
            {'key': '/library/sections/movies/folder?parent=1', 'type': 'folder', 'title': 'Folder One'},
          ],
        };
      case '/library/sections/movies/sorts':
        container = {
          'Directory': [
            {'key': 'titleSort', 'descKey': 'titleSort:desc', 'title': 'Title', 'defaultDirection': 'asc'},
          ],
        };
      default:
        return http.Response('{}', 200, headers: const {'content-type': 'application/json'});
    }
    return http.Response(
      jsonEncode({'MediaContainer': container}),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }

  Future<void> dispose() async {
    provider.dispose();
    manager.dispose();
    await database.close();
  }
}
