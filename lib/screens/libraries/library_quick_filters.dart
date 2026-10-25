import 'package:flutter/material.dart';

import '../../focus/focusable_button.dart';
import '../../i18n/strings.g.dart';
import '../../media/library_query.dart';
import '../../media/media_filter.dart';
import '../../media/media_sort.dart';
import '../../theme/mono_presentation.dart';

/// Inline prototype rows use the same backend fields and persisted clauses as
/// the full editor. Never infer genres, countries or years from a loaded page.
class LibraryQuickFilters extends StatelessWidget {
  const LibraryQuickFilters({
    super.key,
    required this.filters,
    required this.values,
    required this.selection,
    required this.sorts,
    required this.selectedSort,
    required this.descending,
    required this.loadValues,
    required this.onFiltersChanged,
    required this.onSortChanged,
    required this.onMore,
  });

  final List<MediaFilter> filters;
  final Map<String, List<MediaFilterValue>> values;
  final List<LibraryFilter> selection;
  final List<MediaSort> sorts;
  final MediaSort? selectedSort;
  final bool descending;
  final Future<List<MediaFilterValue>> Function(MediaFilter) loadValues;
  final ValueChanged<List<LibraryFilter>> onFiltersChanged;
  final void Function(MediaSort sort, bool descending) onSortChanged;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    // Keep the existing compact filter/sort controls available when a phone
    // is sideways or the keyboard leaves little room for the poster grid.
    if (MediaQuery.sizeOf(context).height < 500 || MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final quickFilters = [
      for (final field in ['genre', 'country', 'year'])
        ...filters.where((filter) => filter.filter.split('.').last == field && filter.hasValueList),
    ];
    if (sorts.isEmpty && quickFilters.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sorts.isNotEmpty)
          _TagRow(
            children: [
              for (final sort in sorts)
                _Tag(
                  label: sort.title,
                  selected: selectedSort?.key == sort.key,
                  onPressed: () =>
                      onSortChanged(sort, selectedSort?.key == sort.key ? !descending : sort.isDefaultDescending),
                ),
            ],
          ),
        for (final filter in quickFilters)
          _QuickFilterValues(
            key: ValueKey('${filter.filter}:${filter.key}'),
            filter: filter,
            cached: values[filter.filter],
            load: loadValues,
            selection: selection,
            onChanged: onFiltersChanged,
            onMore: onMore,
          ),
      ],
    );
  }
}

class _QuickFilterValues extends StatefulWidget {
  const _QuickFilterValues({
    super.key,
    required this.filter,
    required this.cached,
    required this.load,
    required this.selection,
    required this.onChanged,
    required this.onMore,
  });

  final MediaFilter filter;
  final List<MediaFilterValue>? cached;
  final Future<List<MediaFilterValue>> Function(MediaFilter) load;
  final List<LibraryFilter> selection;
  final ValueChanged<List<LibraryFilter>> onChanged;
  final VoidCallback onMore;

  @override
  State<_QuickFilterValues> createState() => _QuickFilterValuesState();
}

class _QuickFilterValuesState extends State<_QuickFilterValues> {
  late final Future<List<MediaFilterValue>> _loaded = widget.load(widget.filter);

  void _select(String? id) {
    widget.onChanged([
      ...widget.selection.where((clause) => clause.field != widget.filter.filter),
      if (id != null) LibraryFilter(field: widget.filter.filter, values: [id]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    Widget row(List<MediaFilterValue> values) {
      if (values.isEmpty) return const SizedBox.shrink();
      final clauses = widget.selection.where((clause) => clause.field == widget.filter.filter);
      final title = widget.filter.title.isNotEmpty
          ? widget.filter.title
          : switch (widget.filter.filter.split('.').last) {
              'genre' => t.libraries.filterCategories.genre,
              'year' => t.libraries.filterCategories.year,
              _ => t.metadataEdit.country,
            };
      bool selected(String id) =>
          clauses.any((clause) => clause.op == LibraryFilterOperator.is_ && clause.values.contains(id));
      return _TagRow(
        children: [
          _Tag(label: title, selected: clauses.isEmpty, onPressed: () => _select(null)),
          for (final value in values.take(24))
            _Tag(
              label: value.title,
              selected: selected(libraryFilterValueId(value.key, widget.filter.filter)),
              onPressed: () {
                final id = libraryFilterValueId(value.key, widget.filter.filter);
                _select(selected(id) ? null : id);
              },
            ),
          _Tag(label: t.common.options, selected: false, onPressed: widget.onMore),
        ],
      );
    }

    if (widget.cached != null) return row(widget.cached!);
    return FutureBuilder<List<MediaFilterValue>>(
      future: _loaded,
      builder: (context, snapshot) => row(snapshot.data ?? const []),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: EdgeInsets.symmetric(horizontal: MonoPresentation.isTablet(context) ? 32 : 12),
    child: Row(children: children),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.selected, required this.onPressed});
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: FocusableButton(
        onPressed: onPressed,
        child: SizedBox(
          height: (MediaQuery.textScalerOf(context).scale(12) * 1.5 + 12).clamp(40, double.infinity),
          child: Center(
            child: Material(
              color: selected ? accent.withValues(alpha: .14) : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .65),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
