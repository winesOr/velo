import 'package:flutter/animation.dart';

/// Shared defaults for press feedback; widgets can override these per control.
abstract final class InteractionTokens {
  // TODO(VELO-P8-01): Tune these defaults with touch and TV device validation.
  static const double selectPressedScale = .97;
  static const double mainPressedScale = .97;
  static const double secondaryPressedScale = .94;
  static const double cardPressedScale = .96;
  static const double navigationPressedScale = .90;
  static const Duration pressDuration = Duration(milliseconds: 120);
  static const Duration releaseDuration = Duration(milliseconds: 180);
  static const Duration menuSelectionDuration = Duration(milliseconds: 120);
  static const Curve pressCurve = Curves.easeOutCubic;
}
