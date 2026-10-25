import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/focus/input_mode_tracker.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/theme/mono_presentation.dart';
import 'package:plezy/widgets/desktop_app_bar.dart';
import 'package:plezy/widgets/focused_scroll_scaffold.dart';

class _BouncingScroll extends MaterialScrollBehavior {
  const _BouncingScroll();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('fixed ${dark ? 'dark' : 'light'} page header remains still during overscroll and content scrolling', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 32);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        InputModeTracker(
          child: MaterialApp(
            theme: monoTheme(dark: dark),
            home: ScrollConfiguration(
              behavior: const _BouncingScroll(),
              child: FocusedScrollScaffold(
                title: const Text('Preferences'),
                contentTopPadding: 16,
                slivers: [SliverList.builder(itemCount: 60, itemBuilder: (_, i) => ListTile(title: Text('Row $i')))],
              ),
            ),
          ),
        ),
      );
      final initial = tester.getRect(find.byType(DesktopPageAppBar));
      expect(tester.getTopLeft(find.text('Preferences')).dy, greaterThanOrEqualTo(32));
      expect(tester.getTopLeft(find.text('Row 0')).dy, greaterThanOrEqualTo(initial.bottom + 16));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(CustomScrollView)));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      expect(tester.getRect(find.byType(DesktopPageAppBar)), initial);
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(DesktopPageAppBar)), initial);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, MonoPresentation.headerSurface(tester.element(find.byType(AppBar))));
      expect(appBar.backgroundColor, isNot(monoTheme(dark: dark).scaffoldBackgroundColor));
      expect(tester.takeException(), isNull);
    });
  }
}
