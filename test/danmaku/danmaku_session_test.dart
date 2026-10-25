import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plezy/danmaku/danmaku_api_client.dart';
import 'package:plezy/danmaku/danmaku_comment.dart';
import 'package:plezy/danmaku/danmaku_session.dart';
import 'package:plezy/danmaku/danmaku_settings.dart';
import 'package:plezy/danmaku/danmaku_settings_repository.dart';
import 'package:plezy/danmaku/danmaku_source.dart';
import 'package:plezy/services/credential_vault.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/services/sensitive_prefs.dart';

import '../test_helpers/prefs.dart';

const sourceA = DanmakuSource(id: 'a', name: 'A', baseUrl: 'https://a.example/private-token');
const sourceB = DanmakuSource(id: 'b', name: 'B', baseUrl: 'https://b.example');
const hitA = DanmakuSearchHit(
  sourceId: 'a',
  animeId: '4',
  episodeId: '41',
  animeTitle: 'Title',
  episodeTitle: 'First',
  episodeNumber: 1,
);

DanmakuMatchContext context({
  String server = 's',
  String item = 'i',
  String profile = 'p',
  String? series = 'series',
  int season = 1,
  int episode = 1,
}) => DanmakuMatchContext(
  profileId: profile,
  serverId: server,
  itemId: item,
  title: 'Title',
  seriesId: series,
  seasonNumber: season,
  episodeNumber: episode,
  durationMs: 20000,
);

class MemoryStore {
  String? value;
  bool fail = false;
  DanmakuSettingsRepository repository() => DanmakuSettingsRepository(
    read: () async => value,
    write: (next) async {
      if (fail) throw StateError('disk');
      value = next;
    },
    protect: (value) async => value,
    reveal: (value) async => value,
  );
}

DanmakuApiClient fixtureClient(DanmakuSource source, DanmakuCredentials? credentials) => DanmakuApiClient(
  baseUrl: source.baseUrl,
  sourceId: source.id,
  credentials: credentials,
  httpClient: MockClient((request) async {
    if (request.url.path.endsWith('search/anime')) {
      return http.Response('{"animes":[{"animeId":4,"animeTitle":"Title"}]}', 200);
    }
    if (request.url.path.endsWith('bangumi/4')) {
      return http.Response(
        '{"bangumi":{"episodes":[{"episodeId":41,"episodeNumber":"1","episodeTitle":"First"},{"episodeId":42,"episodeNumber":"2","episodeTitle":"Second"}]}}',
        200,
      );
    }
    return http.Response('{"comments":[{"p":"10,1,16777215,0","m":"hello"}]}', 200);
  }),
);

