import 'dart:math';

import 'package:flutter/foundation.dart';

import '../media/media_item.dart';
import '../media/play_queue.dart';
import '../models/plex/play_queue_response.dart';
import '../mixins/disposable_change_notifier_mixin.dart';

/// Fetches a window of items from a server-side play queue. Provider calls
/// this when the currently loaded window doesn't contain the next item it
/// needs to surface. Wired to a backend that maintains queues server-side
/// (Plex's `/playQueues`); left null for client-side queues (Jellyfin's
/// [LocalPlayQueue]) where the full list is already resident.
typedef PlayQueueWindowFetcher = Future<PlayQueueResponse?> Function(int playQueueId, {String? center, int window});

/// Outcome of resolving one direction in the active playback queue.
enum QueueNavigationStatus {
  /// The adjacent queue item was found.
  found,

  /// The active queue was loaded successfully and has no item in this direction.
  boundary,

  /// No active queue or matching current item was available.
  unavailable,

  /// A server-backed queue window could not be loaded or validated.
  failed,
}

@immutable
class QueueNavigationResult {
  const QueueNavigationResult._(this.status, this.item);

  const QueueNavigationResult.found(MediaItem item) : this._(QueueNavigationStatus.found, item);

  const QueueNavigationResult.boundary() : this._(QueueNavigationStatus.boundary, null);

  const QueueNavigationResult.unavailable() : this._(QueueNavigationStatus.unavailable, null);

  const QueueNavigationResult.failed() : this._(QueueNavigationStatus.failed, null);

  final QueueNavigationStatus status;
  final MediaItem? item;
}

enum VideoQueueRepeatMode { off, all, one }

@immutable
class QueuePageResult {
  const QueuePageResult({required this.items, required this.hasMore, required this.status});
  final List<MediaItem> items;
  final bool hasMore;
  final QueueNavigationStatus status;
}

/// Result of trying to locate the current queue index.
class _IndexLookupResult {
  final int? index;
  final bool attemptedLoad;
  final bool loadFailed;

  const _IndexLookupResult({this.index, this.attemptedLoad = false, this.loadFailed = false});
}

/// Manages playback state using Plex's play queue API.
/// This provider is session-only and does not persist across app restarts.
class PlaybackStateProvider with ChangeNotifier, DisposableChangeNotifierMixin {
  PlaybackStateProvider({Random? random}) : _random = random ?? Random();

  final Random _random;
  int _queueRevision = 0;
  int _modeRevision = 0;
  int? _playQueueVersion;
  bool _sourceQueueShuffled = false;
  List<int>? _canonicalOrderIds;
  List<int>? _effectiveOrderIds;
  final Map<int, MediaItem> _retainedItems = {};
  VideoQueueRepeatMode _repeatMode = VideoQueueRepeatMode.off;
  Future<bool>? _shuffleChangeFuture;
  bool? _pendingShuffle;

  int get queueRevision => _queueRevision;
  VideoQueueRepeatMode get repeatMode => _repeatMode;
  bool get queueModeChangePending => _shuffleChangeFuture != null;

  bool setRepeatMode(VideoQueueRepeatMode mode) {
    if (isDisposed || !isQueueActive) return false;
    if (_repeatMode == mode) return true;
    _repeatMode = mode;
    safeNotifyListeners();
    return true;
  }

  /// A mode change stages the whole queue-ID order before publishing it.
  /// Fetch failure, cancellation and a successor queue preserve the old mode.
  Future<bool> setShuffleEnabled(bool enabled, {bool Function()? isCurrent}) =>
      _requestShuffle(enabled, isCurrent: isCurrent);

  /// Launcher-only: choose a random head from a canonical queue, then use the
  /// same reversible order layer as an in-player shuffle change.
  Future<QueueNavigationResult> startShuffledPlayback({bool Function()? isCurrent}) async {
    if (!await _requestShuffle(true, fromBeginning: true, isCurrent: isCurrent)) {
      return const QueueNavigationResult.failed();
    }
    final current = currentQueueItem;
    return current == null ? const QueueNavigationResult.failed() : QueueNavigationResult.found(current);
  }

