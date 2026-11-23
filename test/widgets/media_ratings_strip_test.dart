import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:plezy/focus/focusable_button.dart';
import 'package:plezy/focus/key_event_utils.dart';
import 'package:plezy/widgets/rating_source_dialog.dart';
import 'package:plezy/widgets/app_dialog.dart';
import 'package:plezy/widgets/app_glass_surface.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_rating.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/widgets/hero_metadata_badges.dart';
import 'package:plezy/widgets/media_ratings_strip.dart';

import '../test_helpers/prefs.dart';

const _scores = [
  MediaRatingSource(source: 'rottenTomatoesCritic', value: 9.2),
  MediaRatingSource(source: 'rottenTomatoesAudience', value: 8.8),
  MediaRatingSource(source: 'imdb', value: 8.1),
  MediaRatingSource(source: 'tmdb', value: 7.9),
  MediaRatingSource(source: 'simkl', value: 8.2),
];

MediaItem _item(List<MediaRatingSource> ratings) => MediaItem.plex(
  id: 'movie',
  kind: MediaKind.movie,
  title: 'A very long title that never displaces a rating',
  ratings: ratings,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  Brightness brightness = Brightness.dark,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        navigatorObservers: [BackKeySuppressorObserver()],
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Center(child: SizedBox(width: 320, child: child)),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // Locale is constant for this fixture; initialize before any provider mounts.
  // Reassigning it per test schedules slang updates on the departing provider.
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.en));
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
  });

  for (final count in [0, 1, 2, 5]) {
    testWidgets('$count source detail has a stable maximum of four external scores', (tester) async {
      await _pump(tester, MediaRatingsStrip(item: _item(_scores.take(count).toList())));
      expect(find.text('92%'), count == 0 ? findsNothing : findsOneWidget);
      expect(find.text('8.2'), findsNothing);
      if (count == 0) expect(tester.getSize(find.byType(MediaRatingsStrip)).height, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('rating dialog uses its own readable colors over artwork with a ${dark ? 'dark' : 'light'} app', (
      tester,
    ) async {
      final base = monoTheme(dark: dark);
      final pageInk = dark ? Colors.black : Colors.white;
      final art = dark ? Colors.white : const Color(0xff564572);
      final session = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: base,
            home: Theme(
              data: base.copyWith(
                colorScheme: base.colorScheme.copyWith(
                  surface: art,
                  onSurface: pageInk,
                  onSurfaceVariant: pageInk,
                  primary: pageInk,
                ),
                textTheme: base.textTheme.apply(bodyColor: pageInk, displayColor: pageInk),
              ),
              // Even a nested profile navigator rooted in artwork owns its dialog.
              child: Navigator(
                key: session,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: MediaRatingsStrip(item: _item(const [MediaRatingSource(source: 'audience', value: 8.1)])),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('8.1'));
      await tester.pumpAndSettle();
      final dialog = find.byType(RatingSourceDialog);
      expect(session.currentState!.canPop(), isTrue);
      final glass = find.descendant(of: dialog, matching: find.byType(AppGlassSurface));
      final panel = tester.widget<Material>(find.descendant(of: glass, matching: find.byType(Material)).first);
      final bg = Color.alphaBlend(panel.color!, art);
      double contrast(Color ink, Color background) {
        final a = Color.alphaBlend(ink, background).computeLuminance();
        final b = background.computeLuminance();
        return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
      }

      final description = t.ratingDetails.serverExplanation(
        source: t.ratingDetails.sourceUnspecified,
        scale: t.ratingDetails.tenPointScale,
      );
      for (final label in [
        t.ratingDetails.title,
        t.ratingDetails.explanation,
        t.common.ratingSource.audience,
        '8.1/10',
        description,
        t.common.close,
      ]) {
        final text = find.descendant(of: dialog, matching: find.text(label));
        final ink = tester.renderObject<RenderParagraph>(text).text.style!.color!;
        expect(contrast(ink, bg), greaterThanOrEqualTo(4.5), reason: label);
      }
      final close = tester.widget<IconButton>(
        find.descendant(of: find.byType(AppDialogCloseButton), matching: find.byType(IconButton)),
      );
      final buttonBg = Color.alphaBlend(close.style!.backgroundColor!.resolve({})!, bg);
      expect(contrast(close.style!.foregroundColor!.resolve({})!, buttonBg), greaterThanOrEqualTo(3));
      await tester.tap(find.byType(AppDialogCloseButton));
      await tester.pumpAndSettle();
      expect(session.currentState!.canPop(), isFalse);
      expect(dialog, findsNothing);
    });
  }

  testWidgets('detail ignores the poster switch and collapses items with only a personal score', (tester) async {
    await SettingsService.instance.write(SettingsService.showRatingBadges, false);
    final personalOnly = _item(const [MediaRatingSource(source: 'personal', value: 9.5)]).copyWith(userRating: 9.5);
    await _pump(tester, MediaRatingsStrip(item: personalOnly));
    expect(tester.getSize(find.byType(MediaRatingsStrip)).height, 0);

    final public = personalOnly.copyWith(ratings: const [MediaRatingSource(source: 'audience', value: 8.1)]);
    await _pump(tester, MediaRatingsStrip(item: public));
    expect(find.text('8.1'), findsOneWidget);
    expect(find.text(t.common.ratingSource.audience), findsOneWidget);
    expect(find.text('9.5'), findsNothing);
  });

  testWidgets('the strip only occupies the rows required by its visible sources', (tester) async {
    await _pump(tester, MediaRatingsStrip(item: _item([_scores.first])));
    final height = tester.getSize(find.byType(MediaRatingsStrip)).height;
    expect(height, 48);
    await _pump(tester, MediaRatingsStrip(item: _item(_scores)));
    expect(tester.getSize(find.byType(MediaRatingsStrip)).height, height * 2);
  });

  testWidgets('compact inline style centres one row of 13px scores with 14px gaps and no dividers or captions', (
    tester,
  ) async {
    await _pump(tester, MediaRatingsStrip(item: _item(_scores.take(3).toList()), compact: true));
    final texts = ['92%', '88%', '8.1'];
    final rects = texts.map((s) => tester.getRect(find.text(s))).toList();
    expect(rects.map((r) => r.center.dy).toSet().length, 1, reason: 'one row');
    for (final s in texts) {
      final style = tester.widget<Text>(find.text(s)).style!;
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w400);
    }
    expect(
      find
          .byType(DecoratedBox)
          .evaluate()
          .where(
            (e) =>
                (e.widget as DecoratedBox).decoration is BoxDecoration &&
                ((e.widget as DecoratedBox).decoration as BoxDecoration).border != null,
          ),
      isEmpty,
    );
    expect(find.text(t.ratingDetails.serverRating), findsNothing);
    final strip = tester.getRect(find.byType(MediaRatingsStrip));
    final row = rects.first.expandToInclude(rects.last);
    expect(row.center.dx, closeTo(strip.center.dx, 2));
  });

  testWidgets('four compact public scores fit on a 390px phone and wrap with large text', (tester) async {
    final strip = MediaRatingsStrip(item: _item(_scores), showSourceLabels: false);
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(width: 390 - 2 * 24, child: strip),
                ),
              ),
            ),
          ),
        ),
      );
      final cells = ['92%', '88%', '8.1', '79%'].map((s) => tester.getRect(find.text(s))).toList();
      expect(find.text('8.2'), findsNothing);
      if (scale == 1) {
        expect(cells.last.center.dy, closeTo(cells.first.center.dy, 1));
      } else {
        expect(cells.last.center.dy, greaterThan(cells.first.center.dy));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('320px at 200% text stays readable in bright and dark themes', (tester) async {
    for (final brightness in Brightness.values) {
      await _pump(tester, MediaRatingsStrip(item: _item(_scores)), scale: 2, brightness: brightness);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('79%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('source preference changes rebuild an already visible detail region', (tester) async {
    await _pump(tester, MediaRatingsStrip(item: _item(_scores)));
    await SettingsService.instance.write(SettingsService.disabledRatingSources, ['rottenTomatoesCritic']);
    await tester.pump();
    expect(find.text('92%'), findsNothing);
    expect(find.text('8.2'), findsOneWidget);
    await SettingsService.instance.write(
      SettingsService.disabledRatingSources,
      _scores.map((score) => score.source).toList(),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(MediaRatingsStrip)).height, 0);
  });

  testWidgets('unknown source is labeled neutrally rather than exposing the key', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      MediaRatingsStrip(item: _item(const [MediaRatingSource(source: 'internal.future.rating', value: 7.2)])),
    );
    expect(find.text('Other ratings'), findsNothing);
    expect(find.bySemanticsLabel('${t.ratingDetails.unattributedSource} 7.2/10'), findsOneWidget);
    expect(find.textContaining('internal.future'), findsNothing);
    semantics.dispose();
  });

  testWidgets('detail score opens sources and returns focus without moving the scroll position', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          navigatorObservers: [BackKeySuppressorObserver()],
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 500),
                  MediaRatingsStrip(item: _item(_scores), firstFocusNode: focus),
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.jumpTo(400);
    await tester.pump();
    focus.requestFocus();
    await tester.pump();
    final offset = controller.offset;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(RatingSourceDialog), findsOneWidget);
    expect(find.text(t.common.ratingSource.simkl), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(RatingSourceDialog), findsNothing);
    expect(focus.hasFocus, isTrue);
    expect(controller.offset, offset);
  });

  testWidgets('hero rating sources own clicks, scroll, close one layer and restore focus', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var plays = 0;
    await _pump(
      tester,
      GestureDetector(
        onTap: () => plays++,
        child: HeroMetadataBadges(item: _item(_scores)),
      ),
    );
    final trigger = find.byKey(const ValueKey('hero-rating-sources'));
    final button = tester.widget<FocusableButton>(find.descendant(of: trigger, matching: find.byType(FocusableButton)));
    final returnFocus = button.focusNode!;
    await tester.tap(find.text('9.2'));
    await tester.pumpAndSettle();
    expect(plays, 0);
    expect(find.byType(RatingSourceDialog), findsOneWidget);
    expect(find.text(t.common.ratingSource.simkl), findsOneWidget);
    expect(find.text('79%'), findsOneWidget);
    expect(tester.getBottomLeft(find.text(t.common.close)).dy, lessThanOrEqualTo(568));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: find.byType(RatingSourceDialog), matching: find.byType(Scrollable)),
    );
    expect(scroll.position.pixels, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(RatingSourceDialog), findsNothing);
    expect(returnFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(RatingSourceDialog), findsOneWidget);
    final nested = showDialog<void>(
      context: tester.element(find.byType(RatingSourceDialog)),
      builder: (_) => const AlertDialog(content: Text('Nested dialog')),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await nested;
    expect(find.byType(RatingSourceDialog), findsOneWidget);
    await tester.tap(find.text(t.common.close));
    await tester.pumpAndSettle();
    expect(returnFocus.hasFocus, isTrue);
    final unknown = showRatingSourceDialog(tester.element(trigger), const [
      MediaRatingSource(source: 'internal.future.rating', value: 7.2),
      MediaRatingSource(source: 'personal', value: 8),
      MediaRatingSource(source: 'imdb', value: 0),
    ]);
    await tester.pumpAndSettle();
    expect(find.text(t.ratingDetails.serverRating), findsOneWidget);
    expect(find.text(t.explore.detail.yourRating), findsNothing);
    expect(find.text('8.0/10'), findsNothing);
    expect(find.textContaining('internal.future'), findsNothing);
    expect(find.text('0.0/10'), findsNothing);
    await tester.tap(find.text(t.common.close));
    await tester.pumpAndSettle();
    await unknown;
    await _pump(tester, HeroMetadataBadges(item: _item(const [])));
    expect(find.byKey(const ValueKey('hero-rating-sources')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('homepage shows one enabled score and reacts to ordering', (tester) async {
    await _pump(tester, HeroMetadataBadges(item: _item(_scores)));
    expect(find.text('9.2'), findsOneWidget);
    expect(find.text('88%'), findsNothing);
    expect(find.text('8.1'), findsNothing);
    await SettingsService.instance.write(SettingsService.ratingSourceOrder, ['imdb', 'tmdb']);
    await tester.pump();
    expect(find.text('8.1'), findsOneWidget);
    expect(find.text('79%'), findsNothing);
    expect(find.text('92%'), findsNothing);
  });
}
