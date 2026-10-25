import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../focus/focusable_button.dart';
import '../i18n/strings.g.dart';
import '../widgets/app_icon.dart';
import '../theme/mono_presentation.dart';
import '../theme/velo_brand.dart';
import '../utils/selection_feedback.dart';
import 'home_theme.dart';
import 'navigation_tabs.dart';

/// Shared destinations; only the orientation and search affordance differ.
class FusionNavigation extends StatelessWidget {
  const FusionNavigation({
    super.key,
    required this.tabs,
    required this.selectedTab,
    required this.onSelected,
    required this.onSecondary,
    this.isTv = false,
    this.showLabels = true,
    this.focusNodes = const {},
    this.onNavigateDown,
    this.onLibrariesLongPress,
  });

  final List<NavigationTab> tabs;
  final NavigationTabId selectedTab;
  final ValueChanged<NavigationTabId> onSelected;
  final VoidCallback onSecondary;
  final bool isTv;
  final bool showLabels;
  final Map<NavigationTabId, FocusNode> focusNodes;
  final VoidCallback? onNavigateDown;
  final VoidCallback? onLibrariesLongPress;

  Brightness _brightness(BuildContext context) => Theme.of(context).brightness;

  void _select(NavigationTabId id) {
    if (!isTv && id != selectedTab) selectionFeedback();
    onSelected(id);
  }

  @override
  Widget build(BuildContext context) {
    final primary = tabs.any((tab) => tab.id == NavigationTabId.discover) ? primaryNavigationTabs(tabs) : tabs.toList();
    if (isTv) {
      primary.insertAll(primary.isNotEmpty ? primary.length - 1 : 0, tabs.where((t) => t.id == NavigationTabId.search));
    }
    final color = HomeThemeScope.colorOf(context);
    final brightness = _brightness(context);
    final dark = brightness == Brightness.dark;
    return SafeArea(
      top: isTv,
      bottom: !isTv,
      minimum: EdgeInsets.symmetric(horizontal: isTv ? 32 : 21, vertical: isTv ? 18 : 18),
      child: Center(
        heightFactor: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isTv ? 24 : 30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: AnimatedContainer(
              // The scope already supplies the interpolated color. A second
              // implicit animation here would lag behind the page background.
              duration: Duration.zero,
              constraints: BoxConstraints(maxWidth: isTv ? 680 : MonoPresentation.navigationMaxWidth),
              padding: isTv ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4) : const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: MonoPresentation.navigationSurface(
                  brightness,
                  artwork: !isTv && selectedTab == NavigationTabId.discover ? color : null,
                  alpha: isTv ? (dark ? .91 : .94) : .94,
                ),
                borderRadius: BorderRadius.circular(isTv ? 24 : 30),
                border: Border.all(
                  color: dark ? const Color(0x40ffffff) : const Color(0x3d242c3b),
                  width: isTv ? 1 : 1,
                ),
                boxShadow: null,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: isTv
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [for (final tab in primary) _destination(context, tab), _options(context)],
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [for (final tab in primary) Expanded(child: _destination(context, tab))],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(BuildContext context, NavigationTab tab) {
    final selected = selectedTab == tab.id;
    final brightness = _brightness(context);
    final dark = brightness == Brightness.dark;
    final foreground = selected
        ? VeloBrand.foreground(brightness)
        : selectedTab == NavigationTabId.discover && dark
        ? Colors.white
        : MonoPresentation.navigationForeground(brightness);
    final focusColor = dark ? Colors.white : const Color(0xff46526b);
    return Semantics(
      selected: selected,
      button: true,
      label: tab.getLabel(),
      child: FocusableButton(
        focusNode: focusNodes[tab.id],
        onPressed: () => _select(tab.id),
        onNavigateDown: onNavigateDown,
        focusColor: isTv ? focusColor : null,
        dimWhenUnfocused: !isTv,
        child: GestureDetector(
          onTap: () => _select(tab.id),
          onLongPress: tab.id == NavigationTabId.libraries ? onLibrariesLongPress : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: isTv ? 35 : null,
            constraints: isTv ? const BoxConstraints(minWidth: 54, maxWidth: 136) : const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(horizontal: isTv ? 12 : 2, vertical: isTv ? 0 : 4),
            decoration: BoxDecoration(
              color: selected ? VeloBrand.selection(brightness) : Colors.transparent,
              borderRadius: BorderRadius.circular(isTv ? 20 : 26),
              border: selected
                  ? Border.all(color: dark ? const Color(0x1cffffff) : const Color(0x20242d3b), width: 1)
                  : null,
            ),
            child: isTv
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          tab.icon,
                          size: 17,
                          color: foreground,
                          fill: selected ? 1 : 0,
                          weight: selected ? 500 : 400,
                        ),
                        const SizedBox(width: 7),
                        _label(tab, foreground),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(tab.icon, size: 22, color: foreground, fill: 0, weight: selected ? 500 : 400),
                      if (showLabels) ...[const SizedBox(height: 2), _label(tab, foreground)],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _options(BuildContext context) {
    final brightness = _brightness(context);
    final dark = brightness == Brightness.dark;
    final foreground = MonoPresentation.navigationForeground(brightness);
    return FocusableButton(
      onPressed: onSecondary,
      onNavigateDown: onNavigateDown,
      focusColor: dark ? Colors.white : const Color(0xff46526b),
      dimWhenUnfocused: false,
      child: Container(
        width: 35,
        height: 35,
        alignment: Alignment.center,
        child: IconButton(
          tooltip: t.common.options,
          onPressed: onSecondary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 35, height: 35),
          icon: AppIcon(Symbols.more_horiz_rounded, size: 18, color: foreground),
        ),
      ),
    );
  }

  Widget _label(NavigationTab tab, Color color) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.3,
    child: Text(
      tab.getLabel(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: isTv ? 12 : 10, fontWeight: FontWeight.w500, height: 1.2),
    ),
  );
}
