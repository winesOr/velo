import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/navigation/navigation_tabs.dart';

void main() {
  group('NavigationTab.resolveDefaultTab', () {
    test('offline prefers Downloads when available', () {
      expect(
        NavigationTab.resolveDefaultTab(isOffline: true, hasLiveTv: false, preferredStartup: null),
        NavigationTabId.downloads,
      );
    });

    test('offline ignores an online-only preferred section', () {
      expect(
        NavigationTab.resolveDefaultTab(isOffline: true, hasLiveTv: true, preferredStartup: NavigationTabId.liveTv),
        NavigationTabId.downloads,
      );
    });

    test('online honours the preferred section when it is visible', () {
      expect(
        NavigationTab.resolveDefaultTab(isOffline: false, hasLiveTv: true, preferredStartup: NavigationTabId.liveTv),
        NavigationTabId.liveTv,
      );
      expect(
        NavigationTab.resolveDefaultTab(isOffline: false, hasLiveTv: false, preferredStartup: NavigationTabId.search),
        NavigationTabId.libraries,
      );
    });

    test('online falls back to Home when preferred Live TV is unavailable', () {
      expect(
        NavigationTab.resolveDefaultTab(isOffline: false, hasLiveTv: false, preferredStartup: NavigationTabId.liveTv),
        NavigationTabId.discover,
      );
    });

    test('online defaults to Home when no preference is set', () {
      expect(
        NavigationTab.resolveDefaultTab(isOffline: false, hasLiveTv: true, preferredStartup: null),
        NavigationTabId.discover,
      );
    });

    test('online falls back to Home when preferred Explore is unavailable', () {
      expect(
        NavigationTab.resolveDefaultTab(isOffline: false, hasLiveTv: false, preferredStartup: NavigationTabId.explore),
        NavigationTabId.discover,
      );
      expect(
        NavigationTab.resolveDefaultTab(
          isOffline: false,
          hasLiveTv: false,
          hasExplore: true,
          preferredStartup: NavigationTabId.explore,
        ),
        NavigationTabId.explore,
      );
    });
  });

  group('NavigationTab.getVisibleTabs', () {
    test('hides Explore until a catalog source is connected', () {
      final without = NavigationTab.getVisibleTabs(isOffline: false);
      expect(without.map((tab) => tab.id), isNot(contains(NavigationTabId.explore)));

      final with_ = NavigationTab.getVisibleTabs(isOffline: false, hasExplore: true, hasLiveTv: true);
      final ids = with_.map((tab) => tab.id).toList();
      expect(ids, contains(NavigationTabId.explore));
      // Explore sits after Live TV, directly before Search.
      expect(ids.indexOf(NavigationTabId.explore), ids.indexOf(NavigationTabId.liveTv) + 1);
      expect(ids, isNot(contains(NavigationTabId.search)));
    });

    test('Explore is online-only', () {
      final offline = NavigationTab.getVisibleTabs(isOffline: true, hasExplore: true);
      expect(offline.map((tab) => tab.id), isNot(contains(NavigationTabId.explore)));
    });
  });

  group('Favorites navigation', () {
    test('Favorites replaces Libraries as the second primary destination', () {
      expect(primaryNavigationIds, [
        NavigationTabId.discover,
        NavigationTabId.favorites,
        NavigationTabId.together,
        NavigationTabId.settings,
      ]);
      final tabs = NavigationTab.getVisibleTabs(isOffline: false);
      final favorites = tabs.firstWhere((tab) => tab.id == NavigationTabId.favorites);
      expect(favorites.icon, Symbols.favorite_rounded);
      expect(
        NavigationTab.getVisibleTabs(isOffline: true).map((tab) => tab.id),
        isNot(contains(NavigationTabId.favorites)),
      );
    });

    test('Libraries is reached through search, not the overflow menu', () {
      final overflow = secondaryNavigationTabs(NavigationTab.getVisibleTabs(isOffline: false, hasLiveTv: true));
      expect(overflow.map((tab) => tab.id), isNot(contains(NavigationTabId.libraries)));
      expect(overflow.map((tab) => tab.id), isNot(contains(NavigationTabId.favorites)));
    });

    test('a stored Libraries startup preference still resolves', () {
      expect(
        NavigationTab.resolveDefaultTab(
          isOffline: false,
          hasLiveTv: false,
          preferredStartup: NavigationTabId.libraries,
        ),
        NavigationTabId.libraries,
      );
    });

    test('the new id is appended so stored enum names stay stable', () {
      expect(NavigationTabId.values.last, NavigationTabId.favorites);
      expect(NavigationTabId.values.byName('libraries'), NavigationTabId.libraries);
    });
  });
}
