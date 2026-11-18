import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_dialog.dart';
import '../../theme/mono_presentation.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../focus/focusable_button.dart';
import '../../focus/focusable_text_field.dart';
import '../../i18n/strings.g.dart';
import '../../media/media_item.dart';
import '../../media/media_kind.dart';
import '../../media/library_query.dart';
import '../../media/media_person.dart';
import '../../utils/media_server_http_client.dart';
import '../../theme/velo_brand.dart';
import '../../widgets/person_search_row.dart';
import 'library_wall.dart';
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

typedef GroupedPeopleFetcher =
    Future<List<MediaPerson>> Function(
      MediaLibrary library,
      String query,
      Set<String> excludedLibraryIds,
      AbortController abort,
    );

const allLibrarySourcesKey = '__plezy_all_library_sources__';

class GroupedLibraryBrowse extends StatefulWidget {
  const GroupedLibraryBrowse({
    super.key,
    required this.libraries,
    this.onBack,
    this.fetchPage,
    this.fetchCollectionsPage,
    this.fetchPlaylistsPage,
    this.fetchPeople,
    this.searchController,
    this.searchFocusNode,
    this.searchInHeader = false,
  });

  final List<MediaLibrary> libraries;
  final VoidCallback? onBack;
  final GroupedLibraryFetcher? fetchPage;
  final GroupedLibraryFetcher? fetchCollectionsPage;
  final GroupedPlaylistFetcher? fetchPlaylistsPage;
  final GroupedPeopleFetcher? fetchPeople;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final bool searchInHeader;

  @override
  State<GroupedLibraryBrowse> createState() => GroupedLibraryBrowseState();
}

class GroupedLibraryBrowseState extends State<GroupedLibraryBrowse> {
  late final GroupedLibraryController _controller;
  late final _search = widget.searchController ?? TextEditingController();
  final _year = TextEditingController();
  late final _searchFocus = widget.searchFocusNode ?? FocusNode(debugLabel: 'all_sources_search');
  final _scroll = ScrollController();
  final _contentFocus = FocusScopeNode(debugLabel: 'all_sources_content');
  final _filterFocus = FocusScopeNode(debugLabel: 'all_sources_filters');
  final Map<String, FocusNode> _nodes = {};
  final Map<String, FocusScopeNode> _wallRows = {};
  final Map<String, int> _epochs = {};
  Timer? _debounce;
  MediaKind? _kind;
  bool? _watched;
  GroupedLibrarySort _sort = GroupedLibrarySort.title;
  bool _touchWall = false;
  LibraryWallType _wallType = LibraryWallType.all;
  LibrarySortDirection _direction = LibrarySortDirection.descending;
  String? _genre;
  String? _country;
  String? _expandedWallFacet;
  List<MediaPerson> _people = [];
  final List<AbortController> _peopleAborts = [];
  int _peopleGeneration = 0;
  bool _paginationScheduled = false;
  int? _pendingWallFocusIndex;
  FocusNode? _wallFocusOrigin;
  int _wallFocusGeneration = 0;

  GroupedLibrarySelection get _selection => GroupedLibrarySelection(
    search: _search.text,
    year: int.tryParse(_year.text),
    kind: _kind,
    watched: _watched,
    sort: _sort,
    direction: _touchWall ? _direction : null,
    wallType: _touchWall ? _wallType : null,
    genre: _touchWall ? _genre : null,
    country: _touchWall ? _country : null,
  );

  void focusSearchInput() => _searchFocus.requestFocus();

  bool _pendingResultsFocus = false;

  void updateSearchQuery(String query) {
    _pendingResultsFocus = false;
    if (_search.text != query) _search.text = query;
    _queryChanged(debounce: true);
  }

