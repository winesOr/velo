import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plezy/connection/connection.dart';
import 'package:plezy/connection/connection_registry.dart';
import 'package:plezy/database/app_database.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/media/library_query.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/models/download_models.dart';
import 'package:plezy/navigation/main_screen_scope.dart';
import 'package:plezy/providers/download_provider.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/screens/downloads/downloads_screen.dart';
import 'package:plezy/services/download_manager_service.dart';
import 'package:plezy/services/download_storage_service.dart';
import 'package:plezy/services/jellyfin_api_cache.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/services/plex_api_cache.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/services/music/music_playback_service.dart';
import 'package:plezy/services/storage_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/focusable_media_card.dart';
import 'package:plezy/widgets/overlay_sheet.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/prefs.dart';
import '../../test_helpers/media_items.dart';
import '../../test_helpers/io_fakes.dart';
import '../../test_helpers/multi_server_fixtures.dart';
import '../../test_helpers/stub_music_playback_service.dart';

class _FakeConnectionRegistry extends ConnectionRegistry {
  _FakeConnectionRegistry(super.db);

  @override
  Stream<List<Connection>> watchConnections() => Stream.value(const []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalPathProvider = PathProviderPlatform.instance;

  late AppDatabase db;
  late DownloadProvider downloadProvider;
  late MultiServerProvider multiServerProvider;
  late MultiServerManager serverManager;
  late DownloadManagerService downloadManager;
  late DownloadStorageService storageService;
  late Directory temporaryDirectory;

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    DownloadStorageService.resetForTesting();
    temporaryDirectory = await Directory.systemTemp.createTemp('downloads_options_test_');
    PathProviderPlatform.instance = FakePathProvider(temporaryDirectory);
    await SettingsService.getInstance();
    // Warm the StorageService singleton outside the fake-async zone: its
    // cold init path never completes inside testWidgets (the same reason the
    // library browse tests pre-warm it in setUp).
    await StorageService.getInstance();
    storageService = DownloadStorageService.instance;
    await storageService.initialize(SettingsService.instance);

    db = AppDatabase.forTesting(NativeDatabase.memory());
    PlexApiCache.initialize(db);
    JellyfinApiCache.initialize(db);

    downloadManager = DownloadManagerService(
      database: db,
      storageService: storageService,
      clientResolver: (serverId, {clientScopeId}) => null,
    );
    downloadProvider = DownloadProvider.forTesting(downloadManager: downloadManager, database: db);
    await downloadProvider.ensureInitialized();

    serverManager = MultiServerManager();
    multiServerProvider = testMultiServerProvider(serverManager);
  });

  tearDown(() async {
    downloadProvider.dispose();
    downloadManager.dispose();
    multiServerProvider.dispose();
    await db.close();
    DownloadStorageService.resetForTesting();
    SettingsService.resetForTesting();
    PathProviderPlatform.instance = originalPathProvider;
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  /// Pumps the screen as a mobile (Android) surface inside an
  /// [OverlaySheetHost] so the app-bar options action opens sheet pages.
  Future<void> pumpScreen(WidgetTester tester, {required GlobalKey<DownloadsScreenState> screenKey}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      InputModeTracker(
        child: MultiProvider(
          providers: [
            Provider<ConnectionRegistry>.value(value: _FakeConnectionRegistry(db)),
            ChangeNotifierProvider<DownloadProvider>.value(value: downloadProvider),
            ChangeNotifierProvider<MultiServerProvider>.value(value: multiServerProvider),
            ChangeNotifierProvider<MusicPlaybackService>(create: (_) => StubMusicPlaybackService()),
          ],
          child: MaterialApp(
            theme: monoTheme(dark: true).copyWith(platform: TargetPlatform.android),
            home: MainScreenFocusScope(
              focusSidebar: () {},
              sideNavigationWidth: 0,
              child: OverlaySheetHost(child: DownloadsScreen(key: screenKey)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  MediaItem movie(String id, {required String title, String? libraryId, String? libraryTitle, int? viewCount}) =>
      testMediaItem(
        id: id,
        kind: MediaKind.movie,
        title: title,
        serverId: 'srv',
        serverName: 'Server One',
        libraryId: libraryId,
        libraryTitle: libraryTitle,
        viewCount: viewCount,
      );

  void seed(List<MediaItem> items) {
    downloadProvider.debugSeedState(
      downloads: {
        for (final item in items)
          item.globalKey: DownloadProgress(globalKey: item.globalKey, status: DownloadStatus.completed),
      },
      metadata: {for (final item in items) item.globalKey: item},
    );
  }

  List<FocusableMediaCard> cards(WidgetTester tester) =>
      tester.widgetList<FocusableMediaCard>(find.byType(FocusableMediaCard)).toList();

  testWidgets('persisted library filter survives a cold start before downloads load', (tester) async {
    final storage = await StorageService.getInstance();
    await storage.saveLibraryFilters(const [
      LibraryFilter(field: 'library', values: ['srv:lib-a']),
    ], sectionId: 'downloads:movies');

    // Pump with an empty provider: the tab restores its options before any
    // downloads exist, so validating against the (empty) library list would
    // drop the filter. Seeding afterwards must still apply it.
    final screenKey = GlobalKey<DownloadsScreenState>();
    await pumpScreen(tester, screenKey: screenKey);
    screenKey.currentState!.tabController.index = 2;
    await tester.pumpAndSettle();

    seed([
      movie('m-1', title: 'Alpha One', libraryId: 'lib-a', libraryTitle: 'Library A'),
      movie('m-2', title: 'Alpha Two', libraryId: 'lib-a', libraryTitle: 'Library A'),
      movie('m-3', title: 'Beta One', libraryId: 'lib-b', libraryTitle: 'Library B'),
    ]);
    final revisionBefore = downloadProvider.downloadsStructureRevision;
    downloadProvider.safeNotifyListeners();
    expect(downloadProvider.downloadsStructureRevision, revisionBefore + 1);
    await tester.pumpAndSettle();
    expect(cards(tester).map((card) => (card.item as MediaItem).title), ['Alpha One', 'Alpha Two']);
  });
}
