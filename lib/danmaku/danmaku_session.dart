import 'dart:async';

import 'package:flutter/foundation.dart';

import 'danmaku_api_client.dart';
import 'danmaku_matcher.dart';
import 'danmaku_comment.dart';
import 'danmaku_filter.dart';
import 'danmaku_parser.dart';
import 'danmaku_settings.dart';
import 'danmaku_settings_repository.dart';
import 'danmaku_source.dart';

export 'danmaku_settings.dart' show DanmakuMatchContext;

typedef DanmakuClientFactory = DanmakuApiClient Function(DanmakuSource source, DanmakuCredentials? credentials);

/// Persisted preferences and the current item's effective data, shared by all UI.
class DanmakuSession extends ChangeNotifier {
  DanmakuSession._({DanmakuSettingsRepository? repository, DanmakuClientFactory? clientFactory})
    : _repository = repository ?? DanmakuSettingsRepository(),
      _clientFactory =
          clientFactory ??
          ((source, credentials) =>
              DanmakuApiClient(baseUrl: source.baseUrl, sourceId: source.id, credentials: credentials));

  @visibleForTesting
  factory DanmakuSession.forTesting({DanmakuSettingsRepository? repository, DanmakuClientFactory? clientFactory}) =>
      DanmakuSession._(repository: repository, clientFactory: clientFactory);

  static final DanmakuSession instance = DanmakuSession._();
  final DanmakuSettingsRepository _repository;
  final DanmakuClientFactory _clientFactory;
  DanmakuSettings _settings = const DanmakuSettings();
  final Map<String, DanmakuMatchMemory> _runtimeMemories = {};
  final Set<String> _unpersistedMemories = {};
  Future<void>? _initialization;
  bool _isInitialized = false;
  Future<void> _writes = Future.value();
  DanmakuMatchContext? _context;
  int _generation = 0;
  int _contextGeneration = 0;
  int? _durationMs;
  int _offsetMs = 0;
  int _episodeOffset = 0;
  DanmakuSearchHit? _currentHit;
  List<DanmakuComment> _rawComments = const [];
  List<DanmakuComment> _comments = const [];
  String? _selectedSourceId;
  bool _manualSelection = false;
  String? sourceLabel;
  String? error;
  bool loading = false;
  int dataVersion = 0;
  Map<String, String> sourceFailures = const {};
  List<DanmakuAnime> candidates = const [];

  bool get enabled => _settings.enabled;
  bool get heatmapEnabled => _settings.heatmapEnabled;
  double get fontSize => _settings.fontSize;
  double get opacity => _settings.opacity;
  DanmakuSettings get presentation => _settings;
  bool get withRelated => _settings.withRelated;
  int get chConvert => _settings.chConvert;
  int get offsetMs => _offsetMs;
  int get episodeOffset => _episodeOffset;
  List<DanmakuSource> get sources => _settings.sources;
  List<DanmakuComment> get comments => _comments;
  String? get selectedSourceId => _selectedSourceId;
  DanmakuMatchContext? get mediaContext => _context;
  String get suggestedQuery => _context?.suggestedQuery ?? '';

  /// Search-box default: [suggestedQuery] plus the episode (`第N集`).
  String get displayQuery {
    final context = _context;
    if (context == null) return '';
    final episode = context.episodeNumber;
    return danmakuDisplayQuery(context.suggestedQuery, episode == null ? null : episode + _episodeOffset);
  }

