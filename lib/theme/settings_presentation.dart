import 'package:flutter/material.dart';

import '../utils/platform_detector.dart';
import 'velo_brand.dart';

/// Settings use the final settings.html / appearance.css scale, independently
/// of media titles and the player's HUD. Keep the platform font and text scaler.
abstract final class SettingsPresentation {
  static bool _dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static double get rowHeight => 51;
  static double get rowFontSize => PlatformDetector.isTV() ? 17 : 15;
  static double get rowHorizontalPadding => PlatformDetector.isTV() ? 22 : 17;
  static double get groupRadius => 15;

  static const switchActiveTrack = Color(0xffd5d8df);
  static const switchActiveThumb = Color(0xff202020);
  static Color switchInactiveTrack(BuildContext context) =>
      VeloPalette.text(Theme.of(context).brightness).withValues(alpha: .15);

  static Color surface(BuildContext context) => Theme.of(context).colorScheme.surface;

  static Color muted(BuildContext context) => VeloPalette.caption(Theme.of(context).brightness);
  static Color outline(BuildContext context) => VeloPalette.edge(Theme.of(context).brightness);
  static Color icon(BuildContext context) => VeloPalette.caption(Theme.of(context).brightness);

  static BoxDecoration groupDecoration(BuildContext context) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [surface(context), surface(context)],
    ),
    borderRadius: BorderRadius.circular(groupRadius),
    border: Border.all(color: outline(context)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(_dark(context) ? 0x12 : 0x08),
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
    final oled = dark && theme.colorScheme.surface == VeloPalette.oledSurface;
    final background = oled ? VeloPalette.oledBackground : VeloPalette.background(theme.brightness);
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
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return theme.disabledColor.withValues(alpha: .12);
              return states.contains(WidgetState.selected)
                  ? SettingsPresentation.switchActiveTrack
                  : SettingsPresentation.switchInactiveTrack(context);
            }),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return theme.disabledColor;
              return states.contains(WidgetState.selected)
                  ? SettingsPresentation.switchActiveThumb
                  : VeloPalette.text(theme.brightness);
            }),
          ),
        ),
        child: child,
      ),
    );
    if (nested) return themed;
    return DecoratedBox(
      decoration: BoxDecoration(color: background),
      child: themed,
    );
  }
}

class _SettingsAppearanceScope extends InheritedWidget {
  const _SettingsAppearanceScope({required super.child});

  @override
  bool updateShouldNotify(_SettingsAppearanceScope oldWidget) => false;
}
