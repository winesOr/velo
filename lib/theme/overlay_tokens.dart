import 'dart:ui' show Color;

/// Shared presentation defaults for transient surfaces. These are visual
/// tokens, independent of playback, networking and application behaviour.
abstract final class OverlayTokens {
  static const double radius = 24;
  static const double compactRadius = 18;
  static const double blurSigma = 22;
  static const double darkOpacity = 242 / 255;
  static const double lightOpacity = 245 / 255;
  static const double dialogMaxWidth = 560;
  static const double wideDialogMaxWidth = 720;
  static const double notificationMaxWidth = 460;
  static const double viewportInset = 16;
  static const double drawerWidth = 340;
  static const Duration drawerMotion = Duration(milliseconds: 240);
  static const Duration motion = Duration(milliseconds: 180);

  // Player overlays (side drawers, anchored menus) are see-through frosted
  // glass so the picture stays visible behind them; always dark.
  static const Color playerGlassTint = Color(0xff1a1a1c);
  static const double playerGlassOpacity = .56;
  static const double playerGlassBlurSigma = 34;
  static const double playerGlassSaturation = 1.7;
  static const Color playerGlassEdge = Color(0x29ffffff);
  static const double playerBarrierOpacity = .16;
  static const double playerMenuWidth = 132;
}
