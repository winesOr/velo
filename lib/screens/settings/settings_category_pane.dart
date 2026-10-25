import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/app_icon.dart';
import '../../widgets/focusable_list_tile.dart';
import '../../focus/key_event_utils.dart';
import '../../focus/dpad_navigator.dart';
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
class SettingsCategoryPane extends StatefulWidget {
  final List<SettingsCategory> categories;
  final VoidCallback? onLeave;

  const SettingsCategoryPane({super.key, required this.categories, this.onLeave});

  @override
  SettingsCategoryPaneState createState() => SettingsCategoryPaneState();
}

class SettingsCategoryPaneState extends State<SettingsCategoryPane> {
  String? _selectedId;
  final _nodes = <String, FocusNode>{};
  final _details = FocusScopeNode(debugLabel: 'settings_category_details');

  FocusNode _node(String id) => _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'settings_category_$id'));

  void focusCategory() {
    final category = widget.categories.where((c) => c.id == _selectedId).firstOrNull ?? widget.categories.first;
    _node(category.id).requestFocus();
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    _details.dispose();
    super.dispose();
  }

  void _enterDetails() {
    _details.requestFocus();
    _details.nextFocus();
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
                        padding: EdgeInsets.only(left: tv ? 14 : 0, bottom: tv ? 24 : 25),
                        child: Text(t.settings.title, style: MonoPresentation.pageTitle(context)),
                      ),
                      for (final item in widget.categories)
                        Focus(
                          canRequestFocus: false,
                          onFocusChange: (focused) {
                            if (focused && category.id != item.id) setState(() => _selectedId = item.id);
                          },
                          child: Padding(
                            padding: EdgeInsets.only(bottom: tv ? 8 : 7),
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
                              child: FocusableListTile(
                                focusNode: _node(item.id),
                                selected: category.id == item.id,
                                contentPadding: EdgeInsets.symmetric(horizontal: tv ? 16 : 13, vertical: tv ? 5 : 4),
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
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted && tv) _enterDetails();
                                  });
                                },
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
                      _node(category.id).requestFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: KeyedSubtree(key: ValueKey(category.id), child: category.builder(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
