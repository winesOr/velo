import 'package:flutter/material.dart';

import '../../../focus/focus_theme.dart';
import '../../../focus/focusable_wrapper.dart';
import '../../../focus/dpad_navigator.dart';
import '../video_control_button.dart';
import 'player_focus_disc.dart';

/// A TV action keeps one stable focus target for its icon, label and value.
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
      focusScale: 1.14,
      child: SizedBox(
        width: 64 * scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerFocusDisc(
              iconColor: foreground,
              builder: (_, color) => VideoControlButton(icon: icon, color: color, onPressed: onPressed, tooltip: label),
            ),
            SizedBox(
              height: 30 * scale,
              child: Center(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: foreground, fontSize: 12 * scale, height: 1.15),
                ),
              ),
            ),
            SizedBox(
              height: 14 * scale,
              child: Text(
                value ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: foreground.withValues(alpha: .7), fontSize: 10 * scale),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
