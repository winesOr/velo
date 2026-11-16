import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../services/settings_service.dart';
import '../models/watch_session.dart';
import 'watch_together_relay_endpoint.dart';

part 'recent_rooms_service.g.dart';

@JsonSerializable(includeIfNull: false)
class RecentRoom {
  final String code;
  final String relayScope;
  final String? name;
  @JsonKey(fromJson: _dateTimeFromMillis, toJson: _dateTimeToMillis)
  final DateTime lastUsed;
  @JsonKey(fromJson: _controlModeFromIndex, toJson: _controlModeToIndex)
  final ControlMode? controlMode;
  final String? lastMediaTitle;
  final String? lastEpisodeLabel;
  final int? lastMemberCount;
  final List<String>? lastMemberInitials;
  @JsonKey(fromJson: _nullableDateTimeFromMillis, toJson: _nullableDateTimeToMillis)
  final DateTime? lastSeenAt;

  const RecentRoom({
    required this.code,
    required this.relayScope,
    this.name,
    required this.lastUsed,
    this.controlMode,
    this.lastMediaTitle,
    this.lastEpisodeLabel,
    this.lastMemberCount,
    this.lastMemberInitials,
    this.lastSeenAt,
  });

  Map<String, dynamic> toJson() => _$RecentRoomToJson(this);

  factory RecentRoom.fromJson(Map<String, dynamic> json) => _$RecentRoomFromJson(json);

  RecentRoom copyWith({
    String? code,
    String? relayScope,
    String? name,
    DateTime? lastUsed,
    ControlMode? controlMode,
    String? lastMediaTitle,
    String? lastEpisodeLabel,
    int? lastMemberCount,
    List<String>? lastMemberInitials,
    DateTime? lastSeenAt,
    bool replaceMedia = false,
    bool clearName = false,
  }) => RecentRoom(
    code: code ?? this.code,
    relayScope: relayScope ?? this.relayScope,
    name: clearName ? null : (name ?? this.name),
    lastUsed: lastUsed ?? this.lastUsed,
    controlMode: controlMode ?? this.controlMode,
    lastMediaTitle: replaceMedia ? lastMediaTitle : (lastMediaTitle ?? this.lastMediaTitle),
    lastEpisodeLabel: replaceMedia ? lastEpisodeLabel : (lastEpisodeLabel ?? this.lastEpisodeLabel),
    lastMemberCount: lastMemberCount ?? this.lastMemberCount,
    lastMemberInitials: (lastMemberInitials ?? this.lastMemberInitials)?.take(3).toList(growable: false),
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
}

DateTime _dateTimeFromMillis(int value) => DateTime.fromMillisecondsSinceEpoch(value);

int _dateTimeToMillis(DateTime value) => value.millisecondsSinceEpoch;

DateTime? _nullableDateTimeFromMillis(int? value) => value == null ? null : _dateTimeFromMillis(value);

int? _nullableDateTimeToMillis(DateTime? value) => value?.millisecondsSinceEpoch;

ControlMode? _controlModeFromIndex(int? index) {
  if (index == null || index < 0 || index >= ControlMode.values.length) return null;
  return ControlMode.values[index];
}

int? _controlModeToIndex(ControlMode? value) => value?.index;

class RecentRoomsService {
  static const int _maxRooms = 20;

  static List<RecentRoom> getRecentRooms({required String profileId, required WatchTogetherRelayEndpoint endpoint}) {
    final scope = _scopeFor(endpoint);
    return _load(profileId).where((room) => room.relayScope == scope).toList(growable: false);
  }

  static List<RecentRoom> _load(String profileId) {
    final settings = SettingsService.instanceOrNull;
    if (settings == null) return [];
    final json = settings.read(SettingsService.recentRoomsForProfile(profileId));
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      final rooms = list.map((entry) => RecentRoom.fromJson(entry as Map<String, dynamic>)).toList();
      rooms.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      return rooms;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(String profileId, List<RecentRoom> rooms) async {
    rooms.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    if (rooms.length > _maxRooms) {
      rooms.removeRange(_maxRooms, rooms.length);
    }
    await SettingsService.instanceOrNull?.write(
      SettingsService.recentRoomsForProfile(profileId),
      jsonEncode(rooms.map((room) => room.toJson()).toList()),
    );
  }

  static Future<void> addOrUpdateRoom(
    String code, {
    required String profileId,
    required WatchTogetherRelayEndpoint endpoint,
    String? name,
    ControlMode? controlMode,
    String? lastMediaTitle,
    String? lastEpisodeLabel,
    int? lastMemberCount,
    List<String>? lastMemberInitials,
    DateTime? lastSeenAt,
    bool replaceMedia = false,
  }) async {
    final scope = _scopeFor(endpoint);
    final rooms = _load(profileId);
    final index = rooms.indexWhere((room) => room.relayScope == scope && room.code == code);
    if (index >= 0) {
      rooms[index] = rooms[index].copyWith(
        lastUsed: DateTime.now(),
        name: name ?? rooms[index].name,
        controlMode: controlMode,
        lastMediaTitle: lastMediaTitle,
        lastEpisodeLabel: lastEpisodeLabel,
        lastMemberCount: lastMemberCount,
        lastMemberInitials: lastMemberInitials,
        lastSeenAt: lastSeenAt,
        replaceMedia: replaceMedia,
      );
    } else {
      rooms.add(
        RecentRoom(
          code: code,
          relayScope: scope,
          name: name,
          lastUsed: DateTime.now(),
          controlMode: controlMode,
          lastMediaTitle: lastMediaTitle,
          lastEpisodeLabel: lastEpisodeLabel,
          lastMemberCount: lastMemberCount,
          lastMemberInitials: lastMemberInitials?.take(3).toList(growable: false),
          lastSeenAt: lastSeenAt,
        ),
      );
    }
    await _save(profileId, rooms);
  }

  static Future<void> removeRoom(
    String code, {
    required String profileId,
    required WatchTogetherRelayEndpoint endpoint,
  }) async {
    final scope = _scopeFor(endpoint);
    final rooms = _load(profileId)..removeWhere((room) => room.relayScope == scope && room.code == code);
    await _save(profileId, rooms);
  }

  static Future<void> renameRoom(
    String code,
    String? name, {
    required String profileId,
    required WatchTogetherRelayEndpoint endpoint,
  }) async {
    final scope = _scopeFor(endpoint);
    final rooms = _load(profileId);
    final index = rooms.indexWhere((room) => room.relayScope == scope && room.code == code);
    if (index >= 0) {
      rooms[index] = rooms[index].copyWith(name: name, clearName: name == null);
      await _save(profileId, rooms);
    }
  }

  @visibleForTesting
  static String relayScopeFor(WatchTogetherRelayEndpoint endpoint) => _scopeFor(endpoint);

  static String _scopeFor(WatchTogetherRelayEndpoint endpoint) =>
      sha256.convert(utf8.encode(endpoint.canonicalBaseUrl)).toString();
}
