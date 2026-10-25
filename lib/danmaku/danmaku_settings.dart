import 'dart:convert';

import 'danmaku_source.dart';

class DanmakuMatchContext {
  final String profileId;
  final String serverId;
  final String itemId;
  final String title;
  final String? seriesId;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? durationMs;

  const DanmakuMatchContext({
    required this.profileId,
    required this.serverId,
    required this.itemId,
    required this.title,
    this.seriesId,
    this.seasonNumber,
    this.episodeNumber,
    this.durationMs,
  });

  String get memoryKey => jsonEncode([
    profileId,
    serverId,
    seriesId == null ? 'item' : 'series',
    seriesId ?? itemId,
    seriesId == null ? null : seasonNumber,
  ]);
  String get identity => jsonEncode([profileId, serverId, itemId]);
  String get suggestedQuery => seasonNumber == null ? title : '$title 第$seasonNumber季';
}

class DanmakuMatchMemory {
  final String sourceId;
  final String animeId;
  final String animeTitle;
  final int episodeOffset;
  final int offsetMs;
  const DanmakuMatchMemory({
    required this.sourceId,
    required this.animeId,
    required this.animeTitle,
    this.episodeOffset = 0,
    this.offsetMs = 0,
  });
  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'animeId': animeId,
    'animeTitle': animeTitle,
    'episodeOffset': episodeOffset,
    'offsetMs': offsetMs,
  };
  factory DanmakuMatchMemory.fromJson(Map<String, dynamic> json) => DanmakuMatchMemory(
    sourceId: json['sourceId'] as String,
    animeId: json['animeId'] as String,
    animeTitle: json['animeTitle'] as String? ?? '',
    episodeOffset: json['episodeOffset'] as int? ?? 0,
    offsetMs: json['offsetMs'] as int? ?? 0,
  );
}

class DanmakuSettings {
  static const version = 1;
  final bool enabled;
  final bool heatmapEnabled;
  final double fontSize;
  final double opacity;
  final double speed;
  final int maxOnScreen;
  final int scrollLines;
  final int topLines;
  final int bottomLines;
  final bool preventOverlap;
  final bool mergeDuplicates;
  final List<String> blockedKeywords;
  final bool withRelated;
  final int chConvert;
  final List<DanmakuSource> sources;
  final Map<String, DanmakuCredentials> credentials;
  final Map<String, DanmakuMatchMemory> memories;

  const DanmakuSettings({
    this.enabled = true,
    this.heatmapEnabled = true,
    this.fontSize = 18,
    this.opacity = 0.85,
    this.speed = 1,
    this.maxOnScreen = 60,
    this.scrollLines = 12,
    this.topLines = 3,
    this.bottomLines = 3,
    this.preventOverlap = true,
    this.mergeDuplicates = false,
    this.blockedKeywords = const [],
    this.withRelated = true,
    this.chConvert = 0,
    this.sources = const [],
    this.credentials = const {},
    this.memories = const {},
  });

  DanmakuSettings copyWith({
    bool? enabled,
    bool? heatmapEnabled,
    double? fontSize,
    double? opacity,
    double? speed,
    int? maxOnScreen,
    int? scrollLines,
    int? topLines,
    int? bottomLines,
    bool? preventOverlap,
    bool? mergeDuplicates,
    List<String>? blockedKeywords,
    bool? withRelated,
    int? chConvert,
    List<DanmakuSource>? sources,
    Map<String, DanmakuCredentials>? credentials,
    Map<String, DanmakuMatchMemory>? memories,
  }) => DanmakuSettings(
    enabled: enabled ?? this.enabled,
    heatmapEnabled: heatmapEnabled ?? this.heatmapEnabled,
    fontSize: fontSize ?? this.fontSize,
    opacity: opacity ?? this.opacity,
    speed: speed ?? this.speed,
    maxOnScreen: maxOnScreen ?? this.maxOnScreen,
    scrollLines: scrollLines ?? this.scrollLines,
    topLines: topLines ?? this.topLines,
    bottomLines: bottomLines ?? this.bottomLines,
    preventOverlap: preventOverlap ?? this.preventOverlap,
    mergeDuplicates: mergeDuplicates ?? this.mergeDuplicates,
    blockedKeywords: List.unmodifiable(blockedKeywords ?? this.blockedKeywords),
    withRelated: withRelated ?? this.withRelated,
    chConvert: chConvert ?? this.chConvert,
    sources: List.unmodifiable(sources ?? this.sources),
    credentials: Map.unmodifiable(credentials ?? this.credentials),
    memories: Map.unmodifiable(memories ?? this.memories),
  );

