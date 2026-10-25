import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/widgets/app_icon.dart';

import '../helpers/mobile_edge_adjustment_tracker.dart';
import 'player_hud_surface.dart';

/// Compact, non-interactive feedback at the corresponding gesture edge.
class MobileEdgeAdjustmentIndicator extends StatelessWidget {
  const MobileEdgeAdjustmentIndicator({super.key, required this.side, required this.value});

  final MobileEdgeAdjustmentSide side;
  final double value;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    final isLeft = side == MobileEdgeAdjustmentSide.left;
    final icon = isLeft
        ? Symbols.brightness_6_rounded
        : clampedValue == 0
        ? Symbols.volume_off_rounded
        : Symbols.volume_up_rounded;
    final alignment = isLeft ? Alignment.centerLeft : Alignment.centerRight;
    final margin = isLeft ? const EdgeInsets.only(left: 16) : const EdgeInsets.only(right: 16);

    return SafeArea(
      minimum: margin,
      child: Align(
        alignment: alignment,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: '${(clampedValue * 100).round()}%',
          child: ExcludeSemantics(
            child: PlayerHudSurface(
              child: SizedBox(
                width: 42,
                height: 128,
                child: TweenAnimationBuilder<double>(
                  // Start from the actual value, not zero, to avoid a jump on first drag.
                  tween: Tween<double>(begin: clampedValue, end: clampedValue),
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 90),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedValue, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        AppIcon(icon, fill: 1, color: Colors.white, size: 18),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SizedBox(
                            width: 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: ColoredBox(
                                color: Colors.white.withValues(alpha: 0.18),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: animatedValue,
                                    widthFactor: 1,
                                    child: const ColoredBox(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(animatedValue * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
