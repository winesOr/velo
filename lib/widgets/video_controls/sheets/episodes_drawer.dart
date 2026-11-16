import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../i18n/strings.g.dart';
import '../../../media/ids.dart';
import '../../../media/media_item.dart';
import '../../../media/media_item_types.dart';
import '../../../media/media_server_client.dart';
import '../../../providers/playback_state_provider.dart';
import '../../../providers/multi_server_provider.dart';
import '../../../watch_together/providers/watch_together_provider.dart';
import '../../../utils/scroll_utils.dart';
import '../../../services/settings_service.dart';
import '../../../utils/provider_extensions.dart';
import '../../app_icon.dart';
import '../../focusable_list_tile.dart';
import '../../optimized_media_image.dart';
import '../../overlay_sheet.dart';
import '../../settings_builder.dart';
import '../widgets/media_selector_thumbnail.dart';
import 'base_video_control_sheet.dart';
import 'player_initial_focus.dart';
import 'player_popovers.dart' show episodePopoverLabel;

/// Shared player drawer. Queue items retain their original queue identity.
class EpisodesDrawer extends StatefulWidget {
  const EpisodesDrawer({
    super.key,
    required this.current,
    required this.offline,
    required this.canNavigate,
    required this.onSelect,
    required this.isAuthorized,
    required this.onRepeat,
    required this.onShuffle,
  });
  final MediaItem current;
  final bool offline;
  final bool canNavigate;
  final Future<bool> Function(MediaItem) onSelect;
  final bool Function() isAuthorized;
  final Future<bool> Function(VideoQueueRepeatMode) onRepeat;
  final Future<bool> Function(bool, bool Function()) onShuffle;

  @override
  State<EpisodesDrawer> createState() => _EpisodesDrawerState();
}

class _EpisodesDrawerState extends State<EpisodesDrawer> {
  static const _pageSize = 50;
  final _scroll = ScrollController();
  final _currentKey = GlobalKey();
  final _initialFocus = PlayerInitialFocus();
  final _firstKey = GlobalKey();
  PlaybackStateProvider? _scopeQueue;
  int? _scopeRevision;
  MediaServerClient? _scopeClient;
  Object? _scopeAuth;
  bool _scopeReloadScheduled = false;
  bool _scrollToCurrent = true;
  int _seasonOffset = 0;
  List<MediaItem> _seasons = [];
  List<MediaItem> _items = [];
  MediaItem? _season;
  MediaItem? _nextSeasonFirst;
  MediaItem? _nextSeason;
  bool _loading = false;
  bool _failed = false;
  bool _hasMore = false;
  bool _selecting = false;
  int _generation = 0;

  bool get _episodeMode {
    final queue = context.read<PlaybackStateProvider>();
    final key = queue.shuffleContextKey;
    return widget.current.isEpisode &&
        (!queue.isQueueActive ||
            key == null ||
            key == widget.current.grandparentId ||
            key == widget.current.seriesGlobalKey);
  }

