import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../media/ids.dart';
import '../media/library_query.dart';
import '../media/media_filter.dart';
import '../media/media_item.dart';
import '../media/media_kind.dart';
import '../media/media_library.dart';
import '../media/media_server_client.dart';
import '../mixins/refreshable.dart';
import '../mixins/tab_visibility_aware.dart';
import '../navigation/main_screen_scope.dart';
import '../providers/catalog_sources_provider.dart';
import '../providers/libraries_provider.dart';
import '../providers/multi_server_provider.dart';
import '../providers/offline_mode_provider.dart';
import '../services/catalog/catalog_source.dart';
import '../services/catalog/plex_catalog_source.dart';
import '../services/settings_service.dart' show ViewMode;
import '../utils/app_logger.dart';
import '../utils/platform_detector.dart';
import '../widgets/desktop_app_bar.dart';
import '../widgets/focusable_media_card.dart';
import '../widgets/focusable_tab_chip.dart';
import '../widgets/loading_indicator_box.dart';
import '../widgets/media_card_sliver_layout.dart';
import 'libraries/state_messages.dart';

/// Which kinds the favorites grid shows.
enum FavoritesFilter { all, movie, show }

/// Per-library cap for a favorites query. Favorites are a short, hand-curated
/// list; one page per library keeps the aggregate to a single request each.
const int kFavoritesPerLibraryLimit = 200;

/// Watchlist pages read per Plex source (100 items each).
const int kFavoritesWatchlistPages = 3;
const int kFavoritesWatchlistPageSize = 100;

bool _isFavoritesKind(MediaKind kind) => kind == MediaKind.movie || kind == MediaKind.show;

/// Merge favorites across backends.
///
/// Jellyfin/Emby: `IsFavorite` filter per movie/show library on each online
/// server whose [ServerCapabilities.userFavorites] is set. Plex: the cloud
/// watchlist of the active profile. Duplicates collapse on [MediaItem.globalKey].
///
/// Neither backend exposes a "favorited at" timestamp, so Jellyfin entries are
/// ordered by date added (newest first) and watchlist entries keep the
/// watchlist's own order, placed first. A server that fails is skipped; the
/// call throws only when every source failed and nothing was collected.
Future<List<MediaItem>> loadFavorites({
  required MultiServerProvider servers,
  required List<MediaLibrary> libraries,
  required List<PlexCatalogSource> watchlistSources,
}) async {
  var attempted = 0;
  var failed = 0;
  Object? lastError;

  Future<List<MediaItem>> guarded(Future<List<MediaItem>> Function() run) async {
    attempted++;
    try {
      return await run();
    } catch (error, stackTrace) {
      failed++;
      lastError = error;
      appLogger.w('Favorites: source failed', error: error, stackTrace: stackTrace);
      return const [];
    }
  }

  final jobs = <Future<List<MediaItem>>>[];
  for (final serverId in servers.onlineServerIds) {
    final MediaServerClient? client = servers.getClientForServer(ServerId(serverId));
    if (client == null || !client.capabilities.userFavorites) continue;
    for (final library in libraries) {
      if (library.serverId != serverId || library.hidden) continue;
      if (library.kind != MediaKind.unknown && !_isFavoritesKind(library.kind)) continue;
      jobs.add(
        guarded(() async {
          final page = await client.fetchLibraryPagedContent(
            library.id,
            libraryKind: library.kind,
            query: const LibraryQuery(
              includeKinds: [MediaKind.movie, MediaKind.show],
              limit: kFavoritesPerLibraryLimit,
              sort: LibrarySort(field: 'addedAt'),
              filters: [
                LibraryFilter(field: MediaFilterField.favorite, values: ['1']),
              ],
            ),
          );
          return page.items.where((item) => _isFavoritesKind(item.kind)).toList();
        }),
      );
    }
  }

  final watchlistJobs = <Future<List<MediaItem>>>[
    for (final source in watchlistSources)
      guarded(() async {
        final items = <MediaItem>[];
        for (var page = 1; page <= kFavoritesWatchlistPages; page++) {
          final result = await source.fetchRow(CatalogRowId.watchlist, page: page, limit: kFavoritesWatchlistPageSize);
          items.addAll(result.items.map((item) => item.toMediaItem()));
          if (!result.hasMore) break;
        }
        return items;
      }),
  ];

  final serverItems = [for (final list in await Future.wait(jobs)) ...list]
    ..sort((a, b) => (b.addedAt ?? 0).compareTo(a.addedAt ?? 0));
  final watchlistItems = [for (final list in await Future.wait(watchlistJobs)) ...list];

  final seen = <String>{};
  final merged = <MediaItem>[
    for (final item in [...watchlistItems, ...serverItems])
      if (seen.add(item.globalKey)) item,
  ];
  if (merged.isEmpty && attempted > 0 && failed == attempted && lastError != null) {
    throw lastError!;
  }
  return merged;
}

