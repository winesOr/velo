import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_source_info.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/services/video_volume_controller.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/watch_together/providers/watch_together_provider.dart';
import 'package:plezy/widgets/overlay_sheet.dart';
import 'package:plezy/widgets/video_controls/desktop_video_controls.dart';
import 'package:plezy/widgets/video_controls/models/track_controls_state.dart';
import 'package:plezy/widgets/video_controls/sheets/danmaku_settings_sheet.dart';
import 'package:plezy/widgets/video_controls/video_control_button.dart';
import 'package:plezy/widgets/video_controls/widgets/track_chapter_controls.dart';
import 'package:provider/provider.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';
import '../test_helpers/theme.dart';
import '../test_helpers/watch_together_fakes.dart';

void main() {
  setUp(() {
    resetSharedPreferencesForTest();
    LocaleSettings.setLocaleSync(AppLocale.en);
    TvDetectionService.debugSetAppleTVOverride(false);
  });

  tearDown(() {
    TvDetectionService.debugSetAppleTVOverride(null);
    PlatformDetector.debugSetIsDesktopOSOverride(null);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    testWidgets('$platform danmaku entry opens settings and resumes auto-hide after closing', (tester) async {
      PlatformDetector.debugSetIsDesktopOSOverride(platform == TargetPlatform.macOS);
      final metadata = testMediaItem(title: 'Test movie');
      var canceled = 0;
      var resumed = 0;
      final controller = await _pump(
        tester,
        platform: platform,
        state: TrackControlsState(
          metadata: metadata,
          onCancelAutoHide: () => canceled++,
          onStartAutoHide: () => resumed++,
        ),
      );

      final entry = find.byTooltip(t.danmaku.title);
      expect(entry, findsOneWidget);
      final button = tester.widget<VideoControlButton>(_danmakuButton());
      expect(button.semanticLabel, t.danmaku.title);
      expect(button.icon, Symbols.forum_rounded);
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.byType(DanmakuSettingsSheet), findsOneWidget);
      expect(tester.widget<DanmakuSettingsSheet>(find.byType(DanmakuSettingsSheet)).metadata, same(metadata));
      expect(canceled, 1);
      expect(resumed, 0);
      controller.close();
      await tester.pumpAndSettle();
      expect(find.byType(DanmakuSettingsSheet), findsNothing);
      expect(resumed, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TV D-pad reaches danmaku and confirmation opens settings', (tester) async {
    TvDetectionService.debugSetAppleTVOverride(true);
    PlatformDetector.debugSetIsDesktopOSOverride(false);
    final nodes = _focusNodes();
    final controller = await _pump(tester, platform: TargetPlatform.android, focusNodes: nodes);
    expect(PlatformDetector.isTV(), isTrue);
    expect(find.byType(VideoControlButton), findsNWidgets(3));

    nodes.first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(nodes[1].hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final entry = tester.widget<VideoControlButton>(_danmakuButton());
    expect(entry.focusNode, same(nodes[2]));
    expect(nodes[2].hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(DanmakuSettingsSheet), findsOneWidget);
    controller.close();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('all nine desktop controls have focus nodes and bidirectional navigation', (tester) async {
    PlatformDetector.debugSetIsDesktopOSOverride(true);
    final nodes = _focusNodes();
    var leftExits = 0;
    var upExits = 0;
    var downExits = 0;
    await _pump(
      tester,
      focusNodes: nodes,
      chapters: [MediaChapter(id: 1, startTimeOffset: 0, title: 'Chapter')],
      state: TrackControlsState(
        showQueueButton: true,
        onQueueItemSelected: (_) {},
        onTogglePIPMode: () {},
        onCycleBoxFitMode: () {},
        onToggleAlwaysOnTop: () {},
        onToggleFullscreen: () {},
      ),
      onNavigateLeft: () => leftExits++,
      onNavigateUp: () => upExits++,
      onNavigateDown: () => downExits++,
    );
    final buttons = tester.widgetList<VideoControlButton>(find.byType(VideoControlButton)).toList();
    expect(buttons, hasLength(9));
    expect(buttons.map((button) => button.focusNode), orderedEquals(nodes));
    expect(tester.widget<VideoControlButton>(_danmakuButton()).focusNode, same(nodes[6]));

    nodes.first.requestFocus();
    await tester.pump();
    for (var i = 1; i < nodes.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(nodes[i].hasFocus, isTrue, reason: 'right navigation to control $i');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(nodes.last.hasFocus, isTrue);
    for (var i = nodes.length - 2; i >= 0; i--) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(nodes[i].hasFocus, isTrue, reason: 'left navigation to control $i');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(leftExits, 1);
    expect(upExits, 1);
    expect(downExits, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop parent supplies focus nodes for the complete nine-button row', (tester) async {
    PlatformDetector.debugSetIsDesktopOSOverride(true);
    await initializeDateFormatting('en');
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = FakeSyncPlayer();
    addTearDown(player.dispose);
    final settings = await SettingsService.getInstance();
    final volume = VideoVolumeController(player: player, settings: settings, initialVolume: 100);
    addTearDown(volume.dispose);
    final watchTogether = WatchTogetherProvider();
    addTearDown(watchTogether.dispose);
    await tester.pumpWidget(
      InputModeTracker(
        child: ChangeNotifierProvider<WatchTogetherProvider>.value(
          value: watchTogether,
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(platform: TargetPlatform.macOS, extensions: const [testMonoTokens]),
            home: Scaffold(
              body: DesktopVideoControls(
                useDpadNavigation: false,
                player: player,
                volumeController: volume,
                metadata: testMediaItem(),
                onPlayPause: () {},
                chapters: [MediaChapter(id: 1, startTimeOffset: 0, title: 'Chapter')],
                chaptersLoaded: true,
                seekTimeSmall: 10,
                onSeekToPreviousChapter: () {},
                onSeekToNextChapter: () {},
                onSeek: (_) {},
                onSeekEnd: (_) {},
                getReplayIcon: (_) => Icons.replay,
                getForwardIcon: (_) => Icons.forward_10,
                trackControlsState: TrackControlsState(
                  showQueueButton: true,
                  onQueueItemSelected: (_) {},
                  onTogglePIPMode: () {},
                  onCycleBoxFitMode: () {},
                  onToggleAlwaysOnTop: () {},
                  onToggleFullscreen: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final row = tester.widget<TrackChapterControls>(find.byType(TrackChapterControls));
    final buttons = tester
        .widgetList<VideoControlButton>(
          find.descendant(of: find.byType(TrackChapterControls), matching: find.byType(VideoControlButton)),
        )
        .toList();
    expect(buttons, hasLength(9));
    expect(row.focusNodes, hasLength(9));
    expect(buttons.map((button) => button.focusNode), orderedEquals(row.focusNodes!));
    row.focusNodes![7].requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(row.focusNodes!.last.hasFocus, isTrue);
    expect(buttons.last.semanticLabel, t.videoControls.fullscreenButton);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Finder _danmakuButton() =>
    find.byWidgetPredicate((widget) => widget is VideoControlButton && widget.semanticLabel == t.danmaku.title);

List<FocusNode> _focusNodes() {
  final nodes = List.generate(9, (i) => FocusNode(debugLabel: 'TestTrackControl$i'));
  addTearDown(() {
    for (final node in nodes) {
      node.dispose();
    }
  });
  return nodes;
}

Future<OverlaySheetController> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.macOS,
  TrackControlsState state = const TrackControlsState(),
  List<FocusNode>? focusNodes,
  List<MediaChapter> chapters = const [],
  VoidCallback? onNavigateLeft,
  VoidCallback? onNavigateUp,
  VoidCallback? onNavigateDown,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final player = FakeSyncPlayer();
  addTearDown(player.dispose);
  late OverlaySheetController controller;
  await tester.pumpWidget(
    InputModeTracker(
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(platform: platform, extensions: const [testMonoTokens]),
        home: OverlaySheetHost(
          child: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  controller = OverlaySheetController.of(context);
                  return TrackChapterControls(
                    player: player,
                    chapters: chapters,
                    chaptersLoaded: true,
                    trackControlsState: state,
                    focusNodes: focusNodes,
                    onNavigateLeft: onNavigateLeft,
                    onNavigateUp: onNavigateUp,
                    onNavigateDown: onNavigateDown,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}