void main() {
  test('empty initialization makes no network requests and local import works', () async {
    var calls = 0;
    final session = DanmakuSession.forTesting(
      repository: MemoryStore().repository(),
      clientFactory: (s, c) {
        calls++;
        return fixtureClient(s, c);
      },
    );
    await session.initialize();
    expect(session.sources, isEmpty);
    session.setMediaContext(context());
    expect(await session.autoMatch(), isFalse);
    expect(await session.search('Title'), isEmpty);
    expect(calls, 0);
    session.load(const [DanmakuComment(timeMs: 1000, text: 'local')], sourceLabel: 'file');
    expect(session.comments.single.text, 'local');
  });

  for (final remember in [false, true]) {
    test('manual mapping follows the next episode with remember=$remember', () async {
      final store = MemoryStore();
      final requested = <String>[];
      final session = DanmakuSession.forTesting(
        repository: store.repository(),
        clientFactory: (source, credentials) => DanmakuApiClient(
          baseUrl: source.baseUrl,
          sourceId: source.id,
          httpClient: MockClient((request) async {
            requested.add(request.url.path);
            if (request.url.path.contains('/bangumi/')) {
              return http.Response(
                jsonEncode({
                  'bangumi': {
                    'episodes': [
                      {'episodeId': '7009', 'episodeTitle': 'First', 'episodeNumber': 51},
                      {'episodeId': '99', 'episodeTitle': 'Second', 'episodeNumber': 52},
                    ],
                  },
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'comments': [
                  {'p': '1,1,25,16777215', 'm': request.url.path.endsWith('/99') ? 'next episode' : 'first episode'},
                ],
              }),
              200,
            );
          }),
        ),
      );
      addTearDown(session.dispose);
      await session.saveSource(sourceA);
      session.setMediaContext(context());
      expect(session.episodeOffset, 0);
      await session.loadEpisode(
        const DanmakuSearchHit(
          sourceId: 'a',
          animeId: '4',
          episodeId: '7009',
          animeTitle: 'Title',
          episodeTitle: 'First',
          episodeNumber: 51,
        ),
        remember: remember,
      );
      expect(session.episodeOffset, 50);
      session.setMediaContext(context(item: 'next', episode: 2));
      expect(session.episodeOffset, 50);
      expect(await session.autoMatch(), isTrue);
      expect(session.comments.single.text, 'next episode');
      expect(requested.last, endsWith('/comment/99'));
      expect(requested.any((path) => path.contains('/search/')), isFalse);
      final saved = await store.repository().load();
      expect(saved.memories.containsKey(context().memoryKey), remember);
      if (remember) expect(saved.memories[context().memoryKey]!.episodeOffset, 50);
    });
  }

  test('CRUD enabled and order roundtrip; write failure preserves state', () async {
    final store = MemoryStore();
    final session = DanmakuSession.forTesting(repository: store.repository());
    await session.saveSource(sourceA);
    await session.saveSource(sourceB.copyWith(enabled: false));
    await session.reorderSources(['b', 'a']);
    await session.updateStyle(
      enabled: false,
      heatmapEnabled: false,
      fontSize: 22,
      opacity: 0.4,
      withRelated: false,
      chConvert: 2,
    );
    final restored = DanmakuSession.forTesting(repository: store.repository());
    await restored.initialize();
    expect(restored.sources.map((s) => s.id), ['b', 'a']);
    expect(restored.sources.first.enabled, isFalse);
    expect(restored.enabled, isFalse);
    expect(restored.heatmapEnabled, isFalse);
    expect(restored.fontSize, 22);
    expect(restored.opacity, 0.4);
    expect(restored.withRelated, isFalse);
    expect(restored.chConvert, 2);
    store.fail = true;
    await expectLater(session.saveSource(sourceA.copyWith(name: 'Changed')), throwsStateError);
    await expectLater(session.updateStyle(fontSize: 24), throwsStateError);
    expect(session.sources.last.name, 'A');
    expect(session.fontSize, 22);
    store.fail = false;
    await session.deleteSource('a');
    expect(session.sources.map((s) => s.id), ['b']);
  });

  test('corrupt persisted resource returns empty defaults without overwriting input', () async {
    final store = MemoryStore()..value = '{"version":1,"sources":"bad"}';
    final repository = store.repository();
    final result = await repository.load();
    expect(result.sources, isEmpty);
    expect(repository.recoveredCorruptData, isTrue);
    expect(store.value, '{"version":1,"sources":"bad"}');
    final session = DanmakuSession.forTesting(repository: repository);
    await session.initialize();
    expect(session.error, 'settings_invalid');
    await session.saveSource(sourceA);
    expect(session.error, isNull);
    expect(repository.recoveredCorruptData, isFalse);
    expect((await repository.load()).sources.single.id, 'a');
  });

  test('sequential sources preserve failures and source identity; manual selection restricts', () async {
    final calls = <String>[];
    final session = DanmakuSession.forTesting(
      repository: MemoryStore().repository(),
      clientFactory: (source, credentials) => DanmakuApiClient(
        baseUrl: source.baseUrl,
        sourceId: source.id,
        httpClient: MockClient((_) async {
          calls.add(source.id);
          if (source.id == 'a') return http.Response('private-token', 401);
          return http.Response('{"animes":[{"animeId":4,"animeTitle":"Title"}]}', 200);
        }),
      ),
    );
    await session.saveSource(sourceA);
    await session.saveSource(sourceB);
    final works = await session.search('Title');
    expect(calls, ['a', 'b']);
    expect(works.single.sourceId, 'b');
    expect(session.sourceFailures['a'], 'http_error (401)');
    await session.selectSource('a');
    calls.clear();
    expect(await session.search('Title'), isEmpty);
    expect(calls, ['a']);
  });

  test('season memories isolate profile/server/season and movies, persist offsets, invalidate address', () async {
    final store = MemoryStore();
    final session = DanmakuSession.forTesting(repository: store.repository(), clientFactory: fixtureClient);
    await session.saveSource(sourceA);
    session.setMediaContext(context());
    expect(session.suggestedQuery, 'Title 第1季');
    await session.loadEpisode(hitA);
    await session.updateStyle(offsetMs: 1500);
    await session.setEpisodeOffset(1);
    final restored = DanmakuSession.forTesting(repository: store.repository(), clientFactory: fixtureClient);
    await restored.initialize();
    restored.setMediaContext(context(item: 'next', episode: 2));
    expect(restored.offsetMs, 1500);
    expect(restored.episodeOffset, 1);
    expect(restored.selectedSourceId, 'a');
    for (final other in [
      context(server: 'other'),
      context(profile: 'other'),
      context(season: 2),
      context(series: null),
      context(series: null, item: 'movie2'),
    ]) {
      restored.setMediaContext(other);
      expect(restored.offsetMs, 0);
      expect(restored.selectedSourceId, isNull);
    }
    await restored.saveSource(sourceA.copyWith(baseUrl: 'https://new.example'));
    restored.setMediaContext(context());
    expect(restored.offsetMs, 0);
    expect(restored.selectedSourceId, isNull);
  });

  test('positive delay and clipping share immutable effective list, duration updates reversible', () async {
    final session = DanmakuSession.forTesting(repository: MemoryStore().repository());
    await session.initialize();
    session.setMediaContext(context());
    session.load(const [
      DanmakuComment(timeMs: 0, text: 'start'),
      DanmakuComment(timeMs: 10000, text: 'middle'),
      DanmakuComment(timeMs: 19000, text: 'end'),
    ], sourceLabel: 'local');
    await session.updateStyle(offsetMs: 1500);
    expect(session.comments.map((c) => c.timeMs), [1500, 11500]);
    final version = session.dataVersion;
    await session.updateStyle(opacity: 0.3);
    expect(session.dataVersion, version);
    session.setDuration(25000);
    expect(session.comments.map((c) => c.timeMs), [1500, 11500, 20500]);
    await session.updateStyle(offsetMs: -1500);
    expect(session.comments.map((c) => c.timeMs), [8500, 17500]);
    expect(() => session.comments.add(const DanmakuComment(timeMs: 0, text: 'x')), throwsUnsupportedError);
  });

  test('ambiguous same number and specials never silently select first', () async {
    final session = DanmakuSession.forTesting(repository: MemoryStore().repository());
    session.setMediaContext(context());
    expect(session.suggestedEpisode([hitA]), hitA);
    expect(session.suggestedEpisode([hitA, hitA]), isNull);
    const special = DanmakuSearchHit(
      sourceId: 'a',
      animeId: '4',
      episodeId: '42',
      animeTitle: 'Title',
      episodeTitle: 'SP',
    );
    expect(session.suggestedEpisode([special]), isNull);
    await session.setEpisodeOffset(-1);
    expect(session.suggestedEpisode([hitA]), isNull);
  });

  test('late old item response and old route disposal cannot overwrite/clear current item', () async {
    final delayed = Completer<http.Response>();
    final started = Completer<void>();
    final session = DanmakuSession.forTesting(
      repository: MemoryStore().repository(),
      clientFactory: (source, credentials) => DanmakuApiClient(
        baseUrl: source.baseUrl,
        sourceId: source.id,
        httpClient: MockClient((request) async {
          started.complete();
          return delayed.future;
        }),
      ),
    );
    await session.saveSource(sourceA);
    final oldOwner = session.setMediaContext(context(item: 'a'));
    final oldLoad = session.loadEpisode(hitA);
    await started.future;
    session.setMediaContext(context(item: 'b'));
    session.load(const [DanmakuComment(timeMs: 1000, text: 'B')], sourceLabel: 'B');
    session.clear(ownerGeneration: oldOwner);
    delayed.complete(http.Response('{"comments":[{"p":"10,1,16777215,0","m":"A"}]}', 200));
    await oldLoad;
    expect(session.comments.single.text, 'B');
    expect(session.sourceLabel, 'B');
  });

  test('source edits invalidate in-flight candidate response before current selection', () async {
    final delayed = Completer<http.Response>();
    final started = Completer<void>();
    final session = DanmakuSession.forTesting(
      repository: MemoryStore().repository(),
      clientFactory: (source, credentials) => DanmakuApiClient(
        baseUrl: source.baseUrl,
        sourceId: source.id,
        httpClient: MockClient((_) async {
          started.complete();
          return delayed.future;
        }),
      ),
    );
    await session.saveSource(sourceA);
    final search = session.search('Title');
    await started.future;
    await session.saveSource(sourceA.copyWith(baseUrl: 'https://new.example'));
    delayed.complete(http.Response('{"animes":[{"animeId":4,"animeTitle":"Old source"}]}', 200));
    expect(await search, isEmpty);
    expect(session.candidates, isEmpty);
  });

  test('connection test does not persist success and reports safe status/elapsed', () async {
    final store = MemoryStore();
    final session = DanmakuSession.forTesting(repository: store.repository(), clientFactory: fixtureClient);
    final result = await session.testSource(sourceA);
    expect(result.isSuccess, isTrue);
    expect(result.elapsed, greaterThanOrEqualTo(Duration.zero));
    expect(store.value, isNull);
  });

  for (final failureRoute in ['bangumi', 'comment']) {
    test('automatic matching retries complete flow after $failureRoute failure with fresh IDs', () async {
      final paths = <String>[];
      final session = DanmakuSession.forTesting(
        repository: MemoryStore().repository(),
        clientFactory: (source, credentials) => DanmakuApiClient(
          baseUrl: source.baseUrl,
          sourceId: source.id,
          httpClient: MockClient((request) async {
            final path = request.url.path;
            paths.add('${source.id}:$path');
            final animeId = source.id == 'a' ? 4 : 8;
            final episodeId = source.id == 'a' ? 41 : 81;
            if (source.id == 'a' && path.contains('/$failureRoute/')) return http.Response('', 503);
            if (path.endsWith('search/anime')) {
              return http.Response('{"animes":[{"animeId":$animeId,"animeTitle":"Title"}]}', 200);
            }
            if (path.endsWith('bangumi/$animeId')) {
              return http.Response('{"bangumi":{"episodes":[{"episodeId":$episodeId,"episodeNumber":"1"}]}}', 200);
            }
            expect(path, endsWith('comment/$episodeId'));
            return http.Response('{"comments":[{"p":"10,1,16777215,0","m":"${source.id}"}]}', 200);
          }),
        ),
      );
      await session.saveSource(sourceA);
      await session.saveSource(sourceB);
      session.setMediaContext(context());
      expect(await session.autoMatch(), isTrue);
      expect(session.comments.single.text, 'b');
      expect(session.selectedSourceId, 'b');
      expect(session.sourceFailures, {'a': 'http_error (503)'});
      expect(paths.where((path) => path.startsWith('b:')), [
        'b:/api/v2/search/anime',
        'b:/api/v2/bangumi/8',
        'b:/api/v2/comment/81',
      ]);
    });
  }

  test('source candidate switch drops old timing and cannot mutate the previous source memory', () async {
    final store = MemoryStore();
    final session = DanmakuSession.forTesting(repository: store.repository(), clientFactory: fixtureClient);
    await session.saveSource(sourceA);
    await session.saveSource(sourceB);
    session.setMediaContext(context());
    await session.loadEpisode(hitA);
    await session.updateStyle(offsetMs: 1500);
    await session.setEpisodeOffset(2);
    final hits = await session.episodes(const DanmakuAnime(sourceId: 'b', animeId: '4', title: 'Title'));
    expect(session.offsetMs, 0);
    expect(session.episodeOffset, 0);
    await session.updateStyle(offsetMs: 2500);
    final original = (await store.repository().load()).memories[context().memoryKey]!;
    expect(original.sourceId, 'a');
    expect(original.offsetMs, 1500);
    await session.loadEpisode(hits.first);
    expect(session.comments.single.timeMs, 12500);
    final saved = (await store.repository().load()).memories[context().memoryKey]!;
    expect(saved.sourceId, 'b');
    expect(saved.offsetMs, 2500);
  });

  test('same-item successor route owns a distinct context token', () async {
    final session = DanmakuSession.forTesting(repository: MemoryStore().repository());
    final first = session.setMediaContext(context());
    final second = session.setMediaContext(context());
    expect(session.ownsContext(first), isFalse);
    expect(session.ownsContext(second), isTrue);
    session.clear(ownerGeneration: first);
    expect(session.ownsContext(second), isTrue);
    session.clear(ownerGeneration: second);
    expect(session.ownsContext(second), isFalse);
  });

  test('queued offset edits cannot update a successor context or its memory', () async {
    String? stored;
    Completer<void>? writeGate;
    Completer<void>? writeStarted;
    final repository = DanmakuSettingsRepository(
      read: () async => stored,
      write: (value) async {
        writeStarted?.complete();
        await writeGate?.future;
        stored = value;
      },
      protect: (value) async => value,
      reveal: (value) async => value,
    );
    final session = DanmakuSession.forTesting(repository: repository, clientFactory: fixtureClient);
    await session.saveSource(sourceA);
    session.setMediaContext(context(season: 2));
    await session.loadEpisode(hitA);
    await session.updateStyle(offsetMs: 300);
    session.setMediaContext(context());
    await session.loadEpisode(hitA);
    writeGate = Completer<void>();
    writeStarted = Completer<void>();
    final firstWrite = session.updateStyle(fontSize: 23);
    await writeStarted.future;
    writeStarted = null;
    final offsetWrite = session.updateStyle(offsetMs: 1500);
    final episodeWrite = session.setEpisodeOffset(3);
    session.setMediaContext(context(season: 2));
    writeGate.complete();
    await Future.wait([firstWrite, offsetWrite, episodeWrite]);
    expect(session.offsetMs, 300);
    expect(session.episodeOffset, 0);
    final saved = await repository.load();
    expect(saved.memories[context(season: 2).memoryKey]!.offsetMs, 300);
    expect(saved.memories[context().memoryKey]!.offsetMs, 0);
    expect(saved.memories[context().memoryKey]!.episodeOffset, 0);
  });

  test('transient initialization read failure can be retried', () async {
    var reads = 0;
    final session = DanmakuSession.forTesting(
      repository: DanmakuSettingsRepository(
        read: () async {
          if (reads++ == 0) throw StateError('disk');
          return null;
        },
      ),
    );
    await expectLater(session.initialize(), throwsStateError);
    expect(session.initialized, isFalse);
    await session.initialize();
    expect(session.initialized, isTrue);
    expect(reads, 2);
  });

  test('disabling an unrelated source preserves manual selection; deleting current source removes memory', () async {
    final store = MemoryStore();
    final session = DanmakuSession.forTesting(repository: store.repository(), clientFactory: fixtureClient);
    await session.saveSource(sourceA);
    await session.saveSource(sourceB);
    session.setMediaContext(context());
    await session.selectSource('a');
    await session.loadEpisode(hitA);
    await session.updateStyle(offsetMs: 1500);
    await session.saveSource(sourceB.copyWith(enabled: false));
    expect(session.selectedSourceId, 'a');
    expect(session.comments.single.timeMs, 11500);
    await session.saveSource(sourceA.copyWith(enabled: false));
    expect(session.selectedSourceId, isNull);
    expect(session.comments, isEmpty);
    expect(session.offsetMs, 0);
    session.setMediaContext(context());
    expect(session.selectedSourceId, isNull);
    expect(session.offsetMs, 0);
    await session.deleteSource('a');
    expect((await store.repository().load()).memories, isEmpty);
  });

  test('reload applies an out-of-process source import and drops a removed selection', () async {
    final store = MemoryStore();
    final session = DanmakuSession.forTesting(repository: store.repository(), clientFactory: fixtureClient);
    await session.saveSource(sourceA);
    session.setMediaContext(context());
    await session.selectSource('a');
    await session.loadEpisode(hitA);
    expect(session.comments, hasLength(1));

    await store.repository().save(const DanmakuSettings(sources: [sourceB]));
    await session.reload();

    expect(session.sources.map((source) => source.id), ['b']);
    expect(session.selectedSourceId, isNull);
    expect(session.comments, isEmpty);
  });

  test('automatic failure report retains earlier source when the last source has no candidate', () async {
    final session = DanmakuSession.forTesting(
      repository: MemoryStore().repository(),
      clientFactory: (source, credentials) => DanmakuApiClient(
        baseUrl: source.baseUrl,
        sourceId: source.id,
        httpClient: MockClient((request) async {
          if (source.id == 'b') return http.Response('{"animes":[]}', 200);
          if (request.url.path.endsWith('search/anime')) {
            return http.Response('{"animes":[{"animeId":4,"animeTitle":"Title"}]}', 200);
          }
          return http.Response('', 503);
        }),
      ),
    );
    await session.saveSource(sourceA);
    await session.saveSource(sourceB);
    session.setMediaContext(context());
    expect(await session.autoMatch(), isFalse);
    expect(session.sourceFailures, {'a': 'http_error (503)', 'b': 'no_candidates'});
  });

  test('saved official credentials are supplied to test and never to a replacement gateway', () async {
    final seen = <DanmakuCredentials?>[];
    final session = DanmakuSession.forTesting(
      repository: MemoryStore().repository(),
      clientFactory: (source, credentials) {
        seen.add(credentials);
        return fixtureClient(source, credentials);
      },
    );
    const official = DanmakuSource(id: 'official', name: 'Own', baseUrl: 'https://api.dandanplay.net');
    await session.saveSource(official, appId: 'fixture-id', appSecret: 'fixture-secret');
    expect(await session.hasSourceCredentials(official.id), isTrue);
    expect((await session.testSource(official)).isSuccess, isTrue);
    expect(seen.single!.appId, 'fixture-id');
    expect(seen.single!.appSecret, 'fixture-secret');
    final gateway = official.copyWith(baseUrl: 'https://gateway.example/token');
    await session.saveSource(gateway);
    expect((await session.testSource(gateway)).isSuccess, isTrue);
    expect(seen.last, isNull);
  });

  group('credential storage integration', () {
    setUp(() {
      resetSharedPreferencesForTest();
      SettingsService.resetForTesting();
      CredentialVault.resetKeyForTesting();
    });
    test('private path and own secret encrypted and absent from portable export', () async {
      final session = DanmakuSession.forTesting();
      await session.saveSource(sourceA);
      const official = DanmakuSource(id: 'official', name: 'Own', baseUrl: 'https://api.dandanplay.net');
      await session.saveSource(official, appId: 'fixture-id', appSecret: 'fixture-secret');
      final settings = await SettingsService.getInstance();
      final stored = settings.readString(DanmakuSettingsRepository.storageKey);
      expect(CredentialVault.isProtected(stored), isTrue);
      expect(stored, isNot(contains('private-token')));
      expect(stored, isNot(contains('fixture-secret')));
      expect(SettingsService.portablePrefs.any((p) => p.key == DanmakuSettingsRepository.storageKey), isFalse);
      expect(isSensitivePrefKey(DanmakuSettingsRepository.storageKey), isTrue);
      final restored = DanmakuSession.forTesting();
      await restored.initialize();
      expect(restored.sources.first.baseUrl, sourceA.baseUrl);
      expect(await restored.hasSourceCredentials('official'), isTrue);
      await restored.saveSource(official.copyWith(baseUrl: 'https://gateway.example'));
      expect(await restored.hasSourceCredentials('official'), isFalse);
      final clear =
          jsonDecode((await CredentialVault.reveal(settings.readString(DanmakuSettingsRepository.storageKey)))!) as Map;
      expect(clear['credentials'], isEmpty);
    });
  });
}