  bool get initialized => _isInitialized;
  bool ownsContext(int ownerGeneration) => _context != null && ownerGeneration == _contextGeneration;

  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    return _initialization ??= () async {
      try {
        _settings = await _repository.load();
        if (_repository.recoveredCorruptData) error = 'settings_invalid';
        _restoreMemory();
        _rebuildEffective();
        _isInitialized = true;
        notifyListeners();
      } catch (_) {
        _initialization = null;
        rethrow;
      }
    }();
  }

  /// Re-reads the encrypted settings resource after an out-of-process import,
  /// such as the QR sync receiver. Queued edits finish first so a late reload
  /// cannot overwrite them.
  Future<void> reload() {
    final operation = _writes.then((_) async {
      await initialize();
      final previous = _settings;
      final next = await _repository.load();
      _settings = next;
      if (_repository.recoveredCorruptData) error = 'settings_invalid';

      final selectedId = _selectedSourceId;
      final selected = next.sources.where((source) => source.id == selectedId).firstOrNull;
      final previousSelected = previous.sources.where((source) => source.id == selectedId).firstOrNull;
      if (selectedId != null &&
          (selected == null || !selected.enabled || selected.baseUrl != previousSelected?.baseUrl)) {
        _selectedSourceId = null;
        _manualSelection = false;
        _offsetMs = 0;
        _episodeOffset = 0;
        _invalidateRequests();
        _clearData();
      } else if (selectedId == null) {
        _restoreMemory();
        _rebuildEffective();
      } else {
        _rebuildEffective();
      }
      notifyListeners();
    });
    _writes = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> _mutate(DanmakuSettings Function(DanmakuSettings) change) {
    final operation = _writes.then((_) async {
      await initialize();
      final next = change(_settings);
      if (identical(next, _settings)) return;
      await _repository.save(next);
      final filtersChanged =
          next.mergeDuplicates != _settings.mergeDuplicates ||
          !listEquals(next.blockedKeywords, _settings.blockedKeywords);
      _settings = next;
      if (filtersChanged) _rebuildEffective();
      if (error == 'settings_invalid') error = null;
      notifyListeners();
    });
    // Keep a failed write visible to its caller without poisoning later saves.
    _writes = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> updateStyle({
    bool? enabled,
    bool? heatmapEnabled,
    double? opacity,
    double? fontSize,
    int? offsetMs,
    bool? withRelated,
    int? chConvert,
    double? speed,
    int? maxOnScreen,
    int? scrollLines,
    int? topLines,
    int? bottomLines,
    bool? preventOverlap,
    bool? mergeDuplicates,
    List<String>? blockedKeywords,
  }) async {
    if ((fontSize != null && (!fontSize.isFinite || fontSize < 8 || fontSize > 64)) ||
        (opacity != null && (!opacity.isFinite || opacity < 0 || opacity > 1)) ||
        (chConvert != null && (chConvert < 0 || chConvert > 2))) {
      throw const FormatException('invalid_style');
    }
    final keywords = blockedKeywords?.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();
    if ((speed != null && (!speed.isFinite || speed < 0.25 || speed > 3)) ||
        (maxOnScreen != null && (maxOnScreen < 1 || maxOnScreen > 200)) ||
        [scrollLines, topLines, bottomLines].any((value) => value != null && (value < 0 || value > 30)) ||
        (keywords != null && (keywords.length > 100 || keywords.any((s) => s.length > 200)))) {
      throw const FormatException('invalid_presentation');
    }
    final contextGeneration = _contextGeneration;
    await _mutate(
      (settings) => settings.copyWith(
        enabled: enabled,
        heatmapEnabled: heatmapEnabled,
        opacity: opacity,
        fontSize: fontSize,
        withRelated: withRelated,
        chConvert: chConvert,
        speed: speed,
        maxOnScreen: maxOnScreen,
        scrollLines: scrollLines,
        topLines: topLines,
        bottomLines: bottomLines,
        preventOverlap: preventOverlap,
        mergeDuplicates: mergeDuplicates,
        blockedKeywords: keywords,
        memories: contextGeneration == _contextGeneration
            ? _updatedMemory(settings, offsetMs: offsetMs)
            : settings.memories,
      ),
    );
    if (offsetMs != null && contextGeneration == _contextGeneration) {
      _offsetMs = offsetMs;
      _commitRuntimeOffsets();
      _rebuildEffective();
      notifyListeners();
    }
  }

  Future<void> saveSource(DanmakuSource source, {String? appId, String? appSecret}) async {
    final endpoint = DanmakuEndpoint(source.baseUrl);
    if (source.id.isEmpty || source.name.trim().isEmpty) throw const FormatException('invalid_source');
    final normalized = source.copyWith(name: source.name.trim(), baseUrl: endpoint.baseUrl);
    var changedAddress = false;
    await _mutate((settings) {
      final previous = settings.sources.where((s) => s.id == source.id).firstOrNull;
      changedAddress = previous != null && previous.baseUrl != normalized.baseUrl;
      final next = [...settings.sources];
      final index = next.indexWhere((s) => s.id == source.id);
      if (index < 0) {
        next.add(normalized);
      } else {
        next[index] = normalized;
      }
      final credentials = {...settings.credentials};
      if (changedAddress || !endpoint.isOfficial) credentials.remove(source.id);
      if (endpoint.isOfficial && (appId != null || appSecret != null)) {
        final own = DanmakuCredentials(
          appId: appId ?? credentials[source.id]?.appId ?? '',
          appSecret: appSecret ?? credentials[source.id]?.appSecret ?? '',
        );
        if (!own.isValid) throw const FormatException('credentials_required');
        credentials[source.id] = own;
      }
      return settings.copyWith(
        sources: next,
        credentials: credentials,
        memories: changedAddress ? _withoutSource(settings.memories, source.id) : null,
      );
    });
    if (changedAddress || !normalized.enabled) {
      _runtimeMemories.removeWhere((_, memory) => memory.sourceId == source.id);
      _invalidateRequests();
      if (_currentHit?.sourceId == source.id || _selectedSourceId == source.id) {
        _clearData();
        _offsetMs = 0;
        _episodeOffset = 0;
      }
      if (!normalized.enabled && _selectedSourceId == source.id) {
        _selectedSourceId = null;
        _manualSelection = false;
      }
      notifyListeners();
    }
  }

  Future<bool> hasSourceCredentials(String id) async {
    await initialize();
    return _settings.credentials[id]?.isValid ?? false;
  }

  Future<void> deleteSource(String id) async {
    await _mutate(
      (settings) => settings.copyWith(
        sources: settings.sources.where((s) => s.id != id).toList(),
        credentials: {...settings.credentials}..remove(id),
        memories: _withoutSource(settings.memories, id),
      ),
    );
    _runtimeMemories.removeWhere((_, memory) => memory.sourceId == id);
    // A search can still be in flight before there is a selected/current source.
    _invalidateRequests();
    if (_currentHit?.sourceId == id || _selectedSourceId == id) {
      _selectedSourceId = null;
      _manualSelection = false;
      _offsetMs = 0;
      _episodeOffset = 0;
      _clearData();
    }
    notifyListeners();
  }

  Future<void> reorderSources(List<String> ids) => _mutate((settings) {
    if (ids.length != settings.sources.length ||
        ids.toSet().length != ids.length ||
        ids.any((id) => !settings.sources.any((s) => s.id == id))) {
      throw const FormatException('invalid_order');
    }
    return settings.copyWith(sources: ids.map((id) => settings.sources.firstWhere((s) => s.id == id)).toList());
  });

  Future<void> selectSource(String? id) async {
    await initialize();
    if (id != null && !sources.any((s) => s.id == id && s.enabled)) throw const FormatException('source_unavailable');
    if (id == _selectedSourceId && _manualSelection == (id != null)) return;
    _selectedSourceId = id;
    _manualSelection = id != null;
    _invalidateRequests();
    _clearData();
    _offsetMs = 0;
    _episodeOffset = 0;
    notifyListeners();
  }

  Future<DanmakuConnectionResult> testSource(DanmakuSource source) async {
    await initialize();
    final clock = Stopwatch()..start();
    DanmakuApiClient? client;
    try {
      client = _clientFactory(source, _settings.credentials[source.id]);
      await client.searchAnime('test');
      return DanmakuConnectionResult(elapsed: clock.elapsed);
    } catch (failure) {
      return DanmakuConnectionResult(elapsed: clock.elapsed, error: _safeError(failure));
    } finally {
      client?.close();
    }
  }

  /// Returns an ownership token: an older route cannot clear a newer session.
  int setMediaContext(DanmakuMatchContext context) {
    _contextGeneration++;
    _context = context;
    _durationMs = context.durationMs;
    _invalidateRequests();
    _clearData();
    _selectedSourceId = null;
    _manualSelection = false;
    _offsetMs = 0;
    _episodeOffset = 0;
    _restoreMemory();
    notifyListeners();
    return _contextGeneration;
  }

  void _restoreMemory() {
    final memory = _context == null ? null : _memoryFor(_context!.memoryKey);
    if (memory == null || !sources.any((s) => s.id == memory.sourceId && s.enabled)) return;
    _selectedSourceId = memory.sourceId;
    _offsetMs = memory.offsetMs;
    _episodeOffset = memory.episodeOffset;
    _rebuildEffective();
  }

  DanmakuMatchMemory? _memoryFor(String key) => _runtimeMemories[key] ?? _settings.memories[key];

  void setDuration(int? durationMs) {
    final valid = durationMs != null && durationMs > 0 ? durationMs : null;
    if (valid == _durationMs) return;
    _durationMs = valid;
    _rebuildEffective();
    notifyListeners();
  }

  Future<List<DanmakuAnime>> search(String query, {Set<String> skipSourceIds = const {}}) async {
    final owner = _contextGeneration;
    await initialize();
    if (owner != _contextGeneration) return const [];
    final generation = ++_generation;
    loading = true;
    error = null;
    sourceFailures = const {};
    candidates = const [];
    notifyListeners();
    final failures = <String, String>{};
    final ordered = sources
        .where((s) => s.enabled && !skipSourceIds.contains(s.id) && (!_manualSelection || s.id == _selectedSourceId))
        .toList();
    for (final source in ordered) {
      final client = _clientFactory(source, _settings.credentials[source.id]);
      try {
        final results = await client.searchAnime(query);
        if (generation != _generation) return const [];
        if (results.isEmpty) {
          failures[source.id] = 'no_candidates';
          continue;
        }
        candidates = List.unmodifiable(results);
        sourceFailures = Map.unmodifiable(failures);
        loading = false;
        notifyListeners();
        return candidates;
      } catch (failure) {
        if (generation != _generation) return const [];
        failures[source.id] = _safeError(failure);
      } finally {
        client.close();
      }
    }
    if (generation != _generation) return const [];
    loading = false;
    sourceFailures = Map.unmodifiable(failures);
    error = failures.values.lastOrNull ?? 'no_sources';
    notifyListeners();
    return const [];
  }

  Future<List<DanmakuSearchHit>> episodes(DanmakuAnime anime) async {
    final owner = _contextGeneration;
    await initialize();
    if (owner != _contextGeneration) return const [];
    final generation = ++_generation;
    final source = _source(anime.sourceId);
    if (_manualSelection && anime.sourceId != _selectedSourceId) {
      throw const DanmakuApiException('source_mismatch');
    }
    _prepareSource(source.id);
    final client = _clientFactory(source, _settings.credentials[source.id]);
    loading = true;
    error = null;
    notifyListeners();
    try {
      final hits = await client.bangumi(anime);
      if (generation != _generation) return const [];
      return hits;
    } catch (failure) {
      if (generation != _generation) return const [];
      error = _safeError(failure);
      rethrow;
    } finally {
      client.close();
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// [episode] is an explicit target (typed as `第N集`) that replaces the
  /// playing episode plus offset.
  DanmakuSearchHit? suggestedEpisode(List<DanmakuSearchHit> hits, {int? episode}) {
    final index = _context?.episodeNumber;
    final target = episode ?? (index == null ? null : index + _episodeOffset);
    if (target == null) return hits.length == 1 ? hits.single : null;
    final matches = hits.where((hit) => hit.episodeNumber == target).toList();
    return matches.length == 1 ? matches.single : null;
  }

  /// An ambiguous work/episode waits for the user. Service failures may advance
  /// to the next source, whose IDs and timing preferences are matched afresh.
  Future<bool> autoMatch() async {
    final owner = _contextGeneration;
    await initialize();
    final context = _context;
    if (owner != _contextGeneration || context == null || !enabled || sources.every((s) => !s.enabled)) return false;
    final memory = _memoryFor(context.memoryKey);
    DanmakuAnime? work;
    if (memory != null &&
        sources.any((s) => s.id == memory.sourceId && s.enabled) &&
        (!_manualSelection || _selectedSourceId == memory.sourceId)) {
      work = DanmakuAnime(sourceId: memory.sourceId, animeId: memory.animeId, title: memory.animeTitle);
    }
    final skipped = <String>{};
    final failures = <String, String>{};
    while (owner == _contextGeneration) {
      if (work == null) {
        final before = _generation;
        final works = await search(context.suggestedQuery, skipSourceIds: skipped);
        if (owner != _contextGeneration || _generation != before + 1) return false;
        failures.addAll(sourceFailures);
        final confident = confidentDanmakuWork(works, context.suggestedQuery);
        if (confident == null) {
          sourceFailures = Map.unmodifiable(failures);
          notifyListeners();
          return false;
        }
        work = confident;
      }
      final sourceId = work.sourceId;
      var expectedGeneration = _generation + 1;
      try {
        final hits = await episodes(work);
        if (owner != _contextGeneration || _generation != expectedGeneration) return false;
        if (hits.isEmpty) throw const DanmakuApiException('no_candidates');
        final hit = suggestedEpisode(hits);
        if (hit == null) return false;
        expectedGeneration = _generation + 1;
        await loadEpisode(hit, remember: !_unpersistedMemories.contains(context.memoryKey));
        if (owner != _contextGeneration || _generation != expectedGeneration) return false;
        sourceFailures = Map.unmodifiable(failures);
        notifyListeners();
        return true;
      } catch (failure) {
        if (owner != _contextGeneration || _generation != expectedGeneration) return false;
        failures[sourceId] = _safeError(failure);
      }
      skipped.add(sourceId);
      if (_manualSelection) break;
      _offsetMs = 0;
      _episodeOffset = 0;
      _selectedSourceId = null;
      work = null;
      if (sources.every((source) => !source.enabled || skipped.contains(source.id))) break;
    }
    if (owner == _contextGeneration) {
      sourceFailures = Map.unmodifiable(failures);
      error = failures.values.lastOrNull ?? 'no_candidates';
      notifyListeners();
    }
    return false;
  }

  Future<void> loadEpisode(DanmakuSearchHit hit, {bool remember = true}) async {
    final owner = _contextGeneration;
    await initialize();
    if (owner != _contextGeneration) return;
    final generation = ++_generation;
    final source = _source(hit.sourceId);
    if (_manualSelection && hit.sourceId != _selectedSourceId) throw const DanmakuApiException('source_mismatch');
    _prepareSource(source.id);
    final client = _clientFactory(source, _settings.credentials[source.id]);
    _clearData();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final raw = await client.fetchCommentsRaw(hit.episodeId, withRelated: withRelated, chConvert: chConvert);
      if (generation != _generation) return;
      final parsed = DanmakuParser.parse(raw);
      final context = _context;
      DanmakuMatchMemory? memory;
      if (context != null) {
        final playingEpisode = context.episodeNumber;
        final selectedEpisode = hit.episodeNumber;
        memory = DanmakuMatchMemory(
          sourceId: source.id,
          animeId: hit.animeId,
          animeTitle: hit.animeTitle,
          episodeOffset: playingEpisode != null && selectedEpisode != null
              ? selectedEpisode - playingEpisode
              : _episodeOffset,
          offsetMs: _offsetMs,
        );
        if (remember) {
          await _mutate((settings) {
            if (generation != _generation || owner != _contextGeneration) return settings;
            return settings.copyWith(memories: {...settings.memories, context.memoryKey: memory!});
          });
        }
      }
      if (generation != _generation || owner != _contextGeneration) return;
      if (context != null && memory != null) {
        _runtimeMemories[context.memoryKey] = memory;
        if (remember) {
          _unpersistedMemories.remove(context.memoryKey);
        } else {
          _unpersistedMemories.add(context.memoryKey);
        }
        _episodeOffset = memory.episodeOffset;
      }
      _currentHit = hit;
      _selectedSourceId = hit.sourceId;
      _rawComments = List.unmodifiable(parsed);
      sourceLabel = '${source.name} · ${hit.label}';
      _rebuildEffective();
    } catch (failure) {
      if (generation != _generation) return;
      error = _safeError(failure);
      rethrow;
    } finally {
      client.close();
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setEpisodeOffset(int value) async {
    final owner = _contextGeneration;
    await _mutate(
      (settings) => settings.copyWith(
        memories: owner == _contextGeneration ? _updatedMemory(settings, episodeOffset: value) : settings.memories,
      ),
    );
    if (owner != _contextGeneration) return;
    _episodeOffset = value;
    _commitRuntimeOffsets();
    _invalidateRequests();
    _clearData();
    notifyListeners();
  }

  void _commitRuntimeOffsets() {
    final context = _context;
    if (context == null) return;
    final memory = _memoryFor(context.memoryKey);
    if (memory == null || memory.sourceId != _selectedSourceId) return;
    _runtimeMemories[context.memoryKey] = DanmakuMatchMemory(
      sourceId: memory.sourceId,
      animeId: memory.animeId,
      animeTitle: memory.animeTitle,
      episodeOffset: _episodeOffset,
      offsetMs: _offsetMs,
    );
  }

  Map<String, DanmakuMatchMemory> _updatedMemory(DanmakuSettings settings, {int? offsetMs, int? episodeOffset}) {
    final context = _context;
    if (context == null) return settings.memories;
    final saved = _runtimeMemories[context.memoryKey] ?? settings.memories[context.memoryKey];
    final previous = saved?.sourceId == _selectedSourceId ? saved : null;
    final hit = _currentHit;
    if (previous == null && hit == null) return settings.memories;
    final memory = DanmakuMatchMemory(
      sourceId: hit?.sourceId ?? previous!.sourceId,
      animeId: hit?.animeId ?? previous!.animeId,
      animeTitle: hit?.animeTitle ?? previous!.animeTitle,
      episodeOffset: episodeOffset ?? _episodeOffset,
      offsetMs: offsetMs ?? _offsetMs,
    );
    // This runs before the persistent write succeeds. Runtime edits are
    // committed by their callers, so a failed write retains the prior mapping.
    if (_unpersistedMemories.contains(context.memoryKey)) return settings.memories;
    return {...settings.memories, context.memoryKey: memory};
  }

  /// Local import shares the effective-time pipeline and cancels online loads.
  void load(List<DanmakuComment> next, {required String sourceLabel}) {
    _invalidateRequests();
    _currentHit = null;
    _rawComments = List.unmodifiable([...next]..sort((a, b) => a.timeMs.compareTo(b.timeMs)));
    this.sourceLabel = sourceLabel;
    _rebuildEffective();
    notifyListeners();
  }

  void clear({int? ownerGeneration}) {
    if (ownerGeneration != null && ownerGeneration != _contextGeneration) return;
    _contextGeneration++;
    _context = null;
    _durationMs = null;
    _offsetMs = 0;
    _episodeOffset = 0;
    _selectedSourceId = null;
    _manualSelection = false;
    _invalidateRequests();
    _clearData();
    notifyListeners();
  }

  void _invalidateRequests() {
    _generation++;
    loading = false;
    candidates = const [];
    error = null;
  }

  void _clearData() {
    _rawComments = const [];
    _comments = const [];
    _currentHit = null;
    sourceLabel = null;
    dataVersion++;
  }

  void _prepareSource(String id) {
    if (_selectedSourceId != null && _selectedSourceId != id) {
      _offsetMs = 0;
      _episodeOffset = 0;
      _clearData();
    }
    _selectedSourceId = id;
  }

  void _rebuildEffective() {
    _comments = List.unmodifiable(
      filterDanmaku(
            _rawComments,
            blockedKeywords: _settings.blockedKeywords,
            mergeDuplicates: _settings.mergeDuplicates,
          )
          .map(
            (comment) => DanmakuComment(
              timeMs: comment.timeMs + _offsetMs,
              text: comment.text,
              color: comment.color,
              mode: comment.mode,
            ),
          )
          .where(
            (comment) =>
                comment.timeMs >= 0 && (_durationMs == null || _durationMs! <= 0 || comment.timeMs < _durationMs!),
          ),
    );
    dataVersion++;
  }

  DanmakuSource _source(String id) => sources.firstWhere(
    (s) => s.id == id && s.enabled,
    orElse: () => throw const DanmakuApiException('source_unavailable'),
  );
  static Map<String, DanmakuMatchMemory> _withoutSource(Map<String, DanmakuMatchMemory> memories, String id) =>
      Map.fromEntries(memories.entries.where((entry) => entry.value.sourceId != id));
  static String _safeError(Object failure) => failure is DanmakuApiException ? failure.toString() : 'operation_failed';
}
