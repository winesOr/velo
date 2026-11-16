import 'package:flutter/material.dart';
import '../services/device_performance.dart';
import '../theme/mono_tokens.dart';
import '../theme/velo_brand.dart';
import '../utils/platform_detector.dart';

class FocusTheme {
  FocusTheme._();

  static const double focusScale = 1;
  static const double fullCardFocusScale = 1;

  /// Focus remains stationary; press feedback is handled independently.
  static const double playerControlFocusScale = 1;

  /// The TV reference is 1920px at DPR 2, or a 960 logical-pixel viewport.
  static double tvPlayerScale(BuildContext context) =>
      PlatformDetector.isTV() ? (MediaQuery.sizeOf(context).width / 960).clamp(.75, 2.0).toDouble() : 1;

  static BoxDecoration playerDrawerFocusDecoration(BuildContext context, {required bool isFocused}) =>
      focusDecoration(context, isFocused: isFocused);
  static const double focusBorderWidth = 2;
  static const double focusOutlineOffset = 3;
  static const double defaultBorderRadius = 8.0;
  static const double focusGlowInnerBlurRadius = 18;
  static const double focusGlowOuterBlurRadius = 34;
  static const double focusGlowSpreadRadius = 1.5;

  static Color getFocusBorderColor(BuildContext context) {
    return VeloBrand.foreground(Theme.of(context).brightness);
  }

  /// Ten-foot TV focus uses a soft lifted card rather than the 2.5px phone
  /// outline. Artwork cards keep their own focus chrome; settings and
  /// full-width actions use this larger, room-readable treatment.
  static BoxDecoration tvLiftedFocusDecoration(
    BuildContext context, {
    required bool isFocused,
    BorderRadius? radii,
    Color? color,
  }) {
    final focusColor = color ?? getFocusBorderColor(context);
    return BoxDecoration(
      borderRadius: radii ?? BorderRadius.circular(defaultBorderRadius),
      color: isFocused ? focusColor.withValues(alpha: 0.14) : Colors.transparent,
      border: Border.all(color: isFocused ? focusColor.withValues(alpha: 0.9) : Colors.transparent, width: 2),
      boxShadow: isFocused
          ? [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
              BoxShadow(color: focusColor.withValues(alpha: 0.18), blurRadius: 20),
            ]
          : null,
    );
  }

  static Duration getAnimationDuration(BuildContext context) {
    // Reduced tier: snap focus transitions (scale/border/glow) instead of
    // animating — each animation frame re-rasterizes the focused card.
    if (DevicePerformance.isReduced) return Duration.zero;
    return Theme.of(context).extension<MonoTokens>()?.fast ?? const Duration(milliseconds: 150);
  }

  /// How long a TV row (or the hub list) glides after one D-pad focus step.
  ///
  /// Apple TV keeps the ~500ms ease-out measured from the native focus
  /// engine's scrollable containers (issue #2006): Siri Remote swipes chain
  /// steps into one continuous glide and users expect that inertia. D-pad
  /// platforms have no such reference: Leanback's `GridLayoutManager` prices a
  /// one-card step at roughly 100-150ms, so a 500ms glide there trails the
  /// focus border on every press and reads as input lag next to the launcher.
  /// Successive presses (including hold-repeats) retarget the animation from
  /// wherever the row currently is, so a fast series still glides continuously.
  static Duration navigationScrollDuration() =>
      PlatformDetector.isAppleTV() ? const Duration(milliseconds: 500) : const Duration(milliseconds: 150);

  /// [radii] overrides [borderRadius] when per-corner radii are needed
  /// (M3E grouped cards: large outer / small inner corners).
  static BoxDecoration focusDecoration(
    BuildContext context, {
    required bool isFocused,
    double borderRadius = defaultBorderRadius,
    BorderRadius? radii,
    double borderStrokeAlign = BorderSide.strokeAlignOutside,
    Color? color,
  }) {
    final focusColor = color ?? getFocusBorderColor(context);

    return _FocusOutlineDecoration(
      borderRadius: radii ?? BorderRadius.circular(borderRadius),
      border: Border.fromBorderSide(
        BorderSide(
          color: isFocused ? focusColor : Colors.transparent,
          width: focusBorderWidth,
          strokeAlign: borderStrokeAlign + 2 * focusOutlineOffset / focusBorderWidth,
        ),
      ),
    );
  }

