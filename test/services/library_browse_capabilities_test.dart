import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/library_query.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_filter.dart';
import 'package:plezy/services/library_browse_capabilities.dart';
import 'package:plezy/services/library_query_translator.dart';

void main() {
  for (final backend in [MediaBackend.jellyfin, MediaBackend.emby]) {
    test('${backend.id} retains supported conjunctions and removes region explicitly', () {
      final capabilities = LibraryBrowseCapabilities(backend: backend, filters: const []);
      final selection = capabilities.supportedSelection(const [
        LibraryFilter(field: 'country', values: ['Japan']),
        LibraryFilter(field: 'year', values: ['2024', '2025']),
        LibraryFilter(field: 'unwatched', op: LibraryFilterOperator.isNot, values: ['1']),
        LibraryFilter(field: 'genre', values: ['Drama']),
      ]);
      expect(capabilities.supportsCountry, isFalse);
      expect(selection.map((c) => c.field), ['year', 'unwatched', 'genre']);
      final wire = const JellyfinLibraryQueryTranslator(userId: 'u', parentId: 'p', fields: '').toQueryParameters(
        LibraryQuery(
          filters: selection,
          search: 'title',
          offset: 100,
          sort: const LibrarySort(field: 'rating'),
        ),
      );
      expect(wire['Years'], '2024,2025');
      expect(wire['Genres'], 'Drama');
      expect(wire['Filters'], 'IsPlayed');
      expect(wire['SearchTerm'], 'title');
      expect(wire['StartIndex'], '100');
      expect(wire['SortBy'], 'CommunityRating');
    });

    test('${backend.id} never claims unsupported ranges, exclusions, or duplicate conjunctions', () {
      final capabilities = LibraryBrowseCapabilities(backend: backend, filters: const []);
      final selection = capabilities.supportedSelection(const [
        LibraryFilter(field: 'year', op: LibraryFilterOperator.atLeast, values: ['2020']),
        LibraryFilter(field: 'year', values: ['invalid']),
        LibraryFilter(field: 'genre', op: LibraryFilterOperator.isNot, values: ['Drama']),
        LibraryFilter(field: 'favorite', op: LibraryFilterOperator.isNot, values: ['1']),
        LibraryFilter(field: 'genre', values: ['Action']),
        LibraryFilter(field: 'genre', values: ['Drama']),
      ]);
      expect(selection, [
        const LibraryFilter(field: 'genre', values: ['Action']),
      ]);
    });
  }

  test('Plex region and year operators depend on the discovered library schema', () {
    final capabilities = LibraryBrowseCapabilities(
      backend: MediaBackend.plex,
      filters: [
        MediaFilter(filter: 'country', filterType: 'tag', key: 'country', title: 'Country', type: 'filter'),
        MediaFilter(filter: 'year', filterType: 'integer', key: '', title: 'Year', type: 'filter'),
      ],
    );
    expect(capabilities.supportsCountry, isTrue);
    final selected = capabilities.supportedSelection(const [
      LibraryFilter(field: 'country', values: ['JP']),
      LibraryFilter(field: 'year', op: LibraryFilterOperator.atLeast, values: ['2020']),
      LibraryFilter(field: 'unknown', values: ['x']),
    ]);
    expect(selected.length, 2);
    final wire = const PlexLibraryQueryTranslator().toQueryParameters(LibraryQuery(filters: selected));
    expect(wire['country'], 'JP');
    expect(wire['year>>'], '2020');
  });
}