  Future<bool> _requestShuffle(bool enabled, {bool fromBeginning = false, bool Function()? isCurrent}) {
    if (isDisposed || !isQueueActive || !(isCurrent?.call() ?? true)) return Future.value(false);
    if (!fromBeginning && _shuffleChangeFuture != null && _pendingShuffle == enabled) return _shuffleChangeFuture!;
    final request = ++_modeRevision;
    final revision = _queueRevision;
    bool current() =>
        !isDisposed && revision == _queueRevision && request == _modeRevision && (isCurrent?.call() ?? true);
    _pendingShuffle = enabled;
    late final Future<bool> future;
    future =
        Future<bool>.microtask(() async {
          if (!current()) return false;
          if (!fromBeginning && _playQueueShuffled == enabled) return true;
          final canonical = _canonicalOrderIds ?? await _buildCanonicalOrder(isCurrent: current);
          if (canonical == null || canonical.isEmpty || !current()) return false;
          final cursor = _currentPlayQueueItemID;
          final index = cursor == null ? -1 : canonical.indexOf(cursor);
          if (index < 0) return false;
          final List<int> order;
          if (!enabled) {
            order = List.of(canonical);
          } else if (fromBeginning) {
            order = List.of(canonical)..shuffle(_random);
          } else {
            // Preserve played history and the exact playing entry. Only the future
            // changes; duplicate media entries retain distinct queue identities.
            final previousOrder = _effectiveOrderIds ?? canonical;
            final currentIndex = previousOrder.indexOf(cursor!);
            if (currentIndex < 0) return false;
            final remaining = previousOrder.skip(currentIndex + 1).toList()..shuffle(_random);
            order = [...previousOrder.take(currentIndex + 1), ...remaining];
          }
          final selectedId = fromBeginning ? order.first : cursor!;
          final selected = await _resolveQueueItem(selectedId, isCurrent: current);
          if (selected == null || !current() || (!fromBeginning && cursor != _currentPlayQueueItemID)) return false;
          _canonicalOrderIds = List.of(canonical);
          _effectiveOrderIds = order;
          _playQueueShuffled = enabled;
          if (fromBeginning) _currentPlayQueueItemID = selectedId;
          _retainedItems[selectedId] = selected;
          safeNotifyListeners();
          return true;
        }).whenComplete(() {
          if (identical(_shuffleChangeFuture, future)) {
            _shuffleChangeFuture = null;
            _pendingShuffle = null;
            safeNotifyListeners();
          }
        });
    _shuffleChangeFuture = future;
    safeNotifyListeners();
    return future;
  }

  List<int>? _queueIds(List<MediaItem> items) {
    final ids = <int>[];
    for (final item in items) {
      final id = item is PlexMediaItem ? item.playQueueItemId : null;
      if (id == null || ids.contains(id)) return null;
      ids.add(id);
    }
    return ids;
  }

  /// Build an ID index without retaining every fetched metadata window.
  /// A centered window must overlap the known sequence with identical IDs;
  /// queue IDs are opaque and are never incremented as if they were offsets.
  Future<List<int>?> _buildCanonicalOrder({required bool Function() isCurrent}) async {
    if (_sourceQueueShuffled) return null; // No evidence of the source's original order.
    if (_syntheticIds.isNotEmpty) return List.of(_syntheticIds);
    final total = _playQueueTotalCount;
    var ids = _queueIds(_loadedItems);
    if (ids == null || ids.isEmpty || total <= 0 || ids.length > total) return null;
    if (ids.length == total) return ids;
    final fetcher = _windowFetcher;
    final queueId = _playQueueId;
    final version = _playQueueVersion;
    if (fetcher == null || queueId == null) return null;
    var leftDone = false;
    for (var step = 0; step <= total + 1 && ids!.length < total; step++) {
      if (!isCurrent()) return null;
      final anchor = leftDone ? ids.last : ids.first;
      PlayQueueResponse? response;
      try {
        response = await fetcher(queueId, center: anchor.toString(), window: _windowSize);
      } catch (_) {
        return null;
      }
      if (!isCurrent() ||
          !identical(fetcher, _windowFetcher) ||
          response == null ||
          response.playQueueID != queueId ||
          response.playQueueVersion != version ||
          response.playQueueShuffled ||
          (response.playQueueTotalCount ?? response.size ?? 0) != total) {
        return null;
      }
      final fresh = _queueIds(response.items ?? const []);
      if (fresh == null || fresh.isEmpty) return null;
      final oldAnchorIndex = ids.indexOf(anchor);
      final freshAnchorIndex = fresh.indexOf(anchor);
      if (freshAnchorIndex < 0) return null;
      final offset = oldAnchorIndex - freshAnchorIndex;
      for (var i = 0; i < fresh.length; i++) {
        final oldIndex = offset + i;
        if (oldIndex >= 0 && oldIndex < ids.length && ids[oldIndex] != fresh[i]) return null;
      }
      final merged = <int>[
        if (offset < 0) ...fresh.take(-offset),
        ...ids,
        if (offset + fresh.length > ids.length) ...fresh.skip(ids.length - offset),
      ];
      if (merged.toSet().length != merged.length || merged.length > total) return null;
      if (merged.length == ids.length) {
        if (leftDone) return null; // Both ends reached before the advertised count.
        leftDone = true;
      }
      ids = merged;
    }
    return isCurrent() && ids!.length == total ? ids : null;
  }

