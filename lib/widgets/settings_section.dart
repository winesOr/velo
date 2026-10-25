import 'package:flutter/material.dart';
import '../theme/settings_presentation.dart';
import '../utils/platform_detector.dart';
import 'app_icon.dart';
import 'expressive_button_group.dart';

/// Standard settings-option title style, for group children that are not a
/// [ListTile] (segmented controls, sliders) and so don't inherit its
/// typography.
///
TextStyle? settingsOptionTitleStyle(BuildContext context) => SettingsPresentation.title(context);

class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final tv = PlatformDetector.isTV();
    return Padding(
      padding: tv
          ? EdgeInsets.fromLTRB(
              SettingsPresentation.rowHorizontalPadding + 12,
              30,
              SettingsPresentation.rowHorizontalPadding + 12,
              11,
            )
          : const EdgeInsets.fromLTRB(16, 18, 16, 7),
      child: Text(title, style: SettingsPresentation.section(context)),
    );
  }
}

/// Connected settings rows share a quiet surface and fine separators.
/// Focus and ink remain owned by each row; the group adds no traversal nodes.
///
/// Exclude conditional tiles from the child list so separators only appear
/// between visible rows.
///
/// One rounded material clips the native ink focus/hover
/// highlight inside the connected card — that is the d-pad focus visual
/// (background focus). The group adds no [Focus] nodes of its own; traversal
/// order and externally-owned tile focus nodes are untouched.
///
/// Children inherit the compact row geometry the `Focusable*ListTile`s default
/// to, so a plain [ListTile] used as a non-interactive info row lines up with
/// its interactive siblings instead of standing 11px taller.
class SettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SettingsGroup({
    super.key,
    this.title,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final tv = PlatformDetector.isTV();
    return Column(
      crossAxisAlignment: .start,
      children: [
        if (title != null) SettingsSectionHeader(title!),
        Padding(
          padding: margin == EdgeInsets.zero && tv
              ? EdgeInsets.symmetric(horizontal: SettingsPresentation.rowHorizontalPadding)
              : margin,
          child: DecoratedBox(
            decoration: SettingsPresentation.groupDecoration(context),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(SettingsPresentation.groupRadius),
              child: ListTileTheme(
                data: ListTileThemeData(
                  dense: false,
                  titleTextStyle: SettingsPresentation.title(context),
                  subtitleTextStyle: SettingsPresentation.description(context),
                  minTileHeight: SettingsPresentation.rowHeight,
                  minVerticalPadding: 4,
                  contentPadding: EdgeInsets.symmetric(horizontal: tv ? 18 : 13, vertical: tv ? 4 : 0),
                  horizontalTitleGap: tv ? 16 : 12,
                  minLeadingWidth: tv ? 25 : 19,
                  visualDensity: VisualDensity.standard,
                  iconColor: SettingsPresentation.icon(context),
                ),
                child: IconTheme.merge(
                  data: IconThemeData(size: tv ? 25 : 19, color: SettingsPresentation.icon(context)),
                  child: Column(
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: .5,
                            indent: 13,
                            endIndent: 13,
                            color: SettingsPresentation.outline(context),
                          ),
                        children[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A setting with a label + icon row and a full-width button group below.
/// Used for settings with 2-3 short options.
class SegmentedSetting<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const SegmentedSetting({
    super.key,
    required this.icon,
    required this.title,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              AppIcon(icon, fill: 1),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: settingsOptionTitleStyle(context))),
            ],
          ),
          const SizedBox(height: 12),
          ExpressiveButtonGroup<T>(segments: segments, selected: selected, onChanged: onChanged),
        ],
      ),
    );
  }
}
