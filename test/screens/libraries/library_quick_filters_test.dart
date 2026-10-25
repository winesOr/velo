import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/media/library_query.dart';
import 'package:plezy/media/media_filter.dart';
import 'package:plezy/media/media_sort.dart';
import 'package:plezy/screens/libraries/library_quick_filters.dart';
import 'package:plezy/theme/mono_theme.dart';

void main() {
  final genre = MediaFilter(filter: 'genre', filterType: 'tag', key: '/genres', title: 'Genre', type: 'filter');
  const sorts = [MediaSort(key: 'addedAt', title: 'Added', defaultDirection: 'desc')];

  Future<void> pump(
    WidgetTester tester, {
    List<MediaFilter>? filters,
    Map<String, List<MediaFilterValue>>? values,
    List<LibraryFilter> selection = const [],
    ValueChanged<List<LibraryFilter>>? onChanged,
    void Function(MediaSort, bool)? onSort,
    MediaSort? selectedSort,
    Future<List<MediaFilterValue>> Function(MediaFilter)? load,
    double scale = 1,
    double height = 640,
    double keyboard = 0,
  }) async {
    await tester.pumpWidget(
      InputModeTracker(
        child: MaterialApp(
          theme: monoTheme(dark: true),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(320, height),
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: keyboard),
              ),
              child: LibraryQuickFilters(
                filters: filters ?? [genre],
                values:
                    values ??
                    {
                      'genre': [MediaFilterValue(key: 'Science%20Fiction', title: 'Sci-fi')],
                    },
                selection: selection,
                sorts: sorts,
                selectedSort: selectedSort,
                descending: true,
                loadValues: load ?? (_) async => [],
                onFiltersChanged: onChanged ?? (_) {},
                onSortChanged: onSort ?? (_, _) {},
                onMore: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('quick value preserves other clauses and uses decoded server identity', (tester) async {
    List<LibraryFilter>? result;
    const watched = LibraryFilter(field: 'unwatched', op: LibraryFilterOperator.isNot, values: ['1']);
    await pump(tester, selection: [watched], onChanged: (next) => result = next);
    await tester.tap(find.text('Sci-fi'));
    expect(result, [
      watched,
      const LibraryFilter(field: 'genre', values: ['Science Fiction']),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing a row removes all operators for that field only', (tester) async {
    List<LibraryFilter>? result;
    const year = LibraryFilter(field: 'year', values: ['2026']);
    await pump(
      tester,
      selection: [
        year,
        const LibraryFilter(field: 'genre', op: LibraryFilterOperator.isNot, values: ['Comedy']),
      ],
      onChanged: (next) => result = next,
    );
    await tester.tap(find.text('Genre'));
    expect(result, [year]);
  });

  testWidgets('cached MediaBrowser values never invoke a Plex value loader', (tester) async {
    await pump(tester, load: (_) => throw StateError('must use the server discovery payload'));
    expect(find.text('Sci-fi'), findsOneWidget);
    expect(find.text('Country'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plex loads listed values once and does not invent an unlisted numeric year', (tester) async {
    var loads = 0;
    final year = MediaFilter(filter: 'year', filterType: 'integer', key: '', title: 'Year', type: 'filter');
    await pump(
      tester,
      filters: [genre, year],
      values: {},
      load: (_) async {
        loads++;
        return [MediaFilterValue(key: '42', title: 'Drama')];
      },
    );
    expect(loads, 1);
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Year'), findsNothing);
  });

  testWidgets('sort uses backend default direction and toggles the active field', (tester) async {
    bool? direction;
    await pump(tester, onSort: (_, next) => direction = next);
    await tester.tap(find.text('Added'));
    expect(direction, isTrue);
    await pump(tester, selectedSort: sorts.first, onSort: (_, next) => direction = next);
    await tester.tap(find.text('Added'));
    expect(direction, isFalse);
  });

  testWidgets('narrow rows respect system text scaling without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, scale: 2);
    expect(find.text('Sci-fi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape and keyboard leave space for the existing compact toolbar', (tester) async {
    await pump(tester, height: 360, scale: 2);
    expect(find.text('Sci-fi'), findsNothing);
    await pump(tester, keyboard: 300);
    expect(find.text('Sci-fi'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
