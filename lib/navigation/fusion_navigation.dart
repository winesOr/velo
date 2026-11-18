import 'dart:ui';

import 'package:flutter/material.dart';
import '../focus/focusable_button.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_toast.dart';
import '../theme/mono_presentation.dart';
import '../theme/velo_brand.dart';
import '../theme/interaction_tokens.dart';
import '../utils/selection_feedback.dart';
import '../widgets/app_glass_surface.dart';
import '../widgets/press_feedback.dart';
import 'home_theme.dart';
import 'navigation_tabs.dart';

/// Shared destinations; only the orientation and search affordance differ.
class FusionNavigation extends StatelessWidget {
  const FusionNavigation({
    super.key,
    required this.tabs,
    required this.selectedTab,
    required this.onSelected,
    this.isTv = false,
    this.showLabels = true,
    this.focusNodes = const {},
    this.onNavigateDown,
    this.onLibrariesLongPress,
  });

  final List<NavigationTab> tabs;
  final NavigationTabId selectedTab;
  final ValueChanged<NavigationTabId> onSelected;
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
    final color = HomeThemeScope.colorOf(context);
    final brightness = _brightness(context);
    final dark = brightness == Brightness.dark;
    final reduced = AppGlassSurface.reduceEffects(context);
    final navigationBody = AnimatedContainer(
      key: const ValueKey('fusion-navigation-surface'),
      duration: Duration.zero,
      constraints: BoxConstraints(
        minHeight: isTv ? 0 : MonoPresentation.navigationHeight,
        maxWidth: isTv ? 440 : MonoPresentation.navigationMaxWidth,
      ),
      padding: isTv ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4) : const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: MonoPresentation.navigationSurface(
          brightness,
          artwork: !isTv && selectedTab == NavigationTabId.discover ? color : null,
          alpha: reduced
              ? 1
              : isTv
              ? (dark ? .91 : .94)
              : .88,
        ),
        borderRadius: BorderRadius.circular(isTv ? 24 : 30),
        border: Border.all(color: dark ? const Color(0x40ffffff) : const Color(0x3d242c3b)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final tab in primary) Expanded(child: _destination(context, tab))],
        ),
      ),
    );
    final anchoredBody = isTv ? AppToastAnchor(child: navigationBody) : navigationBody;
    return SafeArea(
      top: isTv,
      bottom: !isTv,
      minimum: EdgeInsets.symmetric(horizontal: isTv ? 28 : 16, vertical: 18),
      child: Center(
        heightFactor: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isTv ? 24 : 30),
          child: reduced
              ? anchoredBody
              : BackdropFilter(filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28), child: anchoredBody),
        ),
      ),
    );
  }

  Widget _destination(BuildContext context, NavigationTab tab) {
    final selected = selectedTab == tab.id;
    final brightness = _brightness(context);
    final dark = brightness == Brightness.dark;
    final foreground = selected ? VeloBrand.foreground(brightness) : MonoPresentation.navigationForeground(brightness);
    final focusColor = dark ? Colors.white : const Color(0xff46526b);
    return Semantics(
      selected: selected,
      button: true,
      label: tab.getLabel(),
      child: PressFeedbackBuilder(
        pressedScale: InteractionTokens.navigationPressedScale,
        borderRadius: BorderRadius.circular(isTv ? 20 : 26),
        builder: (context, setPressed, confirm) => FocusableButton(
          focusNode: focusNodes[tab.id],
          onPressed: () {
            confirm();
            _select(tab.id);
          },
          onNavigateDown: onNavigateDown,
          focusColor: isTv ? focusColor : null,
          dimWhenUnfocused: !isTv,
          child: GestureDetector(
            onTap: () => _select(tab.id),
            onTapDown: (_) => setPressed(true),
            onTapUp: (_) => setPressed(false),
            onTapCancel: () => setPressed(false),
            onLongPress: tab.id == NavigationTabId.libraries ? onLibrariesLongPress : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: isTv
                  ? const BoxConstraints(minHeight: 35, minWidth: 54, maxWidth: 136)
                  : const BoxConstraints(minHeight: 48),
              padding: EdgeInsets.symmetric(horizontal: isTv ? 12 : 2),
              decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(isTv ? 20 : 26)),
              child: isTv
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [_icon(tab, foreground), const SizedBox(width: 7), _label(tab, foreground)],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _icon(tab, foreground),
                        if (showLabels) ...[const SizedBox(height: 2), _label(tab, foreground)],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon(NavigationTab tab, Color color) => AppIcon(
    tab.icon,
    size: isTv ? 17 : 22,
    color: color,
    fill: selectedTab == tab.id ? 1 : 0,
    weight: selectedTab == tab.id ? 500 : 400,
  );

  Widget _label(NavigationTab tab, Color color) => Text(
    tab.getLabel(),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: TextStyle(color: color, fontSize: isTv ? 12 : 10, fontWeight: FontWeight.w500, height: 1.2),
  );
}