  /// Atomically publish a launch prepared in an isolated provider. A loading
  /// dialog can be canceled without replacing the queue that was playing.
  bool adoptPreparedQueue(PlaybackStateProvider prepared) {
    if (isDisposed || !prepared.isQueueActive || prepared.queueModeChangePending) return false;
    _resetQueueModes();
    _playQueueId = prepared._playQueueId;
    _playQueueTotalCount = prepared._playQueueTotalCount;
    _playQueueVersion = prepared._playQueueVersion;
    _playQueueShuffled = prepared._playQueueShuffled;
    _sourceQueueShuffled = prepared._sourceQueueShuffled;
    _currentPlayQueueItemID = prepared._currentPlayQueueItemID;
    _loadedItems = List.of(prepared._loadedItems);
    _syntheticIds = List.of(prepared._syntheticIds);
    _canonicalOrderIds = prepared._canonicalOrderIds == null ? null : List.of(prepared._canonicalOrderIds!);
    _effectiveOrderIds = prepared._effectiveOrderIds == null ? null : List.of(prepared._effectiveOrderIds!);
    _retainedItems.addAll(prepared._retainedItems);
    _repeatMode = prepared._repeatMode;
    _contextKey = prepared._contextKey;
    _windowFetcher = prepared._windowFetcher;
    _isQueueMode = true;
    safeNotifyListeners();
    return true;
  }

  /// Keep a resume-offset copy tied to the same queue entry on launch.
  bool replaceQueueEntry(MediaItem original, MediaItem replacement) {
    final id = playQueueItemIdFor(original);
    if (id == null || original.globalKey != replacement.globalKey) return false;
    final index = _findLoadedIndex(id);
    if (index >= 0) _loadedItems[index] = replacement;
    _retainedItems[id] = replacement;
    return true;
  }

  void _resetQueueModes() {
    ++_queueRevision;
    ++_modeRevision;
    _canonicalOrderIds = null;
    _effectiveOrderIds = null;
    _retainedItems.clear();
    _repeatMode = VideoQueueRepeatMode.off;
    _shuffleChangeFuture = null;
    _pendingShuffle = null;
    _playQueueVersion = null;
  }

  // Play queue state
  int? _playQueueId;
  int _playQueueTotalCount = 0;
  bool _playQueueShuffled = false;
  int? _currentPlayQueueItemID;

  // Windowed items (loaded around current position)
  List<MediaItem> _loadedItems = [];
  final int _windowSize = 50; // Number of items to keep in memory

  /// Synthetic per-item queue IDs for client-side queues (Jellyfin, etc.).
  /// Parallel to [_loadedItems] — `_syntheticIds[i]` is the queue ID for
  /// `_loadedItems[i]`. Empty when the queue is server-side (Plex), where
  /// the real id lives on [PlexMediaItem.playQueueItemId].
  List<int> _syntheticIds = const [];

  String? _contextKey; // The show/season/playlist ratingKey for this session
  bool _isQueueMode = false;

  // Client reference for loading more items
  PlayQueueWindowFetcher? _windowFetcher;

  /// Returns the queue id for [item] within the current queue. For Plex
  /// items this is the server's `playQueueItemID`; for client-side queues
  /// (Jellyfin) it's a synthetic index assigned in [setPlaybackFromLocalQueue].
  /// Returns null when [item] isn't in the current loaded window.
  int? playQueueItemIdFor(MediaItem item) {
    if (!_isQueueMode) return null;
    if (item is PlexMediaItem && item.playQueueItemId != null) {
      final id = item.playQueueItemId!;
      final loadedIndex = _findLoadedIndex(id);
      final stored = loadedIndex < 0 ? _retainedItems[id] : _loadedItems[loadedIndex];
      if (stored == null || stored.globalKey != item.globalKey) {
        return null;
      }
      return id;
    }
    final idx = _loadedItems.indexOf(item);
    if (idx < 0 || idx >= _syntheticIds.length) return null;
    return _syntheticIds[idx];
  }

  bool get isShuffleActive => _playQueueShuffled;

  /// Whether playlist/collection mode is currently active
  bool get isPlaylistActive => _isQueueMode;

  /// Whether any queue-based playback is active
  bool get isQueueActive => _playQueueId != null && _isQueueMode;

