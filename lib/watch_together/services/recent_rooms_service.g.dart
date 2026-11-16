// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_rooms_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecentRoom _$RecentRoomFromJson(Map<String, dynamic> json) => RecentRoom(
  code: json['code'] as String,
  relayScope: json['relayScope'] as String,
  name: json['name'] as String?,
  lastUsed: _dateTimeFromMillis((json['lastUsed'] as num).toInt()),
  controlMode: _controlModeFromIndex((json['controlMode'] as num?)?.toInt()),
  lastMediaTitle: json['lastMediaTitle'] as String?,
  lastEpisodeLabel: json['lastEpisodeLabel'] as String?,
  lastMemberCount: (json['lastMemberCount'] as num?)?.toInt(),
  lastMemberInitials: (json['lastMemberInitials'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  lastSeenAt: _nullableDateTimeFromMillis(
    (json['lastSeenAt'] as num?)?.toInt(),
  ),
);

Map<String, dynamic> _$RecentRoomToJson(RecentRoom instance) =>
    <String, dynamic>{
      'code': instance.code,
      'relayScope': instance.relayScope,
      'name': ?instance.name,
      'lastUsed': _dateTimeToMillis(instance.lastUsed),
      'controlMode': ?_controlModeToIndex(instance.controlMode),
      'lastMediaTitle': ?instance.lastMediaTitle,
      'lastEpisodeLabel': ?instance.lastEpisodeLabel,
      'lastMemberCount': ?instance.lastMemberCount,
      'lastMemberInitials': ?instance.lastMemberInitials,
      'lastSeenAt': ?_nullableDateTimeToMillis(instance.lastSeenAt),
    };
