import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/focusable_text_field.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/library_query.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_person.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/widgets/person_search_row.dart';
import 'package:plezy/media/media_library.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/screens/libraries/grouped_library_browse.dart';
import 'package:plezy/screens/libraries/grouped_library_controller.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/focusable_media_card.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/multi_server_fixtures.dart';
import '../../test_helpers/prefs.dart';
import '../../test_helpers/tablet_screenshots.dart';

const libraryA = MediaLibrary(
  id: 'movies',
  backend: MediaBackend.plex,
  title: 'Library A',
  kind: MediaKind.movie,
  serverId: 'server-a',
  serverName: 'Source A',
);
const libraryB = MediaLibrary(
  id: 'movies',
  backend: MediaBackend.emby,
  title: 'Library B',
  kind: MediaKind.movie,
  serverId: 'server-b',
  serverName: 'Source B',
);

Future<void> pumpGrouped(
  WidgetTester tester,
  GroupedLibraryFetcher fetcher, {
  bool tv = false,
  Size? size,
  double textScale = 1,
  GroupedPeopleFetcher? fetchPeople,
  FocusNode? headerSearchFocus,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size ?? (tv ? const Size(960, 540) : const Size(390, 844));
  addTearDown(tester.view.reset);
  TvDetectionService.debugSetAppleTVOverride(tv ? true : null);
  addTearDown(() => TvDetectionService.debugSetAppleTVOverride(null));
  final servers = testMultiServer();
  final searchController = headerSearchFocus == null ? null : TextEditingController();
  if (searchController != null) addTearDown(searchController.dispose);
  final browser = GroupedLibraryBrowse(
    libraries: const [libraryA, libraryB],
    fetchPage: fetcher,
    fetchPeople: fetchPeople ?? (_, _, _, _) async => [],
    searchController: searchController,
    searchFocusNode: headerSearchFocus,
    searchInHeader: headerSearchFocus != null,
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<MultiServerProvider>.value(
      value: servers.provider,
      child: InputModeTracker(
        child: MaterialApp(
          theme: (size != null ? tabletFixtureTheme(monoTheme(dark: true)) : monoTheme(dark: true)).copyWith(
            platform: TargetPlatform.android,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey("tablet-library"),
              child: ColoredBox(
                color: const Color(0xff000000),
                child: headerSearchFocus == null
                    ? browser
                    : Column(
                        children: [
                          SizedBox(
                            height: 48,
                            child: FocusableTextField(
                              controller: searchController!,
                              focusNode: headerSearchFocus,
                              tvTextInputAutoOpenBehavior: TvTextInputAutoOpenBehavior.never,
                            ),
                          ),
                          Expanded(child: browser),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => loadTabletFonts(loadDefaultFont: true));

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  for (final size in [const Size(820, 1180), const Size(1180, 820)]) {
    testWidgets('tablet library uses the merged wall and inline facets at $size', (tester) async {
      await pumpGrouped(
        tester,
        (library, query, abort) async => LibraryPage(
          items: [
            for (var i = 0; i < 8; i++)
              MediaItem(
                id: 'film-$i',
                backend: library.backend,
                kind: MediaKind.movie,
                title: 'Film $i',
                serverId: library.serverId,
              ),
          ],
          totalCount: 8,
        ),
        size: size,
      );
      expect(find.byKey(const ValueKey('wall-types')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureTablet(tester, find.byKey(const ValueKey('tablet-library')), 'library-${size.width.toInt()}');
      expect(find.byKey(const ValueKey('grouped-library-filter-button')), findsNothing);
      expect(find.byKey(const ValueKey('wall-years')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('group errors do not hide available sources and search queries every source', (tester) async {
    final requests = <(String, String?)>[];
    await pumpGrouped(tester, (library, query, abort) async {
      requests.add((library.globalKey, query.search));
      if (library.serverId == libraryA.serverId) throw StateError('offline');
      return const LibraryPage(items: [], totalCount: 0);
    });
    expect(find.text('Library A'), findsNothing);
    expect(find.text('Library B'), findsNothing);
    expect(find.text(t.libraries.groupedLoadFailed), findsOneWidget);
    expect(find.text(t.libraries.groupedFacetUnavailable), findsNothing);
    final search = find.byWidgetPredicate(
      (widget) => widget is FocusableTextField && widget.focusNode?.debugLabel == 'all_sources_search',
    );
    await tester.enterText(find.descendant(of: search, matching: find.byType(TextField)), 'new title');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.$2 == 'new title').map((r) => r.$1), [libraryA.globalKey, libraryB.globalKey]);
    tester.state<GroupedLibraryBrowseState>(find.byType(GroupedLibraryBrowse)).submitSearchQuery('remote title');
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.$2 == 'remote title').map((r) => r.$1), [libraryA.globalKey, libraryB.globalKey]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV library uses five horizontal filter rows and a seven-column wall', (tester) async {
    await pumpGrouped(
      tester,
      (library, query, abort) async => LibraryPage(
        items: [
          for (var i = 0; i < 8; i++)
            MediaItem(
              id: 'film-$i',
              backend: library.backend,
              kind: MediaKind.movie,
              title: 'Film $i',
              year: 2020 + i,
              serverId: library.serverId,
            ),
        ],
        totalCount: 8,
      ),
      tv: true,
      size: const Size(960, 540),
    );
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
    final layout =
        grid.gridDelegate.getLayout(
              const SliverConstraints(
                axisDirection: AxisDirection.down,
                growthDirection: GrowthDirection.forward,
                userScrollDirection: ScrollDirection.idle,
                scrollOffset: 0,
                precedingScrollExtent: 0,
                overlap: 0,
                remainingPaintExtent: 540,
                crossAxisExtent: 892,
                crossAxisDirection: AxisDirection.right,
                viewportMainAxisExtent: 540,
                remainingCacheExtent: 540,
                cacheOrigin: 0,
              ),
            )
            as SliverGridRegularTileLayout;
    expect(layout.crossAxisCount, 7);
    expect(find.byKey(const ValueKey('wall-years')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureTv(tester, find.byKey(const ValueKey('tablet-library')), 'library');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('TV poster returns to the year row and remote search restores result focus', (tester) async {
    await pumpGrouped(
      tester,
      (library, query, abort) async => LibraryPage(
        items: [
          MediaItem(
            id: 'same',
            backend: library.backend,
            kind: MediaKind.movie,
            title: 'Film ${library.serverName}',
            serverId: library.serverId,
          ),
        ],
        totalCount: 1,
      ),
      tv: true,
    );
    final first = tester.widget<FocusableMediaCard>(find.byType(FocusableMediaCard).first);
    first.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      first.focusNode!.hasFocus,
      isTrue,
      reason: 'the last partial row retains its real card rather than the footer',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.ancestors.any((n) => n.debugLabel == 'wall-years'), isTrue);
    final search = tester.widget<FocusableTextField>(
      find.byWidgetPredicate(
        (widget) => widget is FocusableTextField && widget.focusNode?.debugLabel == 'all_sources_search',
      ),
    );
    search.focusNode!.requestFocus();
    await tester.pump();
    tester.state<GroupedLibraryBrowseState>(find.byType(GroupedLibraryBrowse)).submitSearchQuery('Film');
    await tester.pumpAndSettle();
    final result = tester.widget<FocusableMediaCard>(find.byType(FocusableMediaCard).first);
    expect(result.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final reset in ['none', 'query', 'facet', 'refresh', 'leave-search']) {
    testWidgets('TV delayed wall paging preserves focus across twenty frames with $reset reset', (tester) async {
      final persistentSearch = reset == 'leave-search' ? FocusNode(debugLabel: 'all_sources_search') : null;
      if (persistentSearch != null) addTearDown(persistentSearch.dispose);
      final gate = Completer<LibraryPage<MediaItem>>();
      final offsets = <int>[];
      var resetting = false;
      LibraryPage<MediaItem> page(int start, int end) => LibraryPage(
        items: [
          for (var index = start; index < end; index++)
            MediaItem(
              id: 'film-${index.toString().padLeft(3, '0')}',
              backend: libraryA.backend,
              kind: MediaKind.movie,
              title: 'Film ${index.toString().padLeft(3, '0')}',
              year: 2025,
              serverId: libraryA.serverId,
            ),
        ],
        totalCount: 43,
      );
      await pumpGrouped(
        tester,
        (library, query, abort) async {
          if (library.serverId != libraryA.serverId) return const LibraryPage(items: [], totalCount: 0);
          offsets.add(query.offset);
          if (query.offset == 0) return page(0, resetting ? 43 : 36);
          return gate.future;
        },
        tv: true,
        headerSearchFocus: persistentSearch,
      );
      final search = tester
          .widget<FocusableTextField>(
            find.byWidgetPredicate(
              (widget) => widget is FocusableTextField && widget.focusNode?.debugLabel == 'all_sources_search',
            ),
          )
          .focusNode!;
      final selectYear = tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(const ValueKey('wall-years')),
              matching: find.widgetWithText(TextButton, '2025'),
            ),
          )
          .onPressed!;
      final wall = find.byKey(const PageStorageKey('all_sources_merged_wall'));
      final scroll = tester.widget<CustomScrollView>(wall).controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      FocusableMediaCard card(int index) => tester.widget<FocusableMediaCard>(
        find.byKey(ValueKey('wall/plex/server-a:film-${index.toString().padLeft(3, '0')}')),
      );
      final origin = card(35).focusNode!;
      origin.requestFocus();
      await tester.pump();
      expect(offsets, [0, 36], reason: 'automatic pagination is already waiting before the key is pressed');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(origin.hasFocus, isTrue, reason: 'loading must preserve the real card on frame $frame');
      }
      if (reset == 'leave-search') {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(search.hasFocus, isTrue, reason: 'left returns to the actual persistent header search');
        expect(origin.hasFocus, isFalse);
      } else if (reset != 'none') {
        scroll.jumpTo(0);
        await tester.pump();
        search.requestFocus();
        resetting = true;
        final state = tester.state<GroupedLibraryBrowseState>(find.byType(GroupedLibraryBrowse));
        switch (reset) {
          case 'query':
            state.updateSearchQuery('Film');
          case 'facet':
            selectYear();
          case 'refresh':
            state.refresh();
        }
        await tester.pump(const Duration(milliseconds: 400));
      }
      gate.complete(page(36, 43));
      await tester.pumpAndSettle();
      if (reset == 'none') {
        expect(card(42).focusNode!.hasFocus, isTrue, reason: 'the delayed next row resumes the original request');
      } else {
        expect(search.hasFocus, isTrue, reason: 'a stale wall index must not steal focus from $reset results');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large text keeps all five inline facet rows scrollable', (tester) async {
    await pumpGrouped(tester, (_, query, _) async => const LibraryPage(items: [], totalCount: 0), textScale: 2);
    expect(find.byKey(const ValueKey('wall-types')), findsOneWidget);
    expect(find.byKey(const ValueKey('wall-sort')), findsOneWidget);
    expect(find.byKey(const ValueKey('wall-genres')), findsOneWidget);
    expect(find.byKey(const ValueKey('wall-countries')), findsOneWidget);
    expect(find.byKey(const ValueKey('wall-years')), findsOneWidget);
    expect(find.byKey(const ValueKey('grouped-library-filter-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone combines real facets, reverses sorting and filters keywords in the wall', (tester) async {
    final requests = <LibraryQuery>[];
    await pumpGrouped(
      tester,
      (library, query, _) async {
        requests.add(query);
        return LibraryPage(
          items: [
            MediaItem(
              id: 'film',
              backend: library.backend,
              serverId: library.serverId,
              kind: MediaKind.movie,
              title: 'Film',
              year: 2025,
              genres: ['Drama'],
            ).copyWith(countries: ['US']),
            MediaItem(
              id: 'other',
              backend: library.backend,
              serverId: library.serverId,
              kind: MediaKind.movie,
              title: 'Other',
              year: 2024,
              genres: ['Comedy'],
            ).copyWith(countries: ['Japan']),
          ],
          totalCount: 2,
        );
      },
      fetchPeople: (library, query, excluded, abort) async => [
        MediaPerson(id: 'actor', name: query, backend: library.backend, serverId: ServerId(library.serverId!)),
      ],
    );
    final search = find.byWidgetPredicate(
      (widget) => widget is FocusableTextField && widget.focusNode?.debugLabel == 'all_sources_search',
    );
    await tester.enterText(find.descendant(of: search, matching: find.byType(TextField)), 'film');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(requests.last.search, 'film');
    expect(find.byType(PersonSearchRow), findsWidgets);
    await tester.tap(find.text('Drama'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('US'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('wall-years')), matching: find.text('2025')));
    await tester.pumpAndSettle();
    final cards = tester.widgetList<FocusableMediaCard>(find.byType(FocusableMediaCard));
    expect(cards.every((card) => (card.item as MediaItem).id == 'film'), isTrue);
    expect(requests.last.filters, isEmpty, reason: 'local facets must keep independent server cursors stable');

    await tester.tap(find.byKey(const ValueKey('wall-sort-updated')));
    await tester.pumpAndSettle();
    expect(requests.last.sort?.direction, LibrarySortDirection.ascending);
    await tester.tap(find.byKey(const ValueKey('wall-sort-updated')));
    await tester.pumpAndSettle();
    expect(requests.last.sort?.direction, LibrarySortDirection.descending);
    await tester.tap(find.byTooltip(t.common.clear));
    await tester.pumpAndSettle();
    expect(requests.last.search, isNull);
    expect(find.byType(PersonSearchRow), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
