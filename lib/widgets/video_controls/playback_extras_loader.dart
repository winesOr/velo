import '../../database/app_database.dart';
import '../../media/ids.dart';
import '../../media/media_item.dart';
import '../../media/media_kind.dart';
import '../../media/media_server_client.dart';
import '../../media/media_source_info.dart';
import '../../media/skip_marker_resolver.dart';
import '../../services/aniskip_client.dart';
import '../../services/aniskip_identity.dart';
import '../../services/cached_playback_metadata_service.dart';
import '../../services/settings_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/global_key_utils.dart';

class VideoControlsPlaybackExtrasLoader {
  final MediaItem metadata;
  final MediaServerClient? client;
  final AppDatabase database;

  const VideoControlsPlaybackExtrasLoader({required this.metadata, required this.database, required this.client});

  /// Session-wide singletons: the response cache and the identity session
  /// cache only pay off when they outlive one playback.
  static final AniSkipClient _aniskipClient = AniSkipClient();
  static final AniSkipIdentityResolver _aniskipResolver = AniSkipIdentityResolver();

  Future<PlaybackExtras?> load({bool forceRefresh = false}) async {
    final settings = await SettingsService.getInstance();
    // Started before the server round trip so the two sources resolve in
    // parallel; AniSkip never throws and never blocks longer than its
    // internal timeout.
    final aniskipFuture = _fetchAniSkipMarkers(settings);

    PlaybackExtras? extras;
    if (client == null) {
      extras = await _loadFromCacheOnly(cacheServerId: await _resolveCacheServerId());
    } else {
      try {
        appLogger.d('_loadPlaybackExtras: starting for ${metadata.id} (forceRefresh=$forceRefresh)');
        final result = await client!.fetchPlaybackExtras(
          metadata.id,
          introPattern: settings.read(SettingsService.introPattern),
          creditsPattern: settings.read(SettingsService.creditsPattern),
          forceChapterFallback: settings.read(SettingsService.forceSkipMarkerFallback),
          forceRefresh: forceRefresh,
        );
        appLogger.d('_loadPlaybackExtras: got ${_describe(result)}');
        extras = result;
      } catch (e, stack) {
        appLogger.d('_loadPlaybackExtras: network path failed, trying cache fallback');
        try {
          extras = await client!.fetchPlaybackExtrasFromCacheOnly(
            metadata.id,
            introPattern: settings.read(SettingsService.introPattern),
            creditsPattern: settings.read(SettingsService.creditsPattern),
            forceChapterFallback: settings.read(SettingsService.forceSkipMarkerFallback),
          );
          if (extras != null) {
            appLogger.d('_loadPlaybackExtras: loaded ${_describe(extras)} from cache');
          }
        } catch (cacheError) {
          appLogger.d('_loadPlaybackExtras: cache fallback failed', error: cacheError);
        }
        if (extras == null) {
          appLogger.e('_loadPlaybackExtras failed', error: e, stackTrace: stack);
        }
      }
    }

    return _mergeFallbackMarkers(extras, await aniskipFuture, settings);
  }

  /// Overlays the two marker fallbacks on the server extras: per type, the
  /// server markers win over AniSkip, which wins over the user's custom
  /// skip-seconds (docs/skip-intro-outro-plan.md §5). Keeps `null` when the
  /// server produced nothing and neither fallback contributed a marker.
  PlaybackExtras? _mergeFallbackMarkers(
    PlaybackExtras? extras,
    List<MediaMarker> aniskipMarkers,
    SettingsService settings,
  ) {
    final merged = resolveSkipMarkers(
      serverMarkers: extras?.markers ?? const [],
      aniskipMarkers: aniskipMarkers,
      customIntroSeconds: settings.read(SettingsService.customSkipIntroSeconds),
      customEndSeconds: settings.read(SettingsService.customSkipEndSeconds),
      durationMs: metadata.durationMs,
    );
    if (extras == null) {
      return merged.isEmpty ? null : PlaybackExtras(chapters: const [], markers: merged);
    }
    if (identical(merged, extras.markers)) return extras;
    return PlaybackExtras(chapters: extras.chapters, markers: merged);
  }

  Future<List<MediaMarker>> _fetchAniSkipMarkers(SettingsService settings) async {
    if (!settings.read(SettingsService.aniskipEnabled)) return const [];
    if (metadata.kind != MediaKind.episode) return const [];
    final episode = metadata.index;
    final durationMs = metadata.durationMs;
    final seriesKey = metadata.seriesGlobalKey;
    final title = metadata.grandparentTitle;
    if (episode == null || durationMs == null || durationMs <= 0 || seriesKey == null || title == null) {
      return const [];
    }
    try {
      final malId = await _aniskipResolver.resolveMalId(seriesKey: seriesKey, title: title);
      if (malId == null) return const [];
      return await _aniskipClient.fetchSkipTimes(
        malId: malId,
        episodeNumber: episode,
        episodeLengthSeconds: durationMs / 1000,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<PlaybackExtras?> _loadFromCacheOnly({required String? cacheServerId}) async {
    if (cacheServerId == null) {
      appLogger.w('_loadPlaybackExtras: no client or cache scope for server ${metadata.serverId}');
      return null;
    }
    try {
      final settings = await SettingsService.getInstance();
      final extras = await CachedPlaybackMetadataService.fetchPlaybackExtras(
        backend: metadata.backend,
        cacheServerId: cacheServerId,
        itemId: metadata.id,
        introPattern: settings.read(SettingsService.introPattern),
        creditsPattern: settings.read(SettingsService.creditsPattern),
        forceChapterFallback: settings.read(SettingsService.forceSkipMarkerFallback),
      );
      appLogger.d(
        extras == null
            ? '_loadPlaybackExtras: no cached extras for ${metadata.id}'
            : '_loadPlaybackExtras: cache-only ${_describe(extras)}',
      );
      return extras;
    } catch (e) {
      appLogger.d('_loadPlaybackExtras: cache-only path failed', error: e);
      return null;
    }
  }

  /// Marker counts are the difference between "the server has no intro data"
  /// and "auto-skip never fired", which is otherwise indistinguishable in a
  /// user-supplied log.
  static String _describe(PlaybackExtras extras) {
    final markerTypes = extras.markers.map((m) => m.type).join(',');
    return '${extras.chapters.length} chapters, ${extras.markers.length} markers'
        '${markerTypes.isEmpty ? '' : ' ($markerTypes)'}';
  }

  Future<String?> _resolveCacheServerId() async {
    final serverId = metadata.serverId;
    if (serverId == null) return null;
    try {
      final row = await (database.select(
        database.downloadedMedia,
      )..where((tbl) => tbl.globalKey.equals(buildGlobalKey(ServerId(serverId), metadata.id)))).getSingleOrNull();
      return row?.clientScopeId ?? serverId;
    } catch (_) {
      return serverId;
    }
  }
}
