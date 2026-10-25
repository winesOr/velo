import 'package:flutter/material.dart';

import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/app_icon.dart';
import '../../../widgets/bottom_sheet_page_scaffold.dart';

/// Base class for video control bottom sheets providing common UI structure
class BaseVideoControlSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? iconColor;
  final VoidCallback? onBack;

  /// Inside the player drawer the tab bar is the header: only a back row is
  /// shown, on nested pages.
  static bool embeddedIn(BuildContext context) => _EmbeddedSheetScope.of(context);

  const BaseVideoControlSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (embeddedIn(context)) {
      final back = onBack;
      if (back == null) return child;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 12, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: back,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const AppIcon(Symbols.arrow_back_rounded, size: 20),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: child),
        ],
      );
    }
    return BottomSheetPageScaffold(
      title: title,
      icon: icon,
      iconColor: iconColor,
      onBack: onBack,
      titleStyle: const TextStyle(fontSize: 18, fontWeight: .bold),
      showHeaderBorder: false,
      showHeaderDivider: true,
      child: child,
    );
  }
}

/// Marks a subtree as hosted inside the player drawer.
class EmbeddedVideoControlSheet extends StatelessWidget {
  const EmbeddedVideoControlSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _EmbeddedSheetScope(child: child);
}

class _EmbeddedSheetScope extends InheritedWidget {
  const _EmbeddedSheetScope({required super.child});

  static bool of(BuildContext context) => context.getInheritedWidgetOfExactType<_EmbeddedSheetScope>() != null;

  @override
  bool updateShouldNotify(_EmbeddedSheetScope oldWidget) => false;
}
