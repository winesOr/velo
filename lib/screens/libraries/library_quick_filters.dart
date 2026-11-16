import 'package:flutter/material.dart';

import '../../focus/focusable_button.dart';
import '../../i18n/strings.g.dart';
import '../../media/library_query.dart';
import '../../media/media_filter.dart';
import '../../media/media_sort.dart';
import '../../theme/mono_presentation.dart';
import '../../theme/velo_brand.dart';

/// Inline prototype rows use the same backend fields and persisted clauses as
/// the full editor. Server facet IDs remain unchanged when a tag is selected.
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
    final quickSorts = <(MediaSort, String)>[
      for (final (key, label) in [
        ('addedAt', t.libraries.wallSort.updated),
        ('originallyAvailableAt', t.libraries.wallSort.released),
        ('rating', t.libraries.wallSort.rating),
      ])
        for (final sort in sorts.where((sort) => sort.key == key).take(1)) (sort, label),
    ];
    final quickFilters = [
      for (final field in ['genre', 'country', 'year'])
        ...filters.where((filter) => filter.filter.split('.').last == field && filter.hasValueList),
    ];
    if (sorts.isEmpty && quickFilters.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quickSorts.isNotEmpty)
          _TagRow(
            children: [
              for (final (sort, label) in quickSorts)
                _Tag(
                  label: label,
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
      bool selected(String id) =>
          clauses.any((clause) => clause.op == LibraryFilterOperator.is_ && clause.values.contains(id));
      return _TagRow(
        children: [
          _Tag(label: t.libraries.unrestricted, selected: clauses.isEmpty, onPressed: () => _select(null)),
          for (final value in values.take(24))
            _Tag(
              label: value.title,
              selected: selected(libraryFilterValueId(value.key, widget.filter.filter)),
              onPressed: () {
                final id = libraryFilterValueId(value.key, widget.filter.filter);
                _select(selected(id) ? null : id);
              },
            ),
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
    padding: EdgeInsets.symmetric(horizontal: MonoPresentation.isTablet(context) ? 32 : 17),
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
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: FocusableButton(
        onPressed: onPressed,
        child: SizedBox(
          height: (MediaQuery.textScalerOf(context).scale(15) * 1.2 + 12).clamp(32, double.infinity),
          child: Center(
            child: Material(
              color: selected ? VeloBrand.selection(theme.brightness) : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .65),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        fontVariations: selected ? const [FontVariation('wght', 650)] : null,
                        color: selected ? VeloBrand.foreground(theme.brightness) : theme.colorScheme.onSurfaceVariant,
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