/// Bottom-navigation "Favorites" tab: poster grid of favorited movies and
/// shows across every connected server.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen>
    with Refreshable, FullRefreshable, FocusableTab, TabVisibilityAware {
  List<MediaItem> _items = const [];
  FavoritesFilter _filter = FavoritesFilter.all;
  bool _loading = true;
  bool _hasError = false;
  bool _loadedOnce = false;
  int _generation = 0;

  final _chipNodes = {for (final f in FavoritesFilter.values) f: FocusNode(debugLabel: 'favorites_chip_${f.name}')};
  final _firstCardNode = FocusNode(debugLabel: 'favorites_first_card');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    for (final node in _chipNodes.values) {
      node.dispose();
    }
    _firstCardNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final offline = context.read<OfflineModeProvider>().isOffline;
    if (offline) {
      setState(() {
        _items = const [];
        _loading = false;
        _hasError = false;
      });
      return;
    }
    final servers = context.read<MultiServerProvider>();
    final libraries = context.read<LibrariesProvider>().libraries;
    final watchlistSources = context.read<CatalogSourcesProvider>().connectedSources.whereType<PlexCatalogSource>();
    if (!_loadedOnce) setState(() => _loading = true);
    try {
      final items = await loadFavorites(
        servers: servers,
        libraries: libraries,
        watchlistSources: watchlistSources.toList(),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = items;
        _hasError = false;
        _loading = false;
        _loadedOnce = true;
      });
    } catch (error, stackTrace) {
      appLogger.e('Favorites: load failed', error: error, stackTrace: stackTrace);
      if (!mounted || generation != _generation) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  void refresh() => unawaited(_load());

  @override
  void fullRefresh() => unawaited(_load());

  @override
  void onTabShown() {
    // Favorites change from detail pages; re-read when the tab returns.
    if (_loadedOnce) unawaited(_load());
  }

  @override
  void onTabHidden() {}

  @override
  void focusActiveTabIfReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chipNodes[_filter]?.requestFocus();
    });
  }

  List<MediaItem> get _visibleItems => switch (_filter) {
    FavoritesFilter.all => _items,
    FavoritesFilter.movie => [
      for (final item in _items)
        if (item.kind == MediaKind.movie) item,
    ],
    FavoritesFilter.show => [
      for (final item in _items)
        if (item.kind == MediaKind.show) item,
    ],
  };

  String _filterLabel(FavoritesFilter filter) => switch (filter) {
    FavoritesFilter.all => t.libraries.groupings.all,
    FavoritesFilter.movie => t.libraries.groupings.movies,
    FavoritesFilter.show => t.libraries.groupings.shows,
  };

  void _toSidebar() => MainScreenFocusScope.focusSidebarOf(context);

  Widget _buildChips() {
    const filters = FavoritesFilter.values;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(PlatformDetector.isTV() ? 34 : 17, 4, 17, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < filters.length; i++)
              FocusableTabChip(
                key: ValueKey('favorites_filter_${filters[i].name}'),
                label: _filterLabel(filters[i]),
                isSelected: _filter == filters[i],
                focusNode: _chipNodes[filters[i]],
                onSelect: () => setState(() => _filter = filters[i]),
                onNavigateLeft: i == 0 ? _toSidebar : () => _chipNodes[filters[i - 1]]?.requestFocus(),
                onNavigateRight: i == filters.length - 1 ? null : () => _chipNodes[filters[i + 1]]?.requestFocus(),
                onNavigateDown: _visibleItems.isEmpty ? null : _firstCardNode.requestFocus,
                onBack: _toSidebar,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return LoadingIndicatorBox.sliver;
    if (_hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorStateWidget(
          message: t.favorites.loadFailed,
          onRetry: () => unawaited(_load()),
          onActionNavigateLeft: _toSidebar,
        ),
      );
    }
    final items = _visibleItems;
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: StateMessageWidget(
          message: t.favorites.empty,
          subtitle: t.favorites.emptyHint,
          icon: Symbols.favorite_rounded,
        ),
      );
    }
    final isTv = PlatformDetector.isTV();
    return MediaCardSliverLayout(
      viewMode: ViewMode.grid,
      density: 1,
      itemCount: items.length,
      padding: EdgeInsets.symmetric(horizontal: isTv ? 34 : 17),
      minimumItemWidth: 107,
      columnCount: isTv ? 7 : null,
      itemBuilder: (context, position) {
        final item = items[position.index];
        return FocusableMediaCard(
          key: ValueKey('favorites/${item.globalKey}'),
          item: item,
          viewModeOverride: ViewMode.grid,
          focusNode: position.index == 0 ? _firstCardNode : null,
          onRefresh: (_) => refresh(),
          onNavigateLeft: position.isFirstColumn ? _toSidebar : null,
          onNavigateUp: position.isFirstRow ? () => _chipNodes[_filter]?.requestFocus() : null,
          onBack: () => _chipNodes[_filter]?.requestFocus(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        primary: false,
        slivers: [
          DesktopSliverAppBar(
            title: Text(t.navigation.favorites),
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            scrolledUnderElevation: 0,
          ),
          _buildChips(),
          _buildBody(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}
