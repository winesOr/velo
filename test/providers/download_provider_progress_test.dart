import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/models/download_models.dart';
import 'package:plezy/providers/download_provider.dart';
import 'package:plezy/services/download_manager_service.dart';
import 'package:plezy/services/download_storage_service.dart';
import 'package:plezy/services/jellyfin_api_cache.dart';
import 'package:plezy/services/plex_api_cache.dart';

class _ProgressManager extends DownloadManagerService {
  _ProgressManager(AppDatabase database)
    : super(
        database: database,
        storageService: DownloadStorageService.instance,
        clientResolver: (serverId, {clientScopeId}) => null,
      );

  @override
  Future<void> deleteDownload(String globalKey) async {}
}

DownloadProgress _progress(String key, int percent) => DownloadProgress(
  globalKey: key,
  status: DownloadStatus.downloading,
  progress: percent,
  downloadedBytes: percent * 100,
  totalBytes: 10000,
  speed: 1000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const interval = Duration(milliseconds: 100);
  late AppDatabase database;
  late _ProgressManager manager;
  late DownloadProvider provider;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    PlexApiCache.initialize(database);
    JellyfinApiCache.initialize(database);
    manager = _ProgressManager(database)..recoveryFuture = Future<void>.value();
    provider = DownloadProvider.forTesting(
      downloadManager: manager,
      database: database,
      progressNotifyInterval: interval,
    );
    await provider.ensureInitialized();
    provider.debugSeedState(downloads: {'srv:a': _progress('srv:a', 0), 'srv:b': _progress('srv:b', 0)});
  });

  tearDown(() async {
    if (!provider.isDisposed) provider.dispose();
    manager.dispose();
    await database.close();
  });

  Future<void> deliver() => Future<void>.delayed(Duration.zero);
  Future<void> flushInterval() => Future<void>.delayed(const Duration(milliseconds: 150));

  test('a burst publishes each latest value once and preserves immutable snapshots', () async {
    var notifications = 0;
    provider.addListener(() => notifications++);
    final old = provider.downloads;
    final structure = provider.downloadsStructureRevision;
    expect(identical(old, provider.downloads), isTrue);

    for (var i = 1; i <= 100; i++) {
      manager.debugEmitProgress(_progress('srv:a', i));
    }
    manager.debugEmitProgress(_progress('srv:b', 35));
    await deliver();

    expect(provider.downloads['srv:a']!.downloadedBytes, 10000);
    expect(provider.downloads['srv:b']!.progress, 35);
    expect(old['srv:a']!.progress, 0);
    expect(identical(provider.downloads, provider.downloads), isTrue);
    expect(() => provider.downloads.clear(), throwsUnsupportedError);
    expect(notifications, 0);
    await flushInterval();

    expect(notifications, 1, reason: '101 numeric updates share one trailing publication');
    expect(provider.downloadsStructureRevision, structure);
  });

  test('state changes flush pending values immediately and do not leave a second timer notification', () async {
    var notifications = 0;
    provider.addListener(() => notifications++);
    manager.debugEmitProgress(_progress('srv:a', 40));
    await deliver();
    manager.debugEmitProgress(_progress('srv:b', 10).copyWith(status: DownloadStatus.paused));
    await deliver();
    expect(notifications, 1);
    expect(provider.downloads['srv:a']!.progress, 40);
    expect(provider.downloads['srv:b']!.status, DownloadStatus.paused);
    await flushInterval();
    expect(notifications, 1);

    for (final status in [
      DownloadStatus.queued,
      DownloadStatus.downloading,
      DownloadStatus.completed,
      DownloadStatus.failed,
      DownloadStatus.cancelled,
      DownloadStatus.partial,
    ]) {
      final before = notifications;
      manager.debugEmitProgress(_progress('srv:b', 50).copyWith(status: status));
      await deliver();
      expect(notifications, before + 1, reason: '$status must remain immediately actionable');
    }
  });

  test('errors and sort-relevant total size changes are immediate structural updates', () async {
    var notifications = 0;
    provider.addListener(() => notifications++);
    final revision = provider.downloadsStructureRevision;
    manager.debugEmitProgress(_progress('srv:a', 1).copyWith(errorMessage: 'retrying'));
    await deliver();
    expect(notifications, 1);
    manager.debugEmitProgress(_progress('srv:a', 2).copyWith(errorMessage: 'retrying', totalBytes: 20000));
    await deliver();
    expect(notifications, 2);
    expect(provider.downloadsStructureRevision, revision + 2);
  });

  test('profile changes clear the cached view and cancel progress belonging to the old profile', () async {
    final old = provider.downloads;
    manager.debugEmitProgress(_progress('srv:a', 45));
    await deliver();
    provider.setActiveProfileId(null);
    expect(provider.downloads, isEmpty);
    expect(old.keys, ['srv:a', 'srv:b']);
    await provider.debugWaitForProfileScopedReload();
    var notifications = 0;
    provider.addListener(() => notifications++);
    manager.debugEmitProgress(_progress('srv:a', 90));
    await deliver();
    await flushInterval();
    expect(provider.downloads, isEmpty);
    expect(notifications, 0);
  });

  test('deletion invalidates the cached view and late physical progress cannot reclaim ownership', () async {
    final old = provider.downloads;
    manager.debugEmitProgress(_progress('srv:a', 45));
    await deliver();
    await provider.deleteDownload('srv:a');
    expect(provider.downloads.keys, ['srv:b']);
    expect(old, contains('srv:a'));
    var notifications = 0;
    provider.addListener(() => notifications++);
    manager.debugEmitProgress(_progress('srv:a', 90));
    await deliver();
    await flushInterval();
    expect(provider.getProgress('srv:a'), isNull);
    expect(provider.downloads.keys, ['srv:b']);
    expect(notifications, 0);
  });

  test('disposing cancels a scheduled publication and ignores queued stream updates', () async {
    var notifications = 0;
    provider.addListener(() => notifications++);
    manager.debugEmitProgress(_progress('srv:a', 45));
    await deliver();
    provider.dispose();
    manager.debugEmitProgress(_progress('srv:b', 90));
    await flushInterval();
    expect(notifications, 0);
  });

  test('a zero interval allows callers to opt out of numeric batching', () async {
    provider.dispose();
    provider = DownloadProvider.forTesting(
      downloadManager: manager,
      database: database,
      progressNotifyInterval: Duration.zero,
    );
    await provider.ensureInitialized();
    provider.debugSeedState(downloads: {'srv:a': _progress('srv:a', 0)});
    var notifications = 0;
    provider.addListener(() => notifications++);
    for (var i = 1; i <= 3; i++) {
      manager.debugEmitProgress(_progress('srv:a', i));
    }
    await deliver();
    expect(notifications, 3);
  });
}