  /// Whether [item] belongs to the currently active queue. Plex membership
  /// requires both the server queue id and media identity to match a loaded
  /// entry. Client-side membership uses the exact stored object because
  /// duplicate media entries in playlists must remain distinguishable.
  /// Gates the player's "preserve vs. wipe launcher-set queue" decision in
  /// [VideoPlayerScreen.initState], `_ensurePlayQueue`, and
  /// [EpisodeNavigationService]'s `_ensureLocalEpisodeQueue`, so a
  /// playlist, collection, or shuffled show queue survives entry into the
  /// player instead of being replaced with a sequential show queue.
  bool isItemInActiveQueue(MediaItem item) => isQueueActive && playQueueItemIdFor(item) != null;

  /// The context key (show/season/playlist ratingKey) for the current session
  String? get shuffleContextKey => _contextKey;

  int? get playQueueId => _playQueueId;

  /// The currently loaded queue items (windowed subset of full queue)
  List<MediaItem> get loadedItems {
    final order = _effectiveOrderIds;
    if (order == null) return List.unmodifiable(_loadedItems);
    final resident = <int, MediaItem>{};
    for (var i = 0; i < _loadedItems.length; i++) {
      final id = _syntheticIds.isNotEmpty ? _syntheticIds[i] : (_loadedItems[i] as PlexMediaItem).playQueueItemId;
      if (id != null) resident[id] = _loadedItems[i];
    }
    return List.unmodifiable([
      for (final id in order)
        if (resident[id] != null) resident[id]!,
    ]);
  }

  int? get currentPlayQueueItemID => _currentPlayQueueItemID;

  /// The queue item the cursor currently points at, or null when no queue
  /// is active or the cursor is outside the loaded window.
  MediaItem? get currentQueueItem => _currentPlayQueueItemID == null ? null : _findLoadedItem(_currentPlayQueueItemID!);

  /// Set the client reference for loading more items
  void setPlayQueueWindowFetcher(PlayQueueWindowFetcher? fetcher) {
    if (!identical(_windowFetcher, fetcher)) {
      ++_queueRevision;
      ++_modeRevision;
    }
    _windowFetcher = fetcher;
  }

  /// Update the queue cursor after playback of [metadata] starts.
  ///
  /// Items outside the active loaded window are rejected. A server-stamped
  /// queue id alone is not proof that an item belongs to this queue.
  void setCurrentItem(MediaItem metadata) {
    if (!_isQueueMode) return;
    final id = playQueueItemIdFor(metadata);
    if (id == null || id == _currentPlayQueueItemID) return;
    _currentPlayQueueItemID = id;
    safeNotifyListeners();
  }

  /// Initialize playback from a play queue
  /// Call this after creating a play queue via the API
  Future<void> setPlaybackFromPlayQueue(PlayQueueResponse playQueue, String? contextKey) async {
    _resetQueueModes();
    _playQueueVersion = playQueue.playQueueVersion;
    _sourceQueueShuffled = playQueue.playQueueShuffled;
    _playQueueId = playQueue.playQueueID;
    // Use size or items length as fallback if totalCount is null
    _playQueueTotalCount = playQueue.playQueueTotalCount ?? playQueue.size ?? (playQueue.items?.length ?? 0);
    _playQueueShuffled = playQueue.playQueueShuffled;
    _currentPlayQueueItemID = playQueue.playQueueSelectedItemID;

    // Items arrive pre-tagged with server info by the producing mapper.
    _loadedItems = playQueue.items ?? [];
    // Plex items carry their own playQueueItemId — no synthetic IDs needed.
    _syntheticIds = const [];

    _contextKey = contextKey;
    _isQueueMode = true;
    safeNotifyListeners();
  }

  /// Initialize playback from a [LocalPlayQueue] (Jellyfin / any backend
  /// without a server-side queue). Synthetic per-item queue IDs are
  /// recorded in [_syntheticIds] (parallel to [_loadedItems]) so the
  /// existing Plex-shaped UI — Queue sheet, content strip, current item
  /// highlight — keeps working without a parallel rendering path. Items
  /// themselves are stored unmutated.
  ///
  /// `playQueueId` is set to a sentinel so [isQueueActive] returns true.
  /// Window-extension paths (`_ensureItemsLoaded`, `getNextEpisode`) consult
  /// `_windowFetcher`, which stays null for client-side queues — JF callers
  /// resolve adjacent items through [EpisodeNavigationService] instead.
  void setPlaybackFromLocalQueue(LocalPlayQueue queue, {String? contextKey}) {
    _resetQueueModes();
    _sourceQueueShuffled = queue.shuffled;
    _playQueueId = -1; // sentinel for "client-side queue"
    _playQueueTotalCount = queue.items.length;
    _playQueueShuffled = queue.shuffled;
    _loadedItems = List.of(queue.items);
    _syntheticIds = [for (var i = 0; i < queue.items.length; i++) i];
    _currentPlayQueueItemID = queue.currentIndex;
    _contextKey = contextKey;
    _isQueueMode = true;
    _windowFetcher = null; // disable server-side window extension
    safeNotifyListeners();
  }

