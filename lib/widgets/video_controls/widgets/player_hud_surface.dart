import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared small-area glass treatment for transient player feedback.
/// Callers retain their own positioning, semantics and pointer isolation.
class PlayerHudSurface extends StatelessWidget {
  const PlayerHudSurface({super.key, required this.child, this.radius = 22});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: child,
      ),
    ),
  );
}
