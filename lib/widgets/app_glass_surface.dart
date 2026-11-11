import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../services/device_performance.dart';
import '../theme/overlay_tokens.dart';

/// One clipped backdrop for each transient surface. Text and controls share a
/// stable, sufficiently opaque tint; low-effect and accessible modes need no
/// blur to remain readable.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.radius = OverlayTokens.radius,
    this.backgroundColor,
    this.blurSigma = OverlayTokens.blurSigma,
    this.frosted = true,
    this.shape,
  });

  final Widget child;
  final double radius;
  final Color? backgroundColor;
  final double blurSigma;
  final bool frosted;
  final ShapeBorder? shape;

  static bool reduceEffects(BuildContext context) =>
      DevicePerformance.isReduced || MediaQuery.highContrastOf(context) || MediaQuery.disableAnimationsOf(context);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final reduced = reduceEffects(context);
    final glass = frosted && !reduced;
    // A fully transparent legacy container carries no meaningful tint. Its
    // hidden RGB is often black; making that opaque would create black halos
    // in light mode and an unreadable fallback.
    final tint = backgroundColor == null || backgroundColor!.a == 0 ? colors.surface : backgroundColor!;
    final surface = glass
        ? tint.withValues(alpha: dark ? OverlayTokens.darkOpacity : OverlayTokens.lightOpacity)
        : tint.withValues(alpha: 1);
    final outline =
        shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: colors.onSurface.withValues(alpha: reduced ? 0.35 : (dark ? 0.12 : 0.10))),
        );
    Widget body = Material(
      color: surface,
      shape: outline,
      clipBehavior: Clip.antiAlias,
      textStyle: Theme.of(context).textTheme.bodyMedium,
      child: IconTheme.merge(
        data: IconThemeData(color: colors.onSurface),
        child: child,
      ),
    );
    if (glass) {
      body = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: body,
      );
    }
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: outline,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.22 : 0.10),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: outline),
        child: body,
      ),
    );
  }
}