  /// Load a server queue window centered on [centerPlayQueueItemID].
  ///
  /// Returns false for transport errors, malformed/empty responses, when
  /// the requested center is absent from the returned window, or when the
  /// queue was cleared or replaced while the fetch was in flight — a window
  /// belongs to the queue id it was requested for and must never overwrite
  /// a successor's items.
  Future<bool> _loadServerWindow(int centerPlayQueueItemID) async {
    final fetcher = _windowFetcher;
    final queueId = _playQueueId;
    final revision = _queueRevision;
    if (fetcher == null || queueId == null) return false;
    try {
      final response = await fetcher(queueId, center: centerPlayQueueItemID.toString(), window: _windowSize);
      if (isDisposed || _queueRevision != revision || _playQueueId != queueId || !identical(fetcher, _windowFetcher)) {
        return false;
      }
      final items = response?.items;
      if (response == null ||
          response.playQueueID != queueId ||
          items == null ||
          items.isEmpty ||
          (_playQueueVersion != null && response.playQueueVersion != _playQueueVersion) ||
          !items.any((item) => item is PlexMediaItem && item.playQueueItemId == centerPlayQueueItemID)) {
        return false;
      }
      final playing = currentQueueItem;
      if (playing != null && _currentPlayQueueItemID != null) _retainedItems[_currentPlayQueueItemID!] = playing;
      _loadedItems = items;
      _playQueueTotalCount = response.playQueueTotalCount ?? response.size ?? items.length;
      if (_effectiveOrderIds == null) _playQueueShuffled = response.playQueueShuffled;
      safeNotifyListeners();
      return _findLoadedIndex(centerPlayQueueItemID) != -1;
    } catch (_) {
      return false;
    }
  }

  /// Load a missing queue item without refetching an item already resident.
  Future<bool> _ensureItemsLoaded(int targetPlayQueueItemID) async {
    if (_findLoadedIndex(targetPlayQueueItemID) != -1) return true;
    return _loadServerWindow(targetPlayQueueItemID);
  }

  Future<_IndexLookupResult> _getCurrentIndex(String currentItemKey, {bool loadIfMissing = false}) async {
    if (!_isQueueMode || _loadedItems.isEmpty || _currentPlayQueueItemID == null) {
      return const _IndexLookupResult();
    }

    int findCurrent() {
      final cursorIndex = _findLoadedIndex(_currentPlayQueueItemID!);
      if (cursorIndex != -1 && _matchesItemKey(_loadedItems[cursorIndex], currentItemKey)) {
        return cursorIndex;
      }

      var matchedIndex = -1;
      for (var i = 0; i < _loadedItems.length; i++) {
        if (!_matchesItemKey(_loadedItems[i], currentItemKey)) continue;
        if (matchedIndex != -1) return -1;
        matchedIndex = i;
      }
      return matchedIndex;
    }

    var currentIndex = findCurrent();
    if (currentIndex != -1) return _IndexLookupResult(index: currentIndex);

    if (!loadIfMissing || _windowFetcher == null || _playQueueId == null) {
      return const _IndexLookupResult();
    }

    final loaded = await _ensureItemsLoaded(_currentPlayQueueItemID!);
    if (!loaded) {
      return const _IndexLookupResult(attemptedLoad: true, loadFailed: true);
    }

    currentIndex = findCurrent();
    if (currentIndex == -1) {
      return const _IndexLookupResult(attemptedLoad: true, loadFailed: true);
    }
    return _IndexLookupResult(index: currentIndex, attemptedLoad: true);
  }

  bool _matchesItemKey(MediaItem item, String currentItemKey) =>
      item.id == currentItemKey || item.globalKey == currentItemKey;

  /// Returns the index of the item with [playQueueItemId] in [_loadedItems],
  /// or -1 if absent. Bridges Plex (real id on [PlexMediaItem]) and
  /// client-side (synthetic id in [_syntheticIds]) queues.
  int _findLoadedIndex(int playQueueItemId) {
    for (var i = 0; i < _loadedItems.length; i++) {
      final item = _loadedItems[i];
      if (item is PlexMediaItem && item.playQueueItemId == playQueueItemId) {
        return i;
      }
      if (i < _syntheticIds.length && _syntheticIds[i] == playQueueItemId) {
        return i;
      }
    }
    return -1;
  }

  MediaItem? _findLoadedItem(int playQueueItemId) {
    final index = _findLoadedIndex(playQueueItemId);
    return index == -1 ? _retainedItems[playQueueItemId] : _loadedItems[index];
  }