  Map<String, Object?> toJson() => {
    'version': version,
    'enabled': enabled,
    'heatmapEnabled': heatmapEnabled,
    'fontSize': fontSize,
    'opacity': opacity,
    'speed': speed,
    'maxOnScreen': maxOnScreen,
    'scrollLines': scrollLines,
    'topLines': topLines,
    'bottomLines': bottomLines,
    'preventOverlap': preventOverlap,
    'mergeDuplicates': mergeDuplicates,
    'blockedKeywords': blockedKeywords,
    'withRelated': withRelated,
    'chConvert': chConvert,
    'sources': sources.map((s) => s.toJson()).toList(),
    'credentials': credentials.map((k, v) => MapEntry(k, v.toJson())),
    'memories': memories.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory DanmakuSettings.fromJson(Map<String, dynamic> json) {
    if (json['version'] != version) throw const FormatException('invalid_settings_version');
    final sources = (json['sources'] as List)
        .map((v) => DanmakuSource.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    if (sources.map((s) => s.id).toSet().length != sources.length) throw const FormatException('duplicate_source');
    final fontSize = (json['fontSize'] as num? ?? 18).toDouble();
    final opacity = (json['opacity'] as num? ?? 0.85).toDouble();
    final chConvert = json['chConvert'] as int? ?? 0;
    final speed = (json['speed'] as num? ?? 1).toDouble();
    final maxOnScreen = json['maxOnScreen'] as int? ?? 60;
    final scrollLines = json['scrollLines'] as int? ?? 12;
    final topLines = json['topLines'] as int? ?? 3;
    final bottomLines = json['bottomLines'] as int? ?? 3;
    final keywords = (json['blockedKeywords'] as List? ?? const []).cast<String>();
    if (!speed.isFinite ||
        speed < 0.25 ||
        speed > 3 ||
        maxOnScreen < 1 ||
        maxOnScreen > 200 ||
        [scrollLines, topLines, bottomLines].any((value) => value < 0 || value > 30) ||
        keywords.length > 100 ||
        keywords.any((value) => value.trim().isEmpty || value.length > 200)) {
      throw const FormatException('invalid_presentation');
    }
    if (!fontSize.isFinite ||
        fontSize < 8 ||
        fontSize > 64 ||
        !opacity.isFinite ||
        opacity < 0 ||
        opacity > 1 ||
        chConvert < 0 ||
        chConvert > 2) {
      throw const FormatException('invalid_settings');
    }
    return DanmakuSettings(
      enabled: json['enabled'] as bool? ?? true,
      heatmapEnabled: json['heatmapEnabled'] as bool? ?? true,
      fontSize: fontSize,
      opacity: opacity,
      speed: speed,
      maxOnScreen: maxOnScreen,
      scrollLines: scrollLines,
      topLines: topLines,
      bottomLines: bottomLines,
      preventOverlap: json['preventOverlap'] as bool? ?? true,
      mergeDuplicates: json['mergeDuplicates'] as bool? ?? false,
      blockedKeywords: List.unmodifiable(keywords),
      withRelated: json['withRelated'] as bool? ?? true,
      chConvert: chConvert,
      sources: List.unmodifiable(sources),
      credentials: Map.unmodifiable(
        (json['credentials'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, DanmakuCredentials.fromJson(Map<String, dynamic>.from(v as Map))),
        ),
      ),
      memories: Map.unmodifiable(
        (json['memories'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, DanmakuMatchMemory.fromJson(Map<String, dynamic>.from(v as Map))),
        ),
      ),
    );
  }
}