  /// The focus glow as a list of [BoxShadow]s.
  ///
  /// Rendered by [FocusGlowOverlay] in the root overlay so the glow paints
  /// above sibling cards on all four sides (an in-tree background shadow is
  /// occluded by later-painted neighbours, which produced the one-sided halo).
  static List<BoxShadow> focusGlowShadows(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.34),
        blurRadius: focusGlowInnerBlurRadius,
        spreadRadius: focusGlowSpreadRadius,
      ),
      BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: focusGlowOuterBlurRadius),
    ];
  }

  /// How far the focus glow visibly reaches beyond the card edge. Used to size
  /// the overlay paint area so the blur is not clipped.
  static double get focusGlowExtent => focusGlowOuterBlurRadius * 2 + focusGlowSpreadRadius;

  /// Build focus decoration with background color instead of border.
  /// Useful for video controls where it should match the native hover style.
  /// [radii] overrides [borderRadius] when per-corner radii are needed.
  static BoxDecoration focusBackgroundDecoration({
    required bool isFocused,
    double borderRadius = defaultBorderRadius,
    BorderRadius? radii,
  }) {
    return BoxDecoration(
      borderRadius: radii ?? BorderRadius.circular(borderRadius),
      color: isFocused ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
    );
  }

  /// Focus background fill derived from the theme's text color, so it stays
  /// visible on BOTH light and dark surfaces — the white-based
  /// [focusBackgroundDecoration] disappears on light ones. This is the mono
  /// convention used by [TrackRow], the navigation rail, and the music player
  /// surfaces. Prefer this for any new mono-themed surface.
  static BoxDecoration textFillFocusDecoration(
    BuildContext context, {
    required bool isFocused,
    double borderRadius = defaultBorderRadius,
    BorderRadius? radii,
  }) {
    return BoxDecoration(
      borderRadius: radii ?? BorderRadius.circular(borderRadius),
      color: isFocused ? tokens(context).text.withValues(alpha: 0.12) : Colors.transparent,
    );
  }
}

/// An outline outside the child reserves no layout padding. Preserve this
/// during decoration interpolation and when callers add a background color.
class _FocusOutlineDecoration extends BoxDecoration {
  const _FocusOutlineDecoration({
    super.borderRadius,
    super.border,
    super.color,
    super.image,
    super.boxShadow,
    super.gradient,
    super.backgroundBlendMode,
    super.shape,
  });

  factory _FocusOutlineDecoration.from(BoxDecoration decoration) => _FocusOutlineDecoration(
    borderRadius: decoration.borderRadius,
    border: decoration.border,
    color: decoration.color,
    image: decoration.image,
    boxShadow: decoration.boxShadow,
    gradient: decoration.gradient,
    backgroundBlendMode: decoration.backgroundBlendMode,
    shape: decoration.shape,
  );

  @override
  EdgeInsetsGeometry get padding => EdgeInsets.zero;

  @override
  BoxDecoration copyWith({
    Color? color,
    DecorationImage? image,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    BlendMode? backgroundBlendMode,
    BoxShape? shape,
  }) => _FocusOutlineDecoration.from(
    super.copyWith(
      color: color,
      image: image,
      border: border,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      gradient: gradient,
      backgroundBlendMode: backgroundBlendMode,
      shape: shape,
    ),
  );

  @override
  BoxDecoration? lerpFrom(Decoration? a, double t) {
    final result = super.lerpFrom(a, t);
    return result == null ? null : _FocusOutlineDecoration.from(result);
  }

  @override
  BoxDecoration? lerpTo(Decoration? b, double t) {
    final result = super.lerpTo(b, t);
    return result == null ? null : _FocusOutlineDecoration.from(result);
  }
}