  /// Gets the next item in the playback queue.
  ///
  /// Returns a typed result so a queue-window failure cannot be mistaken for
  /// the confirmed end of the queue. Entries backed by the same file as the
  /// one playing are skipped: Plex lists each episode of a multi-episode file
  /// (`S02E24-E25.mkv`) as its own queue item, and advancing to the sibling
  /// would replay the file from the start (#1500). [playedPartId] pins the
  /// comparison to the file of the part actually playing when known;
  /// otherwise any file overlap with the current item counts.
  Future<QueueNavigationResult> getNextEpisode(String currentItemKey, {String? playedPartId}) async {
    if (!_isQueueMode) return const QueueNavigationResult.unavailable();
    final revision = _queueRevision;
    final modeRevision = _modeRevision;
    final repeatMode = _repeatMode;
    bool navigationCurrent() =>
        !isDisposed && revision == _queueRevision && modeRevision == _modeRevision && repeatMode == _repeatMode;

    final indexResult = await _getCurrentIndex(currentItemKey, loadIfMissing: true);
    if (!navigationCurrent()) return const QueueNavigationResult.failed();
    if (indexResult.index == null) {
      return indexResult.loadFailed ? const QueueNavigationResult.failed() : const QueueNavigationResult.unavailable();
    }

    final current = _loadedItems[indexResult.index!];
    var anchor = current;
    // Bounded so a pathological all-same-file queue cannot spin.
    for (var steps = 0; steps <= _playQueueTotalCount; steps++) {
      final result = await _itemAtOffset(anchor, 1, wrap: _repeatMode == VideoQueueRepeatMode.all);
      if (!navigationCurrent()) return const QueueNavigationResult.failed();
      final candidate = result.item;
      if (result.status != QueueNavigationStatus.found || candidate == null) {
        return result;
      }
      if (playQueueItemIdFor(candidate) == playQueueItemIdFor(current)) return const QueueNavigationResult.boundary();
      if (!current.sharesFileWith(candidate, playedPartId: playedPartId)) {
        return result;
      }
      anchor = candidate;
    }
    return const QueueNavigationResult.boundary();
  }

  /// Gets the previous item in the playback queue.
  /// Returns null if at the beginning of the queue or current item is not in queue.
  ///
  /// Mirrors [getNextEpisode]'s multi-episode-file handling (#1500): entries
  /// backed by the file that's playing are skipped, and the result is
  /// collapsed to the first episode of its same-file group so a
  /// multi-episode file is entered at the episode that fronts it.
  Future<QueueNavigationResult> getPreviousEpisode(String currentItemKey, {String? playedPartId}) async {
    if (!_isQueueMode) return const QueueNavigationResult.unavailable();
    final revision = _queueRevision;
    final modeRevision = _modeRevision;
    final repeatMode = _repeatMode;
    bool navigationCurrent() =>
        !isDisposed && revision == _queueRevision && modeRevision == _modeRevision && repeatMode == _repeatMode;

    final indexResult = await _getCurrentIndex(currentItemKey, loadIfMissing: true);
    if (!navigationCurrent()) return const QueueNavigationResult.failed();
    if (indexResult.index == null) {
      return indexResult.loadFailed ? const QueueNavigationResult.failed() : const QueueNavigationResult.unavailable();
    }

    final current = _loadedItems[indexResult.index!];
    MediaItem candidate = current;
    for (var steps = 0; steps <= _playQueueTotalCount; steps++) {
      final result = await _itemAtOffset(candidate, -1, wrap: _repeatMode == VideoQueueRepeatMode.all);
      if (!navigationCurrent()) return const QueueNavigationResult.failed();
      final before = result.item;
      if (result.status != QueueNavigationStatus.found || before == null) {
        return result;
      }
      candidate = before;
      if (playQueueItemIdFor(candidate) == playQueueItemIdFor(current)) return const QueueNavigationResult.boundary();
      if (!current.sharesFileWith(candidate, playedPartId: playedPartId)) break;
    }

    // Collapse to the first episode of the candidate's same-file group.
    for (var steps = 0; steps <= _playQueueTotalCount; steps++) {
      final result = await _itemAtOffset(candidate, -1);
      if (!navigationCurrent()) return const QueueNavigationResult.failed();
      final before = result.item;
      if (result.status == QueueNavigationStatus.failed) return result;
      if (result.status != QueueNavigationStatus.found || before == null || !candidate.sharesFileWith(before)) {
        return QueueNavigationResult.found(candidate);
      }
      candidate = before;
    }
    return QueueNavigationResult.found(candidate);
  }

