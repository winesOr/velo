import 'dart:async';

import 'package:flutter/material.dart';

import '../services/device_performance.dart';
import '../theme/interaction_tokens.dart';

/// Paint-only feedback. The existing control owns gestures and activation.
/// Feed this the control's highlight state so a scroll cancels the press too.
class PressFeedback extends StatelessWidget {
  const PressFeedback({
    super.key,
    required this.pressed,
    required this.child,
    this.enabled = true,
    this.pressedScale = InteractionTokens.selectPressedScale,
    this.pressDuration = InteractionTokens.pressDuration,
    this.releaseDuration = InteractionTokens.releaseDuration,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final bool pressed;
  final bool enabled;
  final Widget child;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final active = enabled && pressed;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : (active ? pressDuration : releaseDuration);
    return AnimatedScale(
      scale: active && !reduceMotion ? pressedScale : 1,
      duration: duration,
      curve: InteractionTokens.pressCurve,
      child: AnimatedContainer(
        duration: DevicePerformance.isReduced ? Duration.zero : duration,
        curve: InteractionTokens.pressCurve,
        foregroundDecoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .08) : Colors.transparent,
          borderRadius: borderRadius,
        ),
        child: child,
      ),
    );
  }
}

/// Connects existing gesture/highlight and keyboard-confirm callbacks to a
/// local feedback state. It adds no recognizer, haptic or business callback.
class PressFeedbackBuilder extends StatefulWidget {
  const PressFeedbackBuilder({
    super.key,
    required this.builder,
    this.pressedScale = InteractionTokens.selectPressedScale,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final Widget Function(BuildContext context, ValueChanged<bool> setPressed, VoidCallback confirm) builder;
  final double pressedScale;
  final bool enabled;
  final BorderRadius borderRadius;

  @override
  State<PressFeedbackBuilder> createState() => _PressFeedbackBuilderState();
}

class _PressFeedbackBuilderState extends State<PressFeedbackBuilder> {
  bool _pressed = false;
  Timer? _confirmation;

  void _setPressed(bool value) {
    _confirmation?.cancel();
    if (!mounted) return;
    final next = widget.enabled && value;
    if (next != _pressed) setState(() => _pressed = next);
  }

  void _confirm() {
    if (!widget.enabled) return;
    _setPressed(true);
    _confirmation = Timer(InteractionTokens.pressDuration, () => _setPressed(false));
  }

  @override
  void dispose() {
    _confirmation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PressFeedback(
    pressed: _pressed,
    enabled: widget.enabled,
    pressedScale: widget.pressedScale,
    borderRadius: widget.borderRadius,
    child: widget.builder(context, _setPressed, _confirm),
  );
}
