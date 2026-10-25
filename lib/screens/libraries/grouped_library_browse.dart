import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/mono_presentation.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../focus/focusable_button.dart';
import '../../focus/focusable_text_field.dart';
import '../../i18n/strings.g.dart';
import '../../media/media_item.dart';
import '../../media/media_kind.dart';
import '../../media/media_library.dart';
import '../../providers/libraries_provider.dart';
import '../../services/settings_service.dart';
import '../../utils/platform_detector.dart';
import '../../utils/dialogs.dart';
import '../../utils/provider_extensions.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_menu.dart';
import '../../widgets/backend_badge.dart';
import '../../widgets/focusable_media_card.dart';
import '../../widgets/media_card_sliver_layout.dart';
import '../../widgets/settings_builder.dart';
import 'grouped_library_controller.dart';
import 'library_server_label.dart';

const allLibrarySourcesKey = '__plezy_all_library_sources__';

class GroupedLibraryBrowse extends StatefulWidget {
  const GroupedLibraryBrowse({super.key, required this.libraries, this.onBack, this.fetchPage});

  final List<MediaLibrary> libraries;
  final VoidCallback? onBack;
  final GroupedLibraryFetcher? fetchPage;

  @override
  State<GroupedLibraryBrowse> createState() => GroupedLibraryBrowseState();
}

