/// Shared presentation defaults for transient surfaces. These are visual
/// tokens, independent of playback, networking and application behaviour.
abstract final class OverlayTokens {
  static const double radius = 24;
  static const double compactRadius = 18;
  static const double blurSigma = 22;
  static const double darkOpacity = 0.90;
  static const double lightOpacity = 0.94;
  static const double dialogMaxWidth = 560;
  static const double wideDialogMaxWidth = 720;
  static const double notificationMaxWidth = 520;
  static const double viewportInset = 16;
  static const Duration motion = Duration(milliseconds: 180);
}