  /// The queue item [delta] steps from [anchor], extending a server-backed
  /// window when needed. The centered response proves whether [anchor] is at
  /// the global boundary; a window-local index is never compared with the
  /// queue's global item count.
  Future<QueueNavigationResult> _itemAtOffset(MediaItem anchor, int delta, {bool wrap = false}) async {
    final anchorId = playQueueItemIdFor(anchor);
    if (anchorId == null) return const QueueNavigationResult.unavailable();
    final order = _effectiveOrderIds;
    if (order != null) {
      final index = order.indexOf(anchorId);
      if (index < 0) return const QueueNavigationResult.unavailable();
      var target = index + delta;
      if (target < 0 || target >= order.length) {
        if (!wrap || order.isEmpty) return const QueueNavigationResult.boundary();
        target = target < 0 ? order.length - 1 : 0;
      }
      final item = await _resolveQueueItem(order[target]);
      return item == null ? const QueueNavigationResult.failed() : QueueNavigationResult.found(item);
    }
    var anchorIndex = _findLoadedIndex(anchorId);
    if (anchorIndex == -1) {
      if (!await _ensureItemsLoaded(anchorId)) return const QueueNavigationResult.failed();
      anchorIndex = _findLoadedIndex(anchorId);
      if (anchorIndex == -1) return const QueueNavigationResult.failed();
    }

    var target = anchorIndex + delta;
    if (target >= 0 && target < _loadedItems.length) {
      return QueueNavigationResult.found(_loadedItems[target]);
    }

    // Local queues are fully resident, so their window edge is the queue edge.
    if (_windowFetcher == null || _playQueueId == null) {
      return wrap ? _queueEndpoint(first: delta > 0) : const QueueNavigationResult.boundary();
    }
    if (_playQueueTotalCount > 0 && _loadedItems.length >= _playQueueTotalCount) {
      return wrap ? _queueEndpoint(first: delta > 0) : const QueueNavigationResult.boundary();
    }

    // Refresh around the actual anchor. Queue ids are opaque and need not be
    // consecutive, so never guess the neighbour's id.
    if (!await _loadServerWindow(anchorId)) {
      return const QueueNavigationResult.failed();
    }
    anchorIndex = _findLoadedIndex(anchorId);
    if (anchorIndex == -1) return const QueueNavigationResult.failed();
    target = anchorIndex + delta;
    return target >= 0 && target < _loadedItems.length
        ? QueueNavigationResult.found(_loadedItems[target])
        : wrap
        ? _queueEndpoint(first: delta > 0)
        : const QueueNavigationResult.boundary();
  }

  Future<MediaItem?> _resolveQueueItem(int id, {bool Function()? isCurrent}) async {
    if (isDisposed || !(isCurrent?.call() ?? true)) return null;
    final stored = _findLoadedItem(id);
    if (stored != null) return stored;
    if (!await _ensureItemsLoaded(id) || !(isCurrent?.call() ?? true)) return null;
    return _findLoadedItem(id);
  }

  Future<QueueNavigationResult> _queueEndpoint({required bool first}) async {
    if (_loadedItems.isEmpty) return const QueueNavigationResult.unavailable();
    final order = _effectiveOrderIds;
    if (order != null) {
      final item = await _resolveQueueItem(first ? order.first : order.last);
      return item == null ? const QueueNavigationResult.failed() : QueueNavigationResult.found(item);
    }
    final revision = _queueRevision;
    for (var step = 0; step <= _playQueueTotalCount; step++) {
      if (isDisposed || revision != _queueRevision || _loadedItems.isEmpty) return const QueueNavigationResult.failed();
      final item = first ? _loadedItems.first : _loadedItems.last;
      final id = playQueueItemIdFor(item);
      if (id == null) return const QueueNavigationResult.failed();
      if (_windowFetcher == null || _loadedItems.length >= _playQueueTotalCount) {
        return QueueNavigationResult.found(item);
      }
      if (!await _loadServerWindow(id)) return const QueueNavigationResult.failed();
      final index = _findLoadedIndex(id);
      if ((first && index == 0) || (!first && index == _loadedItems.length - 1)) {
        return QueueNavigationResult.found(item);
      }
    }
    return const QueueNavigationResult.failed();
  }