  bool _scopeCurrent() {
    if (!mounted) return false;
    final queue = context.read<PlaybackStateProvider>();
    final client = widget.offline ? null : context.tryGetMediaClientForServer(serverIdOrNull(widget.current.serverId));
    return identical(queue, _scopeQueue) &&
        queue.queueRevision == _scopeRevision &&
        identical(client, _scopeClient) &&
        client?.authenticationSessionId == _scopeAuth;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitial();
    });
  }

  @override
  void didUpdateWidget(covariant EpisodesDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current.globalKey != widget.current.globalKey || oldWidget.offline != widget.offline) _loadInitial();
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    _initialFocus.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final generation = ++_generation;
    _scopeQueue = context.read<PlaybackStateProvider>();
    _scopeRevision = _scopeQueue!.queueRevision;
    _scopeClient = widget.offline ? null : context.tryGetMediaClientForServer(serverIdOrNull(widget.current.serverId));
    _scopeAuth = _scopeClient?.authenticationSessionId;
    setState(() {
      _loading = true;
      _failed = false;
      _hasMore = false;
      _items = [];
      _seasons = [];
      _season = null;
      _nextSeasonFirst = null;
      _nextSeason = null;
      _seasonOffset = 0;
      _scrollToCurrent = true;
    });
    if (!_episodeMode) {
      await _loadQueue(generation: generation);
      return;
    }
    final current = widget.current;
    final client = widget.offline ? null : context.tryGetMediaClientForServer(serverIdOrNull(current.serverId));
    if (client == null || current.grandparentId == null || current.parentId == null) {
      final queue = context.read<PlaybackStateProvider>();
      final candidates = queue.loadedItems
          .where((item) => item.parentId == current.parentId && item.isEpisode)
          .toList();
      if (!candidates.any((item) => item.globalKey == current.globalKey)) candidates.insert(0, current);
      if (mounted && generation == _generation && _scopeCurrent()) {
        setState(() {
          _items = candidates;
          _loading = false;
        });
      }
      return;
    }
    try {
      final auth = client.authenticationSessionId;
      final seasons = (await client.fetchChildren(current.grandparentId!)).where((item) => item.isSeason).toList()
        ..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
      if (!mounted || generation != _generation || !_scopeCurrent()) return;
      if (client.authenticationSessionId != auth) throw StateError('Session changed');
      final season = seasons.where((item) => item.id == current.parentId).firstOrNull;
      setState(() {
        _seasons = seasons;
        _season = season;
      });
      if (season == null) {
        setState(() {
          _items = [current];
          _loading = false;
        });
        return;
      }
      await _loadSeasonPage(client, season, generation: generation);
    } catch (_) {
      if (mounted && generation == _generation && _scopeCurrent()) {
        setState(() {
          _items = [current];
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _chooseSeason(MediaItem season) async {
    if (!_scopeCurrent()) {
      await _loadInitial();
      return;
    }
    final generation = ++_generation;
    setState(() {
      _season = season;
      _items = [];
      _nextSeasonFirst = null;
      _nextSeason = null;
      _seasonOffset = 0;
      _scrollToCurrent = season.id == widget.current.parentId;
      _hasMore = false;
      _failed = false;
      _loading = true;
    });
    final client = widget.offline ? null : context.tryGetMediaClientForServer(serverIdOrNull(widget.current.serverId));
    if (client != null) {
      await _loadSeasonPage(client, season, generation: generation);
    } else if (mounted && generation == _generation) {
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadSeasonPage(MediaServerClient client, MediaItem season, {required int generation}) async {
    try {
      final start = _seasonOffset;
      final auth = client.authenticationSessionId;
      final paging = client is SeasonEpisodePagingClient ? client as SeasonEpisodePagingClient : null;
      final page = paging != null && widget.current.grandparentId != null
          ? await paging.fetchSeasonEpisodesPage(
              widget.current.grandparentId!,
              season.id,
              start: start,
              size: _pageSize,
            )
          : await client.fetchChildrenPage(season.id, start: start, size: _pageSize);
      if (!mounted || generation != _generation || !_scopeCurrent()) return;
      if (client.authenticationSessionId != auth) throw StateError('Session changed');
      final more = page.items.isNotEmpty && start + page.items.length < page.totalCount;
      final normalized = page.items
          .where((item) => item.isEpisode)
          .map(
            (item) => item.copyWith(
              serverId: item.serverId ?? widget.current.serverId,
              parentId: item.parentId ?? season.id,
              parentIndex: item.parentIndex ?? season.index,
              grandparentId: item.grandparentId ?? widget.current.grandparentId,
            ),
          )
          .toList();
      final needsCurrent =
          more &&
          _scrollToCurrent &&
          season.id == widget.current.parentId &&
          ![..._items, ...normalized].any((item) => item.globalKey == widget.current.globalKey);
      setState(() {
        _seasonOffset = start + page.items.length;
        _items = [..._items, ...normalized];
        _hasMore = more;
        _failed = false;
        _loading = needsCurrent;
      });
      if (needsCurrent) {
        await _loadSeasonPage(client, season, generation: generation);
      } else if (!more) {
        await _loadNextSeason(client, season, generation);
      }
    } catch (_) {
      if (mounted && generation == _generation && _scopeCurrent()) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadNextSeason(MediaServerClient client, MediaItem season, int generation) async {
    final index = _seasons.indexWhere((item) => item.id == season.id);
    if (index < 0 || index + 1 >= _seasons.length) return;
    final next = _seasons[index + 1];
    try {
      final auth = client.authenticationSessionId;
      final paging = client is SeasonEpisodePagingClient ? client as SeasonEpisodePagingClient : null;
      final page = paging != null && widget.current.grandparentId != null
          ? await paging.fetchSeasonEpisodesPage(widget.current.grandparentId!, next.id, start: 0, size: 1)
          : await client.fetchChildrenPage(next.id, start: 0, size: 1);
      if (mounted && generation == _generation && _scopeCurrent() && client.authenticationSessionId == auth) {
        final item = page.items.where((item) => item.isEpisode).firstOrNull;
        setState(() {
          _nextSeason = next;
          _nextSeasonFirst = item?.copyWith(
            serverId: item.serverId ?? widget.current.serverId,
            parentId: item.parentId ?? next.id,
            parentIndex: item.parentIndex ?? next.index,
            grandparentId: item.grandparentId ?? widget.current.grandparentId,
          );
        });
      }
    } catch (_) {
      // The next season is optional; selecting its tab provides a retry path.
    }
  }

  Future<void> _loadQueue({required int generation}) async {
    final queue = context.read<PlaybackStateProvider>();
    if (!queue.isQueueActive || widget.offline) {
      final loaded = queue.loadedItems;
      final currentIndex = loaded.indexWhere((item) => queue.playQueueItemIdFor(item) == queue.currentPlayQueueItemID);
      final available = currentIndex < 0 ? <MediaItem>[widget.current] : loaded.sublist(currentIndex);
      if (mounted && generation == _generation && _scopeCurrent()) {
        setState(() {
          _items = available;
          _loading = false;
        });
      }
      return;
    }
    final after = _items.isEmpty ? null : queue.playQueueItemIdFor(_items.last);
    final page = await queue.loadQueuePage(
      afterQueueItemId: after,
      limit: _pageSize,
      isCurrent: () => mounted && generation == _generation && _scopeCurrent(),
    );
    if (!mounted || generation != _generation || !_scopeCurrent()) return;
    setState(() {
      _items = [..._items, ...page.items];
      _hasMore = page.hasMore;
      _failed = page.status == QueueNavigationStatus.failed;
      _loading = false;
    });
  }

  Future<void> _more() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final generation = _generation;
    if (!_episodeMode) return _loadQueue(generation: generation);
    final season = _season;
    final client = widget.offline ? null : context.tryGetMediaClientForServer(serverIdOrNull(widget.current.serverId));
    if (season != null && client != null) return _loadSeasonPage(client, season, generation: generation);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _select(MediaItem item) async {
    if (_selecting || !widget.canNavigate || !widget.isAuthorized() || !_scopeCurrent()) return;
    setState(() => _selecting = true);
    try {
      // Season pages are separate copies; reuse a unique queue entry so the
      // player retains its cursor and queue identity after the reload.
      final queue = context.read<PlaybackStateProvider>();
      final matches = _episodeMode && queue.isQueueActive
          ? queue.loadedItems.where((entry) => entry.globalKey == item.globalKey).toList()
          : <MediaItem>[];
      final target = matches.length == 1 ? matches.single : item;
      final success = await widget.onSelect(target);
      if (mounted && success) OverlaySheetController.of(context).close();
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<MultiServerProvider?>();
    context.watch<WatchTogetherProvider?>();
    return _initialFocus.wrap(
      Consumer<PlaybackStateProvider>(
        builder: (context, queue, _) {
          if (_scopeQueue != null && !_scopeCurrent()) {
            if (!_scopeReloadScheduled) {
              _scopeReloadScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scopeReloadScheduled = false;
                if (mounted) _loadInitial();
              });
            }
            return const Center(child: CircularProgressIndicator());
          }
          final episodes = _episodeMode;
          return BaseVideoControlSheet(
            title: episodes ? t.videoControls.episodesButton : t.videoControls.playlistDrawer,
            icon: Symbols.format_list_bulleted_rounded,
            child: Column(
              children: [
                if (episodes && _seasons.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final season in _seasons)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(
                                season.title ??
                                    (season.index == null
                                        ? t.common.unknown
                                        : t.videoControls.seasonNumber(n: season.index!)),
                              ),
                              selected: _season?.id == season.id,
                              onSelected: (_) => _chooseSeason(season),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (!episodes)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: !widget.canNavigate || !widget.isAuthorized() || queue.queueModeChangePending
                              ? null
                              : () async {
                                  final next = switch (queue.repeatMode) {
                                    VideoQueueRepeatMode.off => VideoQueueRepeatMode.all,
                                    VideoQueueRepeatMode.all => VideoQueueRepeatMode.one,
                                    VideoQueueRepeatMode.one => VideoQueueRepeatMode.off,
                                  };
                                  await widget.onRepeat(next);
                                },
                          icon: Icon(
                            queue.repeatMode == VideoQueueRepeatMode.one
                                ? Symbols.repeat_one_rounded
                                : Symbols.repeat_rounded,
                          ),
                          label: Text(switch (queue.repeatMode) {
                            VideoQueueRepeatMode.off => t.videoControls.repeatOff,
                            VideoQueueRepeatMode.all => t.videoControls.repeatAll,
                            VideoQueueRepeatMode.one => t.videoControls.repeatOne,
                          }),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: !widget.canNavigate || !widget.isAuthorized() || queue.queueModeChangePending
                              ? null
                              : () async {
                                  final generation = ++_generation;
                                  final ok = await widget.onShuffle(
                                    !queue.isShuffleActive,
                                    () => mounted && generation == _generation && widget.isAuthorized(),
                                  );
                                  if (!mounted || generation != _generation || !_scopeCurrent()) return;
                                  if (ok) {
                                    await _loadInitial();
                                  } else {
                                    setState(() => _failed = true);
                                  }
                                },
                          icon: Icon(
                            Symbols.shuffle_rounded,
                            color: queue.isShuffleActive ? Theme.of(context).colorScheme.primary : null,
                          ),
                          label: Text(t.common.shuffle),
                        ),
                      ),
                    ],
                  ),
                Expanded(
                  child: SettingValueBuilder<bool>(
                    pref: SettingsService.hideSpoilers,
                    builder: (context, hideSpoilers, _) {
                      final currentId = queue.currentPlayQueueItemID;
                      final currentIndex = _items.indexWhere(
                        (item) => episodes
                            ? item.globalKey == widget.current.globalKey
                            : queue.isQueueActive
                            ? queue.playQueueItemIdFor(item) == currentId
                            : item.globalKey == widget.current.globalKey,
                      );
                      if (currentIndex >= 0 && _scrollToCurrent) {
                        scrollToCurrentItem(
                          _scroll,
                          _firstKey,
                          currentIndex,
                          isCurrent: () => mounted && _scopeCurrent(),
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final target = _currentKey.currentContext;
                            if (mounted && _scopeCurrent() && target != null) {
                              _scrollToCurrent = false;
                              Scrollable.ensureVisible(target, alignment: .25);
                              _initialFocus.focusWhenVisible();
                            }
                          });
                        });
                      }
                      return ListView(
                        controller: _scroll,
                        children: [
                          for (var index = 0; index < _items.length; index++)
                            _row(
                              _items[index],
                              key: index == currentIndex ? _currentKey : (index == 0 ? _firstKey : null),
                              current: index == currentIndex,
                              next: index == currentIndex + 1 && currentIndex >= 0,
                              hideSpoilers: hideSpoilers,
                            ),
                          if (_nextSeasonFirst != null) ...[
                            ListTile(
                              title: Text(
                                _nextSeason?.index == null
                                    ? t.videoControls.nextPlaying
                                    : t.videoControls.nextSeason(n: _nextSeason!.index!),
                              ),
                            ),
                            _row(_nextSeasonFirst!, current: false, next: true, hideSpoilers: hideSpoilers),
                          ],
                          if (_items.isEmpty && !_loading && !_failed)
                            ListTile(title: Text(t.videoControls.noQueueItems)),
                          if (_loading) const Center(child: CircularProgressIndicator()),
                          if (_failed)
                            TextButton(
                              onPressed: _items.isEmpty || (episodes && _season == null) ? _loadInitial : _more,
                              child: Text(t.common.retry),
                            ),
                          if (_hasMore && !_loading && !_failed)
                            TextButton(onPressed: _more, child: Text(t.videoControls.drawerLoadMore)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(MediaItem item, {Key? key, required bool current, required bool next, required bool hideSpoilers}) {
    final client = widget.offline ? null : context.tryGetMediaClientForServer(serverIdOrNull(item.serverId));
    final progress = item.durationMs != null && item.durationMs! > 0
        ? ((item.viewOffsetMs ?? 0) / item.durationMs!).clamp(0.0, 1.0)
        : 0.0;
    return FocusableListTile(
      key: key,
      focusNode: current ? _initialFocus.currentItem : null,
      leading: widget.offline || item.thumbPath == null
          ? null
          : MediaSelectorThumbnail(
              width: 60,
              height: 34,
              isCurrent: current,
              borderColor: Theme.of(context).colorScheme.primary,
              blurThumbnail: hideSpoilers && item.shouldHideSpoiler,
              thumbnail: OptimizedMediaImage.thumb(
                client: client,
                imagePath: item.thumbPath,
                width: 60,
                height: 34,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const AppIcon(Symbols.image_rounded),
              ),
            ),
      title: Text(
        item.isEpisode ? episodePopoverLabel(item) : item.title ?? t.common.unknown,
        style: current ? TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (next) Text(t.videoControls.nextPlaying),
          if (current && progress > 0) LinearProgressIndicator(value: progress, minHeight: 2),
        ],
      ),
      trailing: current
          ? const AppIcon(Symbols.play_circle_rounded)
          : item.isWatched
          ? const AppIcon(Symbols.check_rounded)
          : null,
      onTap: current || _selecting || !widget.canNavigate || !widget.isAuthorized() ? null : () => _select(item),
    );
  }
}
