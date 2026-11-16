import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../focus/card_focus_scope.dart';
import '../../../focus/focus_theme.dart';
import '../../../focus/focusable_wrapper.dart';
import '../../../focus/dpad_navigator.dart';
import '../../../theme/velo_brand.dart';
import '../../app_icon.dart';
import 'player_focus_disc.dart';
import '../../press_feedback.dart';

/// A TV action keeps its icon and one-line current value in a single tile.
class TvActionButton extends StatelessWidget {
  const TvActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.focusNode,
    required this.onPressed,
    this.value,
    this.onKeyEvent,
    this.onFocusChange,
  });

  final IconData icon;
  final String label;
  final String? value;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    final scale = FocusTheme.tvPlayerScale(context);
    final foreground = onPressed == null ? Colors.white38 : Colors.white;
    return FocusableWrapper(
      focusNode: focusNode,
      onSelect: onPressed,
      onKeyEvent: (node, event) {
        if (onPressed == null && event.logicalKey.isSelectKey) return KeyEventResult.handled;
        return onKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
      },
      onFocusChange: onFocusChange,
      semanticLabel: label,
      semanticValue: value,
      descendantsAreFocusable: false,
      excludeChildSemantics: true,
      delegateFocusBorder: true,
      focusScale: FocusTheme.focusScale,
      child: Builder(
        builder: (context) {
          final focused = CardFocusScope.maybeOf(context) ?? false;
          final color = focused ? Colors.black.withValues(alpha: foreground.a) : foreground;
          final radius = BorderRadius.circular(13 * scale);
          return AnimatedContainer(
            duration: FocusTheme.getAnimationDuration(context),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(borderRadius: radius, boxShadow: focused ? const [playerFocusShadow] : const []),
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: focused ? VeloBrand.accent : Colors.transparent, width: 3 * scale),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: focused ? Colors.white : Colors.white.withValues(alpha: .14),
                  child: PressFeedbackInkWell(
                    onTap: onPressed,
                    canRequestFocus: false,
                    child: Tooltip(
                      message: label,
                      child: SizedBox.square(
                        dimension: 62 * scale,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppIcon(icon, size: 24 * scale, color: color),
                            SizedBox(height: 4 * scale),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                              child: Text(
                                value ?? label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                ),
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
          );
        },
      ),
    );
  }
}