  /// Completion has its own target: repeat-one must never hijack manual Next.
  Future<QueueNavigationResult> getCompletionTarget(String currentItemKey, {String? playedPartId}) async {
    final revision = _queueRevision;
    if (!isQueueActive) return const QueueNavigationResult.unavailable();
    final lookup = await _getCurrentIndex(currentItemKey, loadIfMissing: true);
    if (isDisposed || revision != _queueRevision || lookup.index == null) {
      return lookup.loadFailed ? const QueueNavigationResult.failed() : const QueueNavigationResult.unavailable();
    }
    final current = _loadedItems[lookup.index!];
    if (_repeatMode == VideoQueueRepeatMode.one) return QueueNavigationResult.found(current);
    final next = await getNextEpisode(currentItemKey, playedPartId: playedPartId);
    if (isDisposed || revision != _queueRevision) return const QueueNavigationResult.failed();
    // A single playable file can repeat at EOF, even though manual Next must
    // continue to skip the file's other episode entries.
    if (_repeatMode == VideoQueueRepeatMode.all && next.status == QueueNavigationStatus.boundary) {
      return QueueNavigationResult.found(current);
    }
    return next;
  }

  /// Real current/upcoming entries in effective order, with explicit failure
  /// and continuation state. Returned entries remain valid queue selections.
  Future<QueuePageResult> loadQueuePage({int? afterQueueItemId, int? limit, bool Function()? isCurrent}) async {
    final revision = _queueRevision;
    final modeRevision = _modeRevision;
    bool current() =>
        !isDisposed && revision == _queueRevision && modeRevision == _modeRevision && (isCurrent?.call() ?? true);
    if (!isQueueActive || !current()) {
      return const QueuePageResult(items: [], hasMore: false, status: QueueNavigationStatus.unavailable);
    }
    final startId = afterQueueItemId ?? _currentPlayQueueItemID;
    var anchor = startId == null ? null : await _resolveQueueItem(startId, isCurrent: current);
    if (anchor == null || !current()) {
      return const QueuePageResult(items: [], hasMore: true, status: QueueNavigationStatus.failed);
    }
    final items = <MediaItem>[];
    final pageSize = limit ?? _windowSize;
    if (pageSize <= 0) {
      return const QueuePageResult(items: [], hasMore: false, status: QueueNavigationStatus.unavailable);
    }
    if (afterQueueItemId == null) items.add(anchor);
    while (current() && items.length < pageSize) {
      final next = await _itemAtOffset(anchor!, 1);
      if (!current()) return const QueuePageResult(items: [], hasMore: true, status: QueueNavigationStatus.failed);
      if (next.status != QueueNavigationStatus.found || next.item == null) {
        for (final item in items) {
          final id = playQueueItemIdFor(item);
          if (id != null) _retainedItems[id] = item;
        }
        return QueuePageResult(
          items: List.unmodifiable(items),
          hasMore: next.status != QueueNavigationStatus.boundary,
          status: next.status == QueueNavigationStatus.boundary && items.isNotEmpty
              ? QueueNavigationStatus.found
              : next.status,
        );
      }
      anchor = next.item!;
      final id = playQueueItemIdFor(anchor);
      if (id == null) {
        return QueuePageResult(items: List.unmodifiable(items), hasMore: true, status: QueueNavigationStatus.failed);
      }
      _retainedItems[id] = anchor;
      items.add(anchor);
    }
    if (!current()) return const QueuePageResult(items: [], hasMore: true, status: QueueNavigationStatus.failed);
    final following = await _itemAtOffset(anchor!, 1);
    if (!current()) return const QueuePageResult(items: [], hasMore: true, status: QueueNavigationStatus.failed);
    for (final item in items) {
      final id = playQueueItemIdFor(item);
      if (id != null) _retainedItems[id] = item;
    }
    return QueuePageResult(
      items: List.unmodifiable(items),
      hasMore: following.status != QueueNavigationStatus.boundary,
      status: following.status == QueueNavigationStatus.failed
          ? QueueNavigationStatus.failed
          : QueueNavigationStatus.found,
    );
  }

  /// Queue items backed by the same physical file as [current] — the other
  /// episodes of a Plex multi-episode file (#1500), which should share its
  /// watched state. Scans the loaded window only: in sequential order
  /// same-file episodes are adjacent, so they are always co-resident.
  /// [current] may be a different object instance than the queue's copy;
  /// exclusion is by item id.
  List<MediaItem> sameFileSiblings(MediaItem current, {String? playedPartId}) {
    if (!_isQueueMode) return const [];
    final seenIds = <String>{current.id};
    return [
      for (final item in _loadedItems)
        if (seenIds.add(item.id) && current.sharesFileWith(item, playedPartId: playedPartId)) item,
    ];
  }

  /// Clears the playback queue and exits queue mode
  void clearShuffle() {
    _resetQueueModes();
    _sourceQueueShuffled = false;
    _playQueueId = null;
    _playQueueTotalCount = 0;
    _playQueueShuffled = false;
    _currentPlayQueueItemID = null;
    _loadedItems = [];
    _syntheticIds = const [];
    _contextKey = null;
    _isQueueMode = false;
    safeNotifyListeners();
  }
}
