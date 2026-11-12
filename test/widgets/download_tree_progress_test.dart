import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/focus/focusable_wrapper.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/models/download_models.dart';
import 'package:plezy/providers/download_provider.dart';
import 'package:plezy/services/download_manager_service.dart';
import 'package:plezy/services/download_storage_service.dart';
import 'package:plezy/services/jellyfin_api_cache.dart';
import 'package:plezy/services/plex_api_cache.dart';
import 'package:plezy/widgets/download_tree_view.dart';
import 'package:provider/provider.dart';

import '../test_helpers/media_items.dart';

DownloadProgress _progress(String key, int percent) => DownloadProgress(
  globalKey: key,
  status: DownloadStatus.downloading,
  progress: percent,
  totalBytes: 10000,
  downloadedBytes: percent * 100,
  speed: 1000,
);

void main() {
  late AppDatabase database;
  late DownloadManagerService manager;
  late DownloadProvider provider;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    PlexApiCache.initialize(database);
    JellyfinApiCache.initialize(database);
    manager = DownloadManagerService(
      database: database,
      storageService: DownloadStorageService.instance,
      clientResolver: (serverId, {clientScopeId}) => null,
    )..recoveryFuture = Future<void>.value();
    provider = DownloadProvider.forTesting(
      downloadManager: manager,
      database: database,
      progressNotifyInterval: const Duration(milliseconds: 100),
    );
    await provider.ensureInitialized();
    provider.debugSeedState(
      downloads: {'srv:a': _progress('srv:a', 1), 'srv:b': _progress('srv:b', 1)},
      metadata: {
        for (final id in ['a', 'b'])
          'srv:$id': testMediaItem(
            id: id,
            backend: MediaBackend.plex,
            kind: MediaKind.movie,
            title: id == 'a' ? 'Active movie' : 'Unchanged movie',
            serverId: ServerId('srv'),
          ),
      },
    );
  });

  tearDown(() async {
    provider.dispose();
    manager.dispose();
    await database.close();
  });

  Future<void> pumpTree(WidgetTester tester, {VoidCallback? onHierarchyBuild}) => tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: InputModeTracker(
        child: MaterialApp(
          home: Scaffold(
            body: Selector<DownloadProvider, int>(
              selector: (_, value) => value.downloadsStructureRevision,
              builder: (context, _, _) {
                onHierarchyBuild?.call();
                return DownloadTreeView(
                  downloads: provider.downloads,
                  metadata: provider.metadata,
                  observeProgress: true,
                  onPause: (_) {},
                  onResume: (_) {},
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Finder row(String key) => find.byKey(ValueKey('download_row_$key'));

  testWidgets('100 updates rebuild the affected row once without rebuilding the hierarchy or sibling', (tester) async {
    var hierarchyBuilds = 0;
    await pumpTree(tester, onHierarchyBuild: () => hierarchyBuilds++);
    await tester.pumpAndSettle();
    final baselineBuilds = hierarchyBuilds;
    final unchangedWidget = tester.widget(row('srv:b'));
    final rowBuilds = <String, int>{};
    final previousCallback = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousCallback?.call(element, builtOnce);
      final key = element.widget.key;
      if (key is ValueKey<String> && key.value.startsWith('download_row_')) {
        rowBuilds.update(key.value, (count) => count + 1, ifAbsent: () => 1);
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);

    await tester.runAsync(() async {
      for (var i = 1; i <= 100; i++) {
        manager.debugEmitProgress(_progress('srv:a', i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();

    expect(hierarchyBuilds, baselineBuilds);
    expect(rowBuilds['download_row_srv:a'], 1);
    expect(rowBuilds['download_row_srv:b'] ?? 0, 0);
    expect(identical(tester.widget(row('srv:b')), unchangedWidget), isTrue);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.descendant(of: row('srv:a'), matching: find.byType(LinearProgressIndicator)),
    );
    expect(indicator.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a status re-sort keeps focus on the same download and exposes the new action', (tester) async {
    await pumpTree(tester);
    await tester.pumpAndSettle();
    FocusableWrapper wrapper() => tester.widget<FocusableWrapper>(
      find.descendant(of: row('srv:a'), matching: find.byType(FocusableWrapper)).first,
    );
    wrapper().focusNode!.requestFocus();
    await tester.pump();

    await tester.runAsync(() async {
      manager.debugEmitProgress(_progress('srv:a', 25).copyWith(status: DownloadStatus.paused));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump();

    expect(tester.getTopLeft(row('srv:b')).dy, lessThan(tester.getTopLeft(row('srv:a')).dy));
    expect(wrapper().focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}
