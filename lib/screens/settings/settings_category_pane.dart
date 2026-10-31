import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/app_icon.dart';
import '../../widgets/focusable_list_tile.dart';
import '../../widgets/settings_page.dart';
import '../../focus/key_event_utils.dart';
import '../../focus/dpad_navigator.dart';
import '../../focus/input_mode_tracker.dart';
import '../../theme/mono_presentation.dart';
import '../../theme/settings_presentation.dart';
import '../../i18n/strings.g.dart';
import '../../utils/platform_detector.dart';

class SettingsCategory {
  final String id;
  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  const SettingsCategory({required this.id, required this.title, required this.icon, required this.builder});
}

/// Tablet and TV categories share the same settings controls as phones.
/// Explicit left/right handoff avoids traversal jumping to the app's top bar.
///
/// With a remote, focusing a category only previews it. The details stay out
/// of traversal until the category is selected or arrow right is pressed, so
/// pages that focus their first row on build cannot pull focus out of the
/// list while the user moves through it.
class SettingsCategoryPane extends StatefulWidget {
  final List<SettingsCategory> categories;
  final VoidCallback? onLeave;

  const SettingsCategoryPane({super.key, required this.categories, this.onLeave});

  @override
  SettingsCategoryPaneState createState() => SettingsCategoryPaneState();
}

class SettingsCategoryPaneState extends State<SettingsCategoryPane> {
  String? _selectedId;
  bool _detailsActive = false;
  final _nodes = <String, FocusNode>{};
  final _details = FocusScopeNode(debugLabel: 'settings_category_details');

  FocusNode _node(String id) => _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'settings_category_$id'));

  void focusCategory() {
    final category = widget.categories.where((c) => c.id == _selectedId).firstOrNull ?? widget.categories.first;
    if (_detailsActive) setState(() => _detailsActive = false);
    _node(category.id).requestFocus();
  }

  /// Whether the details can take focus. Pointer input reaches them directly.
  bool _detailsFocusable(BuildContext context) => _detailsActive || !InputModeTracker.isKeyboardMode(context);

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    _details.dispose();
    super.dispose();
  }

  void _enterDetails() {
    if (!_detailsActive) setState(() => _detailsActive = true);
    // Wait for the details to rejoin traversal before moving into them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_detailsActive) return;
      _details.requestFocus();
      _details.nextFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.categories.where((c) => c.id == _selectedId).firstOrNull ?? widget.categories.first;
    final tv = PlatformDetector.isTV();
    return SettingsAppearance(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(tv ? 42 : 32, 28, tv ? 42 : 32, tv ? 18 : 100),
          child: Row(
            children: [
              SizedBox(
                width: tv ? 310 : 230,
                child: Focus(
                  canRequestFocus: false,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      _enterDetails();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      widget.onLeave?.call();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: tv ? 14 : 0, bottom: tv ? 18 : 25),
                        child: Text(t.settings.title, style: MonoPresentation.pageTitle(context)),
                      ),
                      for (final item in widget.categories)
                        Focus(
                          canRequestFocus: false,
                          onFocusChange: (focused) {
                            if (!focused || (category.id == item.id && !_detailsActive)) return;
                            setState(() {
                              _selectedId = item.id;
                              _detailsActive = false;
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.only(bottom: tv ? 4 : 7),
                            child: Material(
                              color: category.id == item.id
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(tv ? 16 : 12),
                                side: BorderSide(
                                  color: category.id == item.id
                                      ? SettingsPresentation.outline(context)
                                      : Colors.transparent,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              // TV rows stay compact so the whole category list fits a 540 dp screen.
                              child: ListTileTheme.merge(
                                minTileHeight: tv ? 50 : null,
                                child: FocusableListTile(
                                  focusNode: _node(item.id),
                                  selected: category.id == item.id,
                                  contentPadding: EdgeInsets.symmetric(horizontal: tv ? 16 : 13, vertical: tv ? 2 : 4),
                                  horizontalTitleGap: tv ? 15 : 12,
                                  leading: AppIcon(item.icon, size: tv ? 25 : 24),
                                  title: Text(
                                    item.title,
                                    style: SettingsPresentation.title(context).copyWith(
                                      fontSize: tv ? 16 : 15,
                                      color: category.id == item.id ? Theme.of(context).colorScheme.primary : null,
                                      fontWeight: category.id == item.id ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() => _selectedId = item.id);
                                    if (InputModeTracker.isKeyboardMode(context, listen: false)) _enterDetails();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: tv ? 48 : 24),
              Expanded(
                child: FocusScope(
                  node: _details,
                  onKeyEvent: (_, event) {
                    if (event.logicalKey.isBackKey) return handleBackKeyAction(event, focusCategory);
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      focusCategory();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) {
                      if (!_detailsActive) setState(() => _detailsActive = true);
                    },
                    child: ExcludeFocus(
                      excluding: !_detailsFocusable(context),
                      child: SettingsPaneScope(
                        child: KeyedSubtree(key: ValueKey(category.id), child: category.builder(context)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
