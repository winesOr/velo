import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/card_focus_scope.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/focus/locked_hub_controller.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_hub.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/widgets/media_card.dart';
import 'package:plezy/widgets/tv_browse_rail.dart';
import 'package:provider/provider.dart';

import '../test_helpers/prefs.dart';
import '../test_helpers/media_items.dart';
import '../test_helpers/multi_server_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HubFocusMemory focusMemory;

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    focusMemory = HubFocusMemory();
    await SettingsService.getInstance();
  });

  testWidgets('full card focus adds outside ring, local glow, and card image scale', (tester) async {
    await SettingsService.instanceOrNull!.write(SettingsService.tvFullCardLayout, true);

    TvDetectionService.debugSetAppleTVOverride(true);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(() {
      TvDetectionService.debugSetAppleTVOverride(null);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final serverManager = MultiServerManager();
    final movie = testMediaItem(id: 'movie_1', backend: MediaBackend.plex, kind: MediaKind.movie, title: 'Movie');
    final hub = MediaHub(id: 'movies', title: 'Movies', type: 'movie', items: [movie], size: 1);

    await tester.pumpWidget(
      ChangeNotifierProvider<MultiServerProvider>(
        create: (_) => testMultiServerProvider(serverManager),
        child: InputModeTracker(
          child: MaterialApp(
            theme: monoTheme(dark: true),
            home: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 720,
                child: TvBrowseRail(
                  focusMemory: focusMemory,
                  hubs: [hub],
                  autofocus: true,
                  iconForHub: (_, _) => Icons.movie_rounded,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final scale = TvBrowseRailLayout.scaleForSize(tester.view.physicalSize / tester.view.devicePixelRatio);
    final metrics = TvBrowseRailLayout.metricsForHub(
      minLabelHeight: _railLabelHeight(tester),
      hub: hub,
      availableWidth: 1280 - TvBrowseRailLayout.horizontalInsetForScale(scale),
      density: LibraryDensity.defaultValue,
      episodePosterMode: EpisodePosterMode.seriesPoster,
      scale: scale,
      fullCardLayout: true,
    );

    // Focus wrappers delegate the stroke to the poster's CardFocusBorder;
    // the outer animated container only owns scale/glow placement.
    final borderOwner = find.descendant(
      of: find.byType(CompositedTransformTarget),
      matching: find.byType(CardFocusBorder),
    );
    expect(borderOwner, findsOneWidget);
    expect(CardFocusScope.maybeOf(tester.element(borderOwner)), isTrue);
    final cardFinder = find.descendant(of: borderOwner, matching: find.byType(AnimatedContainer)).first;
    final borderContainer = tester.widget<AnimatedContainer>(cardFinder);
    final border = (borderContainer.foregroundDecoration as BoxDecoration).border as Border;
    final cardSize = tester.getSize(cardFinder);
    // Press feedback adds its own inner scale; the focus scale wraps the glow
    // leader and must be asserted independently of an inactive press animation.
    final focusScale = tester.widget<AnimatedScale>(
      find.ancestor(of: find.byType(CompositedTransformTarget), matching: find.byType(AnimatedScale)).first,
    );

    // The border stays in-card; the glow now renders in an overlay that follows
    // the focused card so it paints above siblings on all sides.
    expect(borderContainer.decoration, isNull);
    expect(border.top.strokeAlign, BorderSide.strokeAlignOutside);
    expect(border.top.width, 2.5);
    expect(border.top.color.a, greaterThan(0));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(CompositedTransformTarget), findsOneWidget);
    expect(find.byType(CompositedTransformFollower), findsOneWidget);
    expect(
      find.descendant(of: find.byType(CompositedTransformFollower), matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(focusScale.scale, closeTo(1.03, 0.0001));
    expect(cardSize.width, closeTo(metrics.cardWidth, 0.001));
    expect(cardSize.height, closeTo(metrics.posterHeight, 0.001));
  });
}

/// Caption band the mounted rail reserves below each poster.
double _railLabelHeight(WidgetTester tester) =>
    MediaCard.gridLabelHeight(tester.element(find.byType(TvBrowseRail).first));
