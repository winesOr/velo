import 'package:flutter/animation.dart';

/// Shared defaults for press feedback; widgets can override these per control.
abstract final class InteractionTokens {
  // Final UI V1: one press scale for fields, actions, cards and navigation.
  static const double selectPressedScale = .97;
  static const double mainPressedScale = .97;
  static const double secondaryPressedScale = .97;
  static const double cardPressedScale = .97;
  static const double navigationPressedScale = .97;
  static const Duration pressDuration = Duration(milliseconds: 120);
  static const Duration releaseDuration = Duration(milliseconds: 180);
  static const Duration menuSelectionDuration = Duration(milliseconds: 120);
  static const Curve pressCurve = Curves.easeOutCubic;
}
