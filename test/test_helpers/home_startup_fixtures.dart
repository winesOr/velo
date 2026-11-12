import 'dart:async';

import 'package:plezy/media/ids.dart';
import 'package:plezy/media/library_change_event.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_library.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/media/server_capabilities.dart';
import 'package:plezy/utils/active_client_scope.dart';

class HomeStartupClient implements MediaServerClient, ScopedMediaServerClient {
  HomeStartupClient(String id, {this.profileId = 'profile-a'}) : serverId = ServerId(id);
  @override
  final ServerId serverId;
  String profileId;
  @override
  String get scopedServerId => PlexProfileScopeId(serverId: serverId, profileId: profileId);
  @override
  Object authenticationSessionId = Object();
  @override
  String get serverName => serverId;
  @override
  MediaBackend get backend => MediaBackend.plex;
  @override
  ServerCapabilities get capabilities => ServerCapabilities.plex;

  Completer<void>? librariesGate;
  Completer<void>? onDeckGate;
  Completer<void>? hubsGate;
  Completer<void>? onDeckStarted;
  Completer<void>? hubsStarted;
  List<MediaItem> onDeck = [];
  List<MediaHub> hubs = [];
  Object? failure;
  int onDeckCalls = 0;
  int hubCalls = 0;
  int libraryCalls = 0;

  @override
  Future<List<MediaLibrary>> fetchLibraries() async {
    libraryCalls++;
    await librariesGate?.future;
    if (failure != null) throw failure!;
    return const [];
  }

  @override
  Future<List<MediaItem>> fetchContinueWatching({int? count = 20, Set<String> excludedLibraryIds = const {}}) async {
    onDeckCalls++;
    if (onDeckStarted case final started? when !started.isCompleted) started.complete();
    await onDeckGate?.future;
    if (failure != null) throw failure!;
    return onDeck;
  }

  @override
  Future<List<MediaHub>> fetchGlobalHubs({
    int limit = defaultHubPreviewLimit,
    bool includePlaybackHubs = true,
    HubFetchDiagnostics? diagnostics,
  }) async {
    hubCalls++;
    if (hubsStarted case final started? when !started.isCompleted) started.complete();
    await hubsGate?.future;
    if (failure != null) throw failure!;
    return hubs;
  }

  @override
  LibraryEventChannel createLibraryEventChannel() => _NoHomeEvents();
  @override
  void close() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoHomeEvents implements LibraryEventChannel {
  @override
  Stream<LibraryChangeEvent> get events => const Stream.empty();
  @override
  void start() {}
  @override
  void stop() {}
  @override
  void dispose() {}
}