  void _focusResultsWhenReady() {
    if (!_pendingResultsFocus || _controller.groups.any((group) => group.loading)) return;
    _pendingResultsFocus = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && TickerMode.valuesOf(context).enabled) focusContent();
    });
  }

  void submitSearchQuery(String query) {
    _debounce?.cancel();
    _search.text = query;
    refresh();
    _searchFocus.unfocus();
    _pendingResultsFocus = true;
    _focusResultsWhenReady();
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _controller = GroupedLibraryController(
      fetchCollectionsPage:
          widget.fetchCollectionsPage ??
          (library, query, abort) => context
              .getMediaClientForLibrary(library)
              .fetchCollectionsPage(library.id, start: query.offset, size: query.limit, abort: abort),
      fetchPlaylistsPage:
          widget.fetchPlaylistsPage ??
          (library, query, abort, playlistType) => context
              .getMediaClientForLibrary(library)
              .fetchPlaylistsPage(playlistType: playlistType, start: query.offset, size: query.limit, abort: abort),
      fetchPage:
          widget.fetchPage ??
          (library, query, abort) async {
            final provider = Provider.of<LibrariesProvider?>(context, listen: false);
            final epoch = provider?.libraryContentEpoch(library.globalKey);
            final page = await context
                .getMediaClientForLibrary(library)
                .fetchLibraryPagedContent(
                  library.id,
                  query: query,
                  libraryKind: library.kind,
                  includeFacetMetadata: _touchWall,
                  abort: abort,
                );
            if (!abort.isAborted && epoch != null && query.offset == 0) _epochs[library.globalKey] = epoch;
            return page;
          },
    );
    _controller.addListener(_onWallContentChanged);
    _controller.addListener(_focusResultsWhenReady);
    _controller.addListener(_resumeWallFocusWhenReady);
    _controller.reset(widget.libraries, _selection, load: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final touch = PlatformDetector.isMobile(context) || PlatformDetector.isTV();
    if (_controller.groups.every((group) => group.offset == 0 && !group.loading) || touch != _touchWall) {
      if (touch != _touchWall) _sort = touch ? GroupedLibrarySort.updated : GroupedLibrarySort.title;
      _touchWall = touch;
      _queryChanged();
    }
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
    final candidates = _touchWall
        ? _controller.entries.map((entry) => _nodes['wall/${entry.library.backend.name}/${entry.globalKey}']).nonNulls
        : _nodes.values;
    final nodes = candidates.where((node) => node.parent != null && node.context != null && node.canRequestFocus);
    if (nodes.isNotEmpty) {
      nodes.first.requestFocus();
    } else {
      _searchFocus.requestFocus();
    }
  }

  void _queryChanged({bool debounce = false}) {
    _cancelWallFocus();
    _debounce?.cancel();
    // Invalidate now, not after the typing delay: an old page must not commit.
    _controller.reset(widget.libraries, _selection, load: !debounce);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _cancelPeople();
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 350), () {
        _controller.loadAll();
        _loadPeople();
      });
    } else {
      _loadPeople();
    }
  }

  void _reset() {
    _search.clear();
    _year.clear();
    _kind = null;
    _watched = null;
    _sort = _touchWall ? GroupedLibrarySort.updated : GroupedLibrarySort.title;
    _direction = LibrarySortDirection.descending;
    _wallType = LibraryWallType.all;
    _genre = null;
    _country = null;
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

  void _cancelWallFocus() {
    _pendingWallFocusIndex = null;
    _wallFocusOrigin = null;
    _wallFocusGeneration++;
  }

  void _resumeWallFocusWhenReady() {
    final index = _pendingWallFocusIndex;
    if (index == null || _controller.groups.any((group) => group.loading)) return;
    if (!identical(FocusManager.instance.primaryFocus, _wallFocusOrigin)) {
      _cancelWallFocus();
      return;
    }
    final generation = _wallFocusGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _wallFocusGeneration) return;
      if (!identical(FocusManager.instance.primaryFocus, _wallFocusOrigin)) {
        _cancelWallFocus();
        return;
      }
      _focusWallItem(index, generation: generation);
    });
  }

  void _focusWallItem(int index, {int attempt = 0, int? generation}) {
    if (!mounted || index < 0) return;
    if (generation == null) {
      generation = ++_wallFocusGeneration;
      _pendingWallFocusIndex = index;
      _wallFocusOrigin = FocusManager.instance.primaryFocus;
    }
    if (generation != _wallFocusGeneration || _pendingWallFocusIndex != index) return;
    final entries = _controller.entries;
    String keyFor(LibraryWallEntry entry) => 'wall/${entry.library.backend.name}/${entry.globalKey}';
    if (index >= entries.length) {
      // Existing pagination can take arbitrarily many frames. Its completion
      // listener resumes this request without spending the render retry budget.
      if (_controller.groups.any((group) => group.loading)) return;
      if (!_controller.groups.any((group) => group.error == null && group.hasMore)) {
        _cancelWallFocus();
        return;
      }
      unawaited(_loadNextWallPages());
      return;
    }
    final node = _node(keyFor(entries[index]));
    if (node.context != null) {
      _cancelWallFocus();
      node.requestFocus();
      return;
    }
    if (!_scroll.hasClients || attempt >= 12) {
      _cancelWallFocus();
      return;
    }
    final focusedIndex = entries.indexWhere((entry) => _nodes[keyFor(entry)]?.hasFocus ?? false);
    final forward = focusedIndex < 0 || index > focusedIndex;
    _scroll.jumpTo((_scroll.offset + (forward ? 240 : -240)).clamp(0.0, _scroll.position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusWallItem(index, attempt: attempt + 1, generation: generation),
    );
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
        GroupedLibrarySort.updated => t.libraries.wallSort.updated,
        GroupedLibrarySort.released => t.libraries.wallSort.released,
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
    builder: (dialogContext) => AppDialog(
      key: const ValueKey('grouped-library-filters'),
      insetPadding: const EdgeInsets.all(16),
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
                  AppDialogTitle(title: Text(t.libraries.filters, style: Theme.of(context).textTheme.titleMedium)),
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

  Widget _legacyTouchControls() {
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

  void _cancelPeople() {
    _peopleGeneration++;
    for (final abort in _peopleAborts) {
      abort.abort();
    }
    _peopleAborts.clear();
    _people = [];
  }

  void _loadPeople() {
    if (!_touchWall ||
        _search.text.trim().isEmpty ||
        _wallType == LibraryWallType.collections ||
        _wallType == LibraryWallType.playlists) {
      return;
    }
    final generation = _peopleGeneration;
    final query = _search.text.trim();
    final servers = <String>{};
    final allLibraries = Provider.of<LibrariesProvider?>(context, listen: false)?.libraries ?? widget.libraries;
    for (final library in widget.libraries) {
      final server = library.serverId ?? library.globalKey;
      if (!servers.add(server)) continue;
      final abort = AbortController();
      _peopleAborts.add(abort);
      final visible = widget.libraries
          .where((entry) => entry.serverId == library.serverId)
          .map((entry) => entry.id)
          .toSet();
      final excluded = allLibraries
          .where((entry) => entry.serverId == library.serverId && !visible.contains(entry.id))
          .map((entry) => entry.id)
          .toSet();
      unawaited(() async {
        try {
          final results =
              await (widget.fetchPeople?.call(library, query, excluded, abort) ??
                  context
                      .getMediaClientForLibrary(library)
                      .searchPeople(query, excludedLibraryIds: excluded, abort: abort));
          if (!mounted || abort.isAborted || generation != _peopleGeneration) return;
          setState(() {
            final unique = {for (final person in _people) person.globalKey: person};
            for (final person in results) {
              unique[person.globalKey] = person;
            }
            _people = unique.values.toList();
          });
        } catch (_) {
          // A missing/offline people endpoint must not hide the media wall.
        }
      }());
    }
  }

  void _onScroll() {
    if (_touchWall && _scroll.hasClients && _scroll.position.extentAfter < 400) unawaited(_loadNextWallPages());
  }

  Future<void> _loadNextWallPages() async {
    await Future.wait([
      for (final group in _controller.groups)
        if (group.error == null && !group.loading && group.hasMore) _controller.loadMore(group),
    ]);
  }

  void _onWallContentChanged() {
    if (!_touchWall || _paginationScheduled) return;
    _paginationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paginationScheduled = false;
      if (!mounted || !_touchWall || _controller.groups.any((group) => group.loading)) return;
      // Genre categories can have no match in the first page. Keep reading
      // each independent source until a result or the real end is reached.
      if (_controller.entries.isEmpty || (_scroll.hasClients && _scroll.position.extentAfter < 240)) {
        unawaited(_loadNextWallPages());
      }
    });
  }

  String _wallTypeLabel(LibraryWallType type) => switch (type) {
    LibraryWallType.all => t.libraries.wallTypes.all,
    LibraryWallType.series => t.libraries.wallTypes.series,
    LibraryWallType.movies => t.libraries.wallTypes.movies,
    LibraryWallType.anime => t.libraries.wallTypes.anime,
    LibraryWallType.variety => t.libraries.wallTypes.variety,
    LibraryWallType.concert => t.libraries.wallTypes.concert,
    LibraryWallType.documentary => t.libraries.wallTypes.documentary,
    LibraryWallType.music => t.libraries.wallTypes.music,
    LibraryWallType.collections => t.libraries.tabs.collections,
    LibraryWallType.playlists => t.libraries.tabs.playlists,
  };

  Widget _wallChip(String label, bool selected, VoidCallback onTap, {Key? key}) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Semantics(
        selected: selected,
        child: TextButton(
          key: key,
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: Size(0, 32 * MediaQuery.textScalerOf(context).scale(1)),
            fixedSize: Size.fromHeight(32 * MediaQuery.textScalerOf(context).scale(1)),
            padding: const EdgeInsets.symmetric(horizontal: 11),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: selected ? VeloBrand.selection(brightness) : Colors.transparent,
            foregroundColor: selected ? VeloBrand.foreground(brightness) : VeloPalette.caption(brightness),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontVariations: selected ? const [FontVariation('wght', 650)] : null,
            ),
          ),
          child: Text(label, maxLines: 1),
        ),
      ),
    );
  }

  Widget _wallRow(String key, List<Widget> children, {String? label}) {
    final inset = PlatformDetector.isTV() ? 34.0 : 17.0;
    final expanded = label != null && _expandedWallFacet == key;
    void toggle() => setState(() => _expandedWallFacet = expanded ? null : key);
    final options = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: label == null ? EdgeInsets.symmetric(horizontal: inset) : EdgeInsets.zero,
      child: Row(children: children),
    );
    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.only(bottom: 7),
      child: FocusScope(
        node: _wallRows.putIfAbsent(
          key,
          () => FocusScopeNode(debugLabel: key, directionalTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope),
        ),
        child: label == null
            ? options
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
                        ),
                        Expanded(child: expanded ? const SizedBox.shrink() : options),
                        Semantics(
                          expanded: expanded,
                          child: IconButton(
                            key: ValueKey('$key-expand'),
                            tooltip: '$label · ${expanded ? t.accessibility.collapseText : t.accessibility.expandText}',
                            onPressed: toggle,
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
                            padding: EdgeInsets.zero,
                            icon: AppIcon(
                              expanded ? Symbols.expand_less_rounded : Symbols.expand_more_rounded,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (expanded) Wrap(spacing: 0, runSpacing: 7, children: children),
                  ],
                ),
              ),
      ),
    );
  }

  void _localFacetChanged() {
    _cancelWallFocus();
    _expandedWallFacet = null;
    _controller.updateLocalSelection(_selection);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _wallSearch() => Padding(
    key: const ValueKey('wall-search-input'),
    padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
    child: SizedBox(
      height: 40,
      child: FocusableTextField(
        controller: _search,
        focusNode: _searchFocus,
        tvTextInputAutoOpenBehavior: TvTextInputAutoOpenBehavior.never,
        decoration: InputDecoration(
          hintText: t.libraries.searchHint,
          prefixIcon: const AppIcon(Symbols.search_rounded, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: t.common.clear,
                  onPressed: () {
                    _search.clear();
                    _queryChanged();
                  },
                  icon: const AppIcon(Symbols.close_rounded, size: 18),
                ),
        ),
        onChanged: (_) => _queryChanged(debounce: true),
        onSubmitted: (_) => _queryChanged(),
        onBack: widget.onBack,
      ),
    ),
  );

  Widget _wallControls({bool includeSearch = true}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (includeSearch && !widget.searchInHeader) _wallSearch(),
      _wallRow('wall-types', [
        for (final type in LibraryWallType.values)
          _wallChip(_wallTypeLabel(type), _wallType == type, () {
            _wallType = type;
            _kind = null;
            _genre = null;
            _country = null;
            _year.clear();
            _queryChanged();
          }, key: ValueKey('wall-type-${type.name}')),
      ]),
      _wallRow('wall-sort', [
        for (final sort in [GroupedLibrarySort.updated, GroupedLibrarySort.released, GroupedLibrarySort.rating])
          _wallChip(
            switch (sort) {
              GroupedLibrarySort.updated => t.libraries.wallSort.updated,
              GroupedLibrarySort.released => t.libraries.wallSort.released,
              _ => t.libraries.wallSort.rating,
            },
            _sort == sort,
            () {
              _direction = _sort == sort && _direction == LibrarySortDirection.descending
                  ? LibrarySortDirection.ascending
                  : LibrarySortDirection.descending;
              _sort = sort;
              _queryChanged();
            },
            key: ValueKey('wall-sort-${sort.name}'),
          ),
      ]),
      _wallRow('wall-genres', [
        _wallChip(t.libraries.all, _genre == null, () {
          _genre = null;
          _localFacetChanged();
        }),
        for (final genre in {..._controller.genres, ?_genre})
          _wallChip(genre, _genre == genre, () {
            _genre = genre;
            _localFacetChanged();
          }),
      ], label: t.libraries.filterCategories.genre),
      _wallRow('wall-countries', [
        _wallChip(t.libraries.all, _country == null, () {
          _country = null;
          _localFacetChanged();
        }),
        for (final country in {..._controller.countries, ?_country})
          _wallChip(country, _country == country, () {
            _country = country;
            _localFacetChanged();
          }),
      ], label: t.explore.detail.country),
      _wallRow('wall-years', [
        _wallChip(t.libraries.all, _year.text.isEmpty, () {
          _year.clear();
          _localFacetChanged();
        }),
        for (final year in {..._controller.years, if (int.tryParse(_year.text) != null) int.parse(_year.text)})
          _wallChip('$year', _year.text == '$year', () {
            _year.text = '$year';
            _localFacetChanged();
          }),
      ], label: t.libraries.filterCategories.year),
    ],
  );

  Widget _buildWall() => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final entries = _controller.entries;
      final loading = _controller.groups.any((group) => group.loading);
      final failed = _controller.groups.any((group) => group.error != null);
      final hasMore = _controller.groups.any((group) => group.hasMore);
      final wall = CustomScrollView(
        key: const PageStorageKey('all_sources_merged_wall'),
        controller: _scroll,
        slivers: [
          if (PlatformDetector.isTV())
            SliverToBoxAdapter(child: _wallControls())
          else ...[
            SliverFloatingHeader(
              key: const ValueKey('wall-filter-header'),
              animationStyle: MediaQuery.disableAnimationsOf(context) ? AnimationStyle.noAnimation : null,
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: _wallControls(includeSearch: false),
              ),
            ),
          ],
          if (_people.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(17, 8, 0, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.libraries.wallActors, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 116 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _people.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) =>
                            SizedBox(width: 240, child: PersonSearchRow(person: _people[index], showServerName: true)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          MediaCardSliverLayout(
            viewMode: ViewMode.grid,
            density: 1,
            itemCount: entries.length,
            padding: EdgeInsets.symmetric(horizontal: PlatformDetector.isTV() ? 34 : 17),
            minimumItemWidth: 107,
            columnCount: PlatformDetector.isTV() ? 7 : null,
            itemBuilder: (context, position) {
              final entry = entries[position.index];
              return FocusableMediaCard(
                key: ValueKey('wall/${entry.library.backend.name}/${entry.globalKey}'),
                item: entry.item,
                viewModeOverride: ViewMode.grid,
                showServerName: true,
                libraryName: entry.library.title,
                focusNode: _node('wall/${entry.library.backend.name}/${entry.globalKey}'),
                onRefresh: (_) => refresh(),
                onBack: widget.onBack,
                onNavigateLeft: position.isFirstColumn ? _searchFocus.requestFocus : null,
                onNavigateDown: PlatformDetector.isTV()
                    ? () => _focusWallItem(position.index + position.columnCount)
                    : null,
                onNavigateUp: position.isFirstRow
                    ? () {
                        _wallRows['wall-years']?.descendants
                            .where((node) => node.canRequestFocus && node.context != null)
                            .firstOrNull
                            ?.requestFocus();
                      }
                    : PlatformDetector.isTV()
                    ? () => _focusWallItem(position.index - position.columnCount)
                    : null,
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                children: [
                  if (loading) const CircularProgressIndicator(),
                  if (failed) Text(t.libraries.groupedLoadFailed),
                  if (!loading && entries.isEmpty && !hasMore && !failed) Text(t.libraries.noItemsMatchFilters),
                  if (failed || hasMore)
                    TextButton(
                      onPressed: _controller.loadAll,
                      child: Text(failed ? t.common.retry : t.libraries.loadMore),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      );
      if (PlatformDetector.isTV() || widget.searchInHeader) return wall;
      // Keep the search outside the floating viewport so the returning filter
      // rows cannot paint underneath it or cover its input hit target.
      return Column(
        children: [
          Material(color: Theme.of(context).scaffoldBackgroundColor, child: _wallSearch()),
          Expanded(child: wall),
        ],
      );
    },
  );

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
    if (_touchWall) return _buildWall();
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
              : _legacyTouchControls(),
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
    _cancelPeople();
    _controller.removeListener(_onWallContentChanged);
    _controller.removeListener(_focusResultsWhenReady);
    _controller.removeListener(_resumeWallFocusWhenReady);
    _cancelWallFocus();
    _controller.dispose();
    if (widget.searchController == null) _search.dispose();
    _year.dispose();
    if (widget.searchFocusNode == null) _searchFocus.dispose();
    _scroll.dispose();
    _contentFocus.dispose();
    _filterFocus.dispose();
    for (final row in _wallRows.values) {
      row.dispose();
    }
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }
}
