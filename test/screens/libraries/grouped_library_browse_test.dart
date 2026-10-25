import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/focusable_text_field.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/library_query.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
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
}) async {
  if (size != null) await loadTabletFonts(loadDefaultFont: true);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size ?? (tv ? const Size(960, 540) : const Size(390, 844));
  addTearDown(tester.view.reset);
  TvDetectionService.debugSetAppleTVOverride(tv ? true : null);
  addTearDown(() => TvDetectionService.debugSetAppleTVOverride(null));
  final servers = testMultiServer();
  await tester.pumpWidget(
    ChangeNotifierProvider<MultiServerProvider>.value(
      value: servers.provider,
      child: InputModeTracker(
        child: MaterialApp(
          theme: size != null ? tabletFixtureTheme(monoTheme(dark: true)) : monoTheme(dark: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey("tablet-library"),
              child: ColoredBox(
                color: const Color(0xff000000),
                child: GroupedLibraryBrowse(libraries: const [libraryA, libraryB], fetchPage: fetcher),
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
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  for (final size in [const Size(820, 1180), const Size(1180, 820)]) {
    testWidgets('tablet library preserves touch filters and source grids at $size', (tester) async {
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
      expect(find.byKey(const ValueKey('grouped-library-filter-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureTablet(tester, find.byKey(const ValueKey('tablet-library')), 'library-${size.width.toInt()}');
      await tester.tap(find.byKey(const ValueKey('grouped-library-filter-button')));
      await tester.pumpAndSettle();
      expect(find.text(t.libraries.allYears), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('group errors do not hide available sources and search queries every source', (tester) async {
    final requests = <(String, String?)>[];
    await pumpGrouped(tester, (library, query, abort) async {
      requests.add((library.globalKey, query.search));
      if (library.serverId == libraryA.serverId) throw StateError('offline');
      return const LibraryPage(items: [], totalCount: 0);
    });
    expect(find.text('Library A'), findsOneWidget);
    expect(find.text('Library B'), findsOneWidget);
    expect(find.text('Source A'), findsOneWidget);
    expect(find.text('Source B'), findsOneWidget);
    expect(find.text(t.libraries.groupedLoadFailed), findsOneWidget);
    expect(find.text(t.libraries.groupedFacetUnavailable), findsOneWidget);
    final search = find.byWidgetPredicate(
      (widget) => widget is FocusableTextField && widget.focusNode?.debugLabel == 'all_sources_search',
    );
    await tester.enterText(find.descendant(of: search, matching: find.byType(TextField)), 'new title');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.$2 == 'new title').map((r) => r.$1), [libraryA.globalKey, libraryB.globalKey]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV source poster transfers left to filters and right to real content', (tester) async {
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
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.ancestors.any((n) => n.debugLabel == 'all_sources_filters'), isTrue);
    final search = tester.widget<FocusableTextField>(
      find.byWidgetPredicate(
        (widget) => widget is FocusableTextField && widget.focusNode?.debugLabel == 'all_sources_search',
      ),
    );
    search.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(first.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text keeps type tabs scrollable and detailed filters in a centered panel', (tester) async {
    await pumpGrouped(tester, (_, query, _) async => const LibraryPage(items: [], totalCount: 0), textScale: 2);
    expect(find.text(t.libraries.allYears), findsNothing);
    await tester.tap(find.byKey(const ValueKey('grouped-library-filter-button')));
    await tester.pumpAndSettle();
    expect(find.text(t.libraries.allYears), findsOneWidget);
    final panel = tester.getRect(
      find.descendant(of: find.byKey(const ValueKey('grouped-library-filters')), matching: find.byType(Material)).first,
    );
    expect(panel.top, greaterThan(12));
    expect(panel.bottom, lessThan(844 - 12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone keeps combined conditions when reopening filters and clears every source', (tester) async {
    final requests = <LibraryQuery>[];
    await pumpGrouped(tester, (_, query, _) async {
      requests.add(query);
      return const LibraryPage(items: [], totalCount: 0);
    });
    final search = find.byWidgetPredicate(
      (widget) => widget is FocusableTextField && widget.focusNode?.debugLabel == 'all_sources_search',
    );
    await tester.enterText(find.descendant(of: search, matching: find.byType(TextField)), 'film');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grouped-library-filter-button')));
    await tester.pumpAndSettle();
    final year = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == t.libraries.allYears,
    );
    await tester.enterText(year, '2025');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.libraries.allWatchStates));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.libraries.watched));
    await tester.pumpAndSettle();
    expect(requests.last.search, 'film');
    expect(requests.last.filters.map((filter) => filter.field), ['year', 'unwatched']);
    expect(requests.last.filters.first.values, ['2025']);
    expect(requests.last.filters.last.op, LibraryFilterOperator.isNot);
    await tester.tap(find.text(t.common.close));
    await tester.pumpAndSettle();
    expect(find.text('2025 · ${t.libraries.watched}'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('grouped-library-filter-button')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(year).controller!.text, '2025');
    await tester.tap(find.text(t.libraries.resetFilters));
    await tester.pumpAndSettle();
    expect(requests.last.search, isNull);
    expect(requests.last.filters, isEmpty);
    expect(find.text(t.libraries.groupedFacetUnavailable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
