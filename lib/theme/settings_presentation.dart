import 'package:flutter/material.dart';

import '../utils/platform_detector.dart';
import 'velo_brand.dart';

/// Settings use the final settings.html / appearance.css scale, independently
/// of media titles and the player's HUD. Keep the platform font and text scaler.
abstract final class SettingsPresentation {
  static bool _dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static double get rowHeight => PlatformDetector.isTV() ? 64 : 48;
  static double get rowFontSize => PlatformDetector.isTV() ? 17 : 15;
  static double get rowHorizontalPadding => PlatformDetector.isTV() ? 22 : 17;
  static double get groupRadius => PlatformDetector.isTV() ? 18 : 15;

  static Color surface(BuildContext context) => _dark(context) ? const Color(0xff252530) : const Color(0xfffdfcff);

  static Color muted(BuildContext context) => _dark(context) ? const Color(0xffa6a7b8) : const Color(0xff686b80);
  static Color outline(BuildContext context) => _dark(context) ? const Color(0x12eeebff) : const Color(0x1255506e);
  static Color icon(BuildContext context) => _dark(context) ? const Color(0xffc6c3d5) : const Color(0xff67667b);

  static BoxDecoration groupDecoration(BuildContext context) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: _dark(context)
          ? const [Color(0xff252530), Color(0xff20212a)]
          : const [Color(0xfffefeff), Color(0xfffbfaff)],
    ),
    borderRadius: BorderRadius.circular(groupRadius),
    border: Border.all(color: _dark(context) ? const Color(0x0ceeebff) : const Color(0xb3ffffff)),
    boxShadow: [
      BoxShadow(
        color: _dark(context) ? const Color(0x12000000) : const Color(0x083d3452),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );

  static TextStyle title(BuildContext context) => Theme.of(context).textTheme.bodyMedium!.copyWith(
    fontSize: rowFontSize,
    fontWeight: FontWeight.w400,
    fontVariations: const [FontVariation('wght', 450)],
    height: 1.4,
    letterSpacing: 0,
  );

  static TextStyle description(BuildContext context) => title(context).copyWith(
    fontSize: PlatformDetector.isTV() ? 13 : 12,
    color: muted(context),
    fontVariations: const [FontVariation('wght', 400)],
  );

  static TextStyle value(BuildContext context) =>
      description(context).copyWith(fontSize: PlatformDetector.isTV() ? 14 : 12, color: muted(context));
  static TextStyle section(BuildContext context) => title(context).copyWith(
    fontSize: PlatformDetector.isTV() ? 14 : 12,
    fontWeight: FontWeight.w500,
    letterSpacing: PlatformDetector.isTV() ? .2 : 0,
    color: muted(context),
  );
}

/// Local to settings: changing a list row must not resize media menus or HUDs.
///
/// Only the outermost instance paints the page background. Pages shown inside
/// another settings surface, such as the tablet and TV category pane, keep the
/// row theme without stacking a second opaque panel over the first.
class SettingsAppearance extends StatelessWidget {
  const SettingsAppearance({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nested = context.getInheritedWidgetOfExactType<_SettingsAppearanceScope>() != null;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // Respect an explicitly requested OLED black page.
    final oled = dark && theme.colorScheme.surface == const Color(0xff0a0a0a);
    final background = oled
        ? Colors.black
        : dark
        ? const Color(0xff14151c)
        : const Color(0xffeeeff2);
    final glow = oled
        ? Colors.black
        : dark
        ? const Color(0xff2b283c)
        : const Color(0xfff4efff);
    final tv = PlatformDetector.isTV();
    final themed = _SettingsAppearanceScope(
      child: Theme(
        data: theme.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: theme.appBarTheme.copyWith(backgroundColor: Colors.transparent),
          splashFactory: InkRipple.splashFactory,
          splashColor: VeloBrand.foreground(theme.brightness).withValues(alpha: .16),
          highlightColor: VeloBrand.foreground(theme.brightness).withValues(alpha: .08),
          listTileTheme: ListTileThemeData(
            dense: false,
            minTileHeight: SettingsPresentation.rowHeight,
            titleTextStyle: SettingsPresentation.title(context),
            subtitleTextStyle: SettingsPresentation.description(context),
            contentPadding: EdgeInsets.symmetric(horizontal: tv ? 18 : 13, vertical: tv ? 7 : 2),
            horizontalTitleGap: tv ? 16 : 12,
            minLeadingWidth: tv ? 25 : 19,
            visualDensity: VisualDensity.standard,
            iconColor: SettingsPresentation.icon(context),
          ),
          iconTheme: theme.iconTheme.copyWith(size: tv ? 25 : 19, color: SettingsPresentation.icon(context)),
          focusColor: theme.colorScheme.onSurface.withValues(alpha: tv ? 0.14 : 0.12),
          hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.07),
          sliderTheme: theme.sliderTheme.copyWith(
            trackHeight: tv ? 6 : 4,
            trackGap: 0,
            thumbSize: WidgetStatePropertyAll(Size.square(tv ? 18 : 12)),
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: tv ? 9 : 6),
            trackShape: const RoundedRectSliderTrackShape(),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            overlayShape: RoundSliderOverlayShape(overlayRadius: tv ? 20 : 14),
          ),
          switchTheme: theme.switchTheme.copyWith(
            padding: EdgeInsets.zero,
            trackOutlineWidth: const WidgetStatePropertyAll(1),
            trackOutlineColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return Colors.transparent;
              return states.contains(WidgetState.selected)
                  ? const Color(0x5cddd6ff)
                  : dark
                  ? const Color(0xff60606e)
                  : const Color(0xffbcb9ce);
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              if (states.contains(WidgetState.disabled)) return theme.disabledColor.withValues(alpha: .12);
              return selected
                  ? VeloBrand.accent
                  : dark
                  ? const Color(0xff41424e)
                  : const Color(0xffd4d3df);
            }),
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : theme.brightness == Brightness.dark
                  ? const Color(0xffb0b4bc)
                  : Colors.white,
            ),
          ),
        ),
        child: child,
      ),
    );
    if (nested) return themed;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        gradient: RadialGradient(
          center: const Alignment(-.6, -1.4),
          radius: 1.3,
          colors: [glow, background],
          stops: const [0, .9],
        ),
      ),
      child: themed,
    );
  }
}

class _SettingsAppearanceScope extends InheritedWidget {
  const _SettingsAppearanceScope({required super.child});

  @override
  bool updateShouldNotify(_SettingsAppearanceScope oldWidget) => false;
}
