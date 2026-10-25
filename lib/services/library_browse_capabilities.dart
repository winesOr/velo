import '../media/library_query.dart';
import '../media/media_backend.dart';
import '../media/media_filter.dart';

/// Validates restored selections before a translator can silently drop them.
/// Plex publishes its schema; MediaBrowser's supported grammar is fixed even
/// when facet discovery times out or a library has no values for a field.
class LibraryBrowseCapabilities {
  final MediaBackend backend;
  final List<MediaFilter> filters;

  const LibraryBrowseCapabilities({required this.backend, required this.filters});

  bool get supportsCountry => !backend.usesMediaBrowserApi && filters.any((f) => f.filter == 'country');

  List<LibraryFilter> supportedSelection(List<LibraryFilter> selection) {
    final claimed = <String>{};
    return selection
        .where((clause) {
          if (clause.values.isEmpty) return false;
          if (!backend.usesMediaBrowserApi) {
            return filters.any((f) => f.filter == clause.field && f.operators.contains(clause.op));
          }
          if (claimed.contains(clause.field)) return false;
          final supported = switch (clause.field) {
            MediaFilterField.unwatched =>
              (clause.op == LibraryFilterOperator.is_ || clause.op == LibraryFilterOperator.isNot) &&
                  clause.values.length == 1 &&
                  clause.values.single == '1',
            MediaFilterField.favorite =>
              clause.op == LibraryFilterOperator.is_ && clause.values.length == 1 && clause.values.single == '1',
            MediaFilterField.genre || MediaFilterField.tag || MediaFilterField.contentRating =>
              clause.op == LibraryFilterOperator.is_ && clause.values.every((v) => v.isNotEmpty),
            MediaFilterField.year =>
              clause.op == LibraryFilterOperator.is_ && clause.values.every((v) => int.tryParse(v) != null),
            _ => false,
          };
          if (supported) claimed.add(clause.field);
          return supported;
        })
        .toList(growable: false);
  }
}
