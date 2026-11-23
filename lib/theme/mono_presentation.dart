import 'package:flutter/material.dart';

import '../utils/platform_detector.dart';
import 'velo_brand.dart';

/// Presentation values shared by phone, tablet and TV layouts.
/// Artwork mapping is our implementation, independent of the server protocol.
abstract final class MonoPresentation {
  static const artworkDuration = Duration(milliseconds: 560);
  static const navigationHeight = 58.0;
  static const navigationMaxWidth = 336.0;

  /// Use the available touch viewport, so a tablet in split view can fall
  /// back to the phone layout without inheriting desktop presentation.
  static bool isTablet(BuildContext context) =>
      PlatformDetector.isMobile(context) && MediaQuery.sizeOf(context).shortestSide >= 600;

  static bool isLandscapeTablet(BuildContext context) =>
      isTablet(context) && MediaQuery.orientationOf(context) == Orientation.landscape;

  static bool useSettingsColumns(BuildContext context) =>
      isTablet(context) && MediaQuery.sizeOf(context).width >= 760 && MediaQuery.textScalerOf(context).scale(16) <= 24;

  static double pageInset(BuildContext context) => isTablet(context) ? 32 : 16;

  static double touchHeroHeight(BuildContext context, {bool detail = false, bool hasArtwork = true}) {
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final extra = (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0, 32) * 2;
    if (isTablet(context)) {
      return (size.height * (size.width > size.height ? .64 : .60)).clamp(440.0 + top, 720.0) + extra;
    }
    if (detail) {
      final base = hasArtwork
          ? (size.width * (603 / 390)).clamp(540.0, double.infinity)
          : size.width.clamp(390.0, double.infinity);
      return base + (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, double.infinity) * 180;
    }
    return size.width > size.height
        ? (500 + top).clamp(0, size.height)
        : (size.height * .65).clamp(500 + top, double.infinity) + extra;
  }

  static TextStyle pageTitle(BuildContext context, {bool secondary = false}) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: secondary ? 20 : (PlatformDetector.isTV() ? 24 : 21),
        fontWeight: FontWeight.w600,
        letterSpacing: -.2,
      );

  static TextStyle libraryTitle(BuildContext context) => pageTitle(context);

  static Color headerSurface(BuildContext context) => Theme.of(context).colorScheme.surface;

  static Color headerEdge(BuildContext context) => VeloPalette.edge(Theme.of(context).brightness);

  // Artwork is content, not a theme surface. Appearance controls chrome; it
  // must not dilute a red poster into a pink or gray page.
  static Color artworkSurface(Color raw, Brightness brightness) => raw;

  static ({Color foreground, Color caption}) artworkTextColors(
    Color surface, {
    Brightness brightness = Brightness.dark,
    bool highContrastCaption = false,
  }) {
    final luminance = surface.computeLuminance();
    final whiteContrast = 1.05 / (luminance + .05);
    final blackContrast = (luminance + .05) / .05;
    final lightInk = highContrastCaption
        ? whiteContrast >= blackContrast
        : whiteContrast >= 4.5 && (blackContrast < 4.5 || brightness == Brightness.dark);
    final foreground = lightInk ? Colors.white : Colors.black;
    final muted = highContrastCaption
        ? Color.lerp(surface, foreground, .88)!
        : VeloPalette.caption(lightInk ? Brightness.dark : Brightness.light);
    final minimumContrast = highContrastCaption ? 7.0 : 4.5;
    // Keep secondary text muted as far as the actual artwork permits.
    for (var step = 0; step < 8; step++) {
      final caption = Color.lerp(muted, foreground, step / 8)!;
      final ink = caption.computeLuminance();
      final contrast = ink >= luminance ? (ink + .05) / (luminance + .05) : (luminance + .05) / (ink + .05);
      if (contrast >= minimumContrast) return (foreground: foreground, caption: caption);
    }
    return (foreground: foreground, caption: foreground);
  }

  /// Blend artwork into its page color with a long, gently eased ramp.
  /// Shared by home and details so their transitions stay in sync.
  static LinearGradient artworkBlend(Color surface) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, .28, .3675, .455, .5425, .63, .7175, .805, .8925, .98, 1],
    colors: [
      for (final alpha in const [0.0, 0.0, .043, .156, .316, .5, .684, .844, .957, 1.0, 1.0])
        surface.withValues(alpha: alpha),
    ],
  );

  static Color navigationSurface(Brightness brightness, {Color? artwork, double alpha = .94}) {
    final base = VeloPalette.surface(brightness);
    return (artwork == null ? base : Color.lerp(base, artwork, .16)!).withValues(alpha: alpha);
  }

  static Color navigationForeground(Brightness brightness, {bool selected = false}) =>
      selected ? VeloBrand.foreground(brightness) : VeloPalette.caption(brightness);
}