class GroupedLibraryBrowseState extends State<GroupedLibraryBrowse> {
  late final GroupedLibraryController _controller;
  final _search = TextEditingController();
  final _year = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'all_sources_search');
  final _scroll = ScrollController();
  final _contentFocus = FocusScopeNode(debugLabel: 'all_sources_content');
  final _filterFocus = FocusScopeNode(debugLabel: 'all_sources_filters');
  final Map<String, FocusNode> _nodes = {};
  final Map<String, int> _epochs = {};
  Timer? _debounce;
  MediaKind? _kind;
  bool? _watched;
  GroupedLibrarySort _sort = GroupedLibrarySort.title;

  GroupedLibrarySelection get _selection => GroupedLibrarySelection(
    search: _search.text,
    year: int.tryParse(_year.text),
    kind: _kind,
    watched: _watched,
    sort: _sort,
  );

  @override
  void initState() {
    super.initState();
    _controller = GroupedLibraryController(
      fetchPage:
          widget.fetchPage ??
          (library, query, abort) async {
            final provider = Provider.of<LibrariesProvider?>(context, listen: false);
            final epoch = provider?.libraryContentEpoch(library.globalKey);
            final page = await context
                .getMediaClientForLibrary(library)
                .fetchLibraryPagedContent(library.id, query: query, libraryKind: library.kind, abort: abort);
            if (!abort.isAborted && epoch != null && query.offset == 0) _epochs[library.globalKey] = epoch;
            return page;
          },
    );
    _controller.reset(widget.libraries, _selection);
  }

  @override
  void didUpdateWidget(GroupedLibraryBrowse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.libraries, widget.libraries)) refresh();
  }

  void refresh() => _queryChanged();

  void refreshIfStale() {
    final provider = Provider.of<LibrariesProvider?>(context, listen: false);
    if (provider != null &&
        widget.libraries.any(
          (library) => provider.libraryContentEpoch(library.globalKey) != _epochs[library.globalKey],
        )) {
      refresh();
    }
  }

  void focusContent() {
    final nodes = _nodes.values.where((node) => node.context != null && node.canRequestFocus);
    if (nodes.isNotEmpty) {
      nodes.first.requestFocus();
    } else {
      _searchFocus.requestFocus();
    }
  }

  void _queryChanged({bool debounce = false}) {
    _debounce?.cancel();
    // Invalidate now, not after the typing delay: an old page must not commit.
    _controller.reset(widget.libraries, _selection, load: !debounce);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (debounce) _debounce = Timer(const Duration(milliseconds: 350), _controller.loadAll);
  }

  void _reset() {
    _search.clear();
    _year.clear();
    _kind = null;
    _watched = null;
    _sort = GroupedLibrarySort.title;
    _queryChanged();
  }

  FocusNode _node(String key) => _nodes.putIfAbsent(key, () => FocusNode(debugLabel: key));
  String _itemKey(LibraryBrowseGroup group, int index) => '${group.library.globalKey}/${group.items[index].globalKey}';

  void _focusItem(LibraryBrowseGroup group, int index, {int attempt = 0}) {
    if (!mounted || !_controller.groups.contains(group)) return;
    final node = _node(_itemKey(group, index));
    if (node.context != null) {
      node.requestFocus();
      return;
    }
    if (!_scroll.hasClients || attempt >= 12) return;
    final forward = index > 0;
    _scroll.jumpTo((_scroll.offset + (forward ? 240 : -240)).clamp(0.0, _scroll.position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusItem(group, index, attempt: attempt + 1));
  }

  Widget _choice<T>(String label, List<AppMenuEntry<T>> entries, ValueChanged<T> onSelected) => AppMenuButton<T>(
    tooltip: label,
    adaptiveSheet: true,
    entriesBuilder: (_) => entries,
    onSelected: onSelected,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          const AppIcon(Symbols.expand_more_rounded, size: 18),
        ],
      ),
    ),
  );

  List<Widget> _controls(bool tv) => [
    SizedBox(
      width: double.infinity,
      child: FocusableTextField(
        controller: _search,
        focusNode: _searchFocus,
        tvTextInputAutoOpenBehavior: TvTextInputAutoOpenBehavior.never,
        decoration: InputDecoration(
          hintText: t.libraries.searchHint,
          prefixIcon: const AppIcon(Symbols.search_rounded),
          isDense: true,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        onChanged: (_) => _queryChanged(debounce: true),
        onSubmitted: (_) => _queryChanged(),
        onNavigateRight: tv ? focusContent : null,
        onBack: widget.onBack,
      ),
    ),
    _choice<String>(
      _kind?.label ?? t.libraries.groupings.all,
      [
        AppMenuItem(value: '', label: t.libraries.groupings.all, selected: _kind == null),
        for (final kind in [MediaKind.movie, MediaKind.show, MediaKind.artist, MediaKind.clip])
          AppMenuItem(value: kind.id, label: kind.label, selected: _kind == kind),
      ],
      (value) {
        _kind = value.isEmpty ? null : MediaKind.fromString(value);
        _queryChanged();
      },
    ),
    SizedBox(
      width: double.infinity,
      child: FocusableTextField(
        controller: _year,
        tvTextInputAutoOpenBehavior: TvTextInputAutoOpenBehavior.never,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        decoration: InputDecoration(labelText: t.libraries.allYears, isDense: true),
        onChanged: (_) => _queryChanged(debounce: true),
        onSubmitted: (_) => _queryChanged(),
        onNavigateRight: tv ? focusContent : null,
        onBack: widget.onBack,
      ),
    ),
    _choice<String>(
      _watched == null
          ? t.libraries.allWatchStates
          : _watched!
          ? t.libraries.watched
          : t.libraries.filterCategories.unwatched,
      [
        AppMenuItem(value: '', label: t.libraries.allWatchStates, selected: _watched == null),
        AppMenuItem(value: 'watched', label: t.libraries.watched, selected: _watched == true),
        AppMenuItem(value: 'unwatched', label: t.libraries.filterCategories.unwatched, selected: _watched == false),
      ],
      (value) {
        _watched = value.isEmpty ? null : value == 'watched';
        _queryChanged();
      },
    ),
    _choice<GroupedLibrarySort>(
      '${t.libraries.sort}: ${switch (_sort) {
        GroupedLibrarySort.title => t.libraries.sortLabels.title,
        GroupedLibrarySort.year => t.libraries.sortLabels.productionYear,
        GroupedLibrarySort.rating => t.libraries.sortLabels.rating,
      }}',
      [
        AppMenuItem(
          value: GroupedLibrarySort.title,
          label: t.libraries.sortLabels.title,
          selected: _sort == GroupedLibrarySort.title,
        ),
        AppMenuItem(
          value: GroupedLibrarySort.year,
          label: t.libraries.sortLabels.productionYear,
          selected: _sort == GroupedLibrarySort.year,
        ),
        AppMenuItem(
          value: GroupedLibrarySort.rating,
          label: t.libraries.sortLabels.rating,
          selected: _sort == GroupedLibrarySort.rating,
        ),
      ],
      (value) {
        _sort = value;
        _queryChanged();
      },
    ),
    FocusableButton(
      onPressed: _reset,
      onNavigateRight: tv ? focusContent : null,
      onBack: widget.onBack,
      child: TextButton.icon(
        onPressed: _reset,
        icon: const AppIcon(Symbols.restart_alt_rounded),
        label: Text(t.libraries.resetFilters),
      ),
    ),
  ];

  String get _conditionSummary => [
    if (_year.text.isNotEmpty) _year.text,
    if (_watched != null) _watched! ? t.libraries.watched : t.libraries.filterCategories.unwatched,
  ].join(' · ');

  Future<void> _showFilters() => showScopedDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      key: const ValueKey('grouped-library-filters'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final controls = _controls(false);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.libraries.filters, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 20),
                  controls[2],
                  const SizedBox(height: 12),
                  controls[3],
                  const SizedBox(height: 12),
                  Text(t.libraries.groupedFacetUnavailable, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  controls[5],
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t.common.close)),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _mobileControls() {
    final controls = _controls(false);
    return Padding(
      padding: EdgeInsets.fromLTRB(MonoPresentation.pageInset(context), 8, MonoPresentation.pageInset(context), 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          controls[0],
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final kind in [null, MediaKind.movie, MediaKind.show, MediaKind.artist, MediaKind.clip])
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _kind == kind ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: TextButton(
                        onPressed: () {
                          _kind = kind;
                          _queryChanged();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size(48, 44),
                          foregroundColor: _kind == kind
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: Text(kind?.label ?? t.libraries.groupings.all),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TextButton.icon(
                  key: const ValueKey('grouped-library-filter-button'),
                  onPressed: _showFilters,
                  icon: const AppIcon(Symbols.tune_rounded, size: 18),
                  label: Text(_conditionSummary.isEmpty ? t.libraries.filters : _conditionSummary),
                ),
                controls[4],
                if (_conditionSummary.isNotEmpty)
                  IconButton(
                    tooltip: t.libraries.resetFilters,
                    onPressed: _reset,
                    icon: const AppIcon(Symbols.filter_alt_off_rounded, size: 18),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _groupSlivers(LibraryBrowseGroup group, int density) => [
    SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(MonoPresentation.pageInset(context), 16, MonoPresentation.pageInset(context), 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BackendBadge(backend: group.library.backend, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(group.library.title, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 4),
            LibraryServerLabel(library: group.library, fallbackServerName: group.library.serverId, constrainText: true),
          ],
        ),
      ),
    ),
    MediaCardSliverLayout(
      viewMode: ViewMode.grid,
      density: density,
      itemCount: group.items.length,
      minimumItemWidth: PlatformDetector.isTV()
          ? null
          : 108 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
      padding: EdgeInsets.symmetric(horizontal: MonoPresentation.isTablet(context) ? 28 : 12),
      shape: group.library.kind.isMusic
          ? CardShape.square
          : group.library.kind == MediaKind.clip
          ? CardShape.wide
          : null,
      itemBuilder: (context, position) {
        final index = position.index;
        final key = _itemKey(group, index);
        return FocusableMediaCard(
          key: ValueKey(key),
          item: group.items[index],
          viewModeOverride: ViewMode.grid,
          showServerName: true,
          libraryName: group.library.title,
          focusNode: _node(key),
          onRefresh: (_) => refresh(),
          onBack: widget.onBack,
          onNavigateLeft: position.isFirstColumn ? () => _searchFocus.requestFocus() : null,
          onNavigateUp: position.isFirstRow
              ? () => _searchFocus.requestFocus()
              : () => _focusItem(group, index - position.columnCount),
          onNavigateDown: index + position.columnCount < group.items.length
              ? () => _focusItem(group, index + position.columnCount)
              : group.hasMore || group.error != null
              ? () => _node('${group.library.globalKey}/more').requestFocus()
              : null,
        );
      },
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: group.loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (group.error != null)
                    Text(t.libraries.groupedLoadFailed)
                  else if (group.items.isEmpty)
                    Text(t.libraries.noItemsMatchFilters),
                  if (group.error != null || group.hasMore)
                    FocusableButton(
                      focusNode: _node('${group.library.globalKey}/more'),
                      onPressed: () => unawaited(_controller.loadMore(group)),
                      onBack: widget.onBack,
                      onNavigateLeft: () => _searchFocus.requestFocus(),
                      child: TextButton(
                        onPressed: () => unawaited(_controller.loadMore(group)),
                        child: Text(group.error != null ? t.common.retry : t.libraries.loadMore),
                      ),
                    ),
                ],
              ),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tv = PlatformDetector.isTV();
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final controls = FocusScope(
          node: _filterFocus,
          child: tv
              ? ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final control in _controls(true))
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: control),
                    Text(t.libraries.groupedOrdering, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Text(t.libraries.groupedFacetUnavailable, style: Theme.of(context).textTheme.bodySmall),
                  ],
                )
              : _mobileControls(),
        );
        final results = Expanded(
          child: FocusScope(
            node: _contentFocus,
            child: SettingValueBuilder<int>(
              pref: SettingsService.libraryDensity,
              builder: (context, density, _) => CustomScrollView(
                key: const PageStorageKey('all_sources_grouped_results'),
                controller: _scroll,
                slivers: [
                  if (!tv)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MonoPresentation.isTablet(context) ? 32 : 12,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.libraries.groupedOrdering),
                            const SizedBox(height: 6),
                            Text(t.libraries.groupedFacetUnavailable, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  for (final group in _controller.groups) ..._groupSlivers(group, density),
                  const SliverToBoxAdapter(child: SizedBox(height: 48)),
                ],
              ),
            ),
          ),
        );
        return tv
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 220, child: controls),
                  results,
                ],
              )
            : Column(children: [controls, results]);
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _search.dispose();
    _year.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    _contentFocus.dispose();
    _filterFocus.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }
}
