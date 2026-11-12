import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/services/data_aggregation_service.dart';
import 'package:plezy/services/multi_server_manager.dart';

import '../test_helpers/home_startup_fixtures.dart';
import '../test_helpers/media_items.dart';

void main() {
  test('fast server hubs publish before the slow server library prefetch finishes', () async {
    final fast = HomeStartupClient('fast')
      ..hubs = [
        MediaHub(
          id: 'fast-hub',
          title: 'Fast',
          type: 'movie',
          items: [testMediaItem(id: 'fast', serverId: 'fast')],
        ),
      ];
    final slow = HomeStartupClient('slow')..librariesGate = Completer<void>();
    final manager = MultiServerManager()
      ..debugRegisterClientForTesting(fast)
      ..debugRegisterClientForTesting(slow);
    final aggregation = DataAggregationService(manager);
    final first = Completer<HubAggregationResult>();
    final pending = aggregation.getHubsProgressively(
      onProgress: (result) {
        if (!first.isCompleted && result.hubs.isNotEmpty) first.complete(result);
      },
    );
    final partial = await first.future;
    expect(partial.hubs.single.id, 'fast-hub');
    expect(partial.succeededServerIds, {'fast'});
    expect(slow.hubCalls, 0);
    expect(fast.libraryCalls, 1);
    expect(fast.hubCalls, 1);
    slow.librariesGate!.complete();
    final result = await pending;
    expect(result.succeededServerIds, {'fast', 'slow'});
    expect(fast.hubCalls, 1, reason: 'late servers do not refetch the fast leg');
  });

  test('on-deck partial result survives a failed slow server with accurate failure ids', () async {
    final fast = HomeStartupClient('fast')..onDeck = [testMediaItem(id: 'fast', title: 'Fast', serverId: 'fast')];
    final slow = HomeStartupClient('slow')
      ..onDeckGate = Completer<void>()
      ..failure = StateError('offline');
    final manager = MultiServerManager()
      ..debugRegisterClientForTesting(fast)
      ..debugRegisterClientForTesting(slow);
    final first = Completer<OnDeckAggregationResult>();
    final pending = DataAggregationService(manager).getOnDeckProgressively(
      onProgress: (result) {
        if (!first.isCompleted && result.items.isNotEmpty) first.complete(result);
      },
    );
    expect((await first.future).items.single.id, 'fast');
    slow.onDeckGate!.complete();
    final result = await pending;
    expect(result.items.single.id, 'fast');
    expect(result.failedServerIds, {'slow'});
    expect(result.succeededServerIds, {'fast'});
    expect(fast.onDeckCalls, 1);
  });

  test('progressive cumulative merge deduplicates overlapping scoped rows', () async {
    final first = testMediaItem(id: 'shared', title: 'First', serverId: 'server-1');
    final second = testMediaItem(id: 'shared', title: 'Second', serverId: 'server-2');
    final manager = MultiServerManager()
      ..debugRegisterClientForTesting(HomeStartupClient('server-1'))
      ..debugRegisterClientForTesting(HomeStartupClient('server-2'));
    final aggregation = _OverlappingAggregationService(
      manager,
      items: [first, second],
      hubs: [
        MediaHub(id: 'same-hub', title: 'First', type: 'movie', serverId: 'server-1', items: [first]),
        MediaHub(id: 'same-hub', title: 'Second', type: 'movie', serverId: 'server-2', items: [second]),
      ],
    );

    final onDeck = await aggregation.getOnDeckProgressively(onProgress: (_) {});
    expect(onDeck.items.map((item) => item.globalKey).toSet(), {first.globalKey, second.globalKey});
    expect(onDeck.items, hasLength(2));

    final hubs = await aggregation.getHubsProgressively(onProgress: (_) {});
    expect(hubs.hubs.map((hub) => '${hub.serverId}:${hub.id}').toSet(), {'server-1:same-hub', 'server-2:same-hub'});
    expect(hubs.hubs, hasLength(2));
  });
}

class _OverlappingAggregationService extends DataAggregationService {
  _OverlappingAggregationService(super.manager, {required this.items, required this.hubs});

  final List<MediaItem> items;
  final List<MediaHub> hubs;

  @override
  Future<OnDeckAggregationResult> getOnDeckFromAllServers({
    int? limit,
    Set<String>? hiddenLibraryKeys,
    Set<String>? serverIds,
  }) async {
    return (
      items: items,
      observedItems: [for (final item in items) (item: item, clientScope: item.serverId)],
      succeededServerIds: serverIds ?? const <String>{},
      cancelledServerIds: const <String>{},
      failedServerIds: const <String>{},
    );
  }

  @override
  Future<HubAggregationResult> getHubsFromAllServers({
    int? limit,
    Set<String>? hiddenLibraryKeys,
    bool useGlobalHubs = true,
    bool includePlaybackHubs = true,
    Set<String>? serverIds,
  }) async {
    return (
      hubs: hubs,
      observedItems: [
        for (final hub in hubs)
          for (final item in hub.items) (item: item, clientScope: item.serverId),
      ],
      succeededServerIds: serverIds ?? const <String>{},
      cancelledServerIds: const <String>{},
      failedServerIds: const <String>{},
    );
  }
}
