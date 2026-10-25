import 'package:flutter/material.dart';

/// Round white knob for the slim settings sliders: a soft drop shadow keeps
/// it legible on glass and light surfaces, and [focused] adds a ring for
/// D-pad focus.
class GlassSliderThumbShape extends SliderComponentShape {
  const GlassSliderThumbShape({this.radius = 9, this.focused = false, this.color = Colors.white});

  final double radius;
  final bool focused;
  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(radius + (focused ? 4 : 0));

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    // Grows slightly while dragging.
    final r = radius + activationAnimation.value * 1.5;
    if (focused) {
      canvas.drawCircle(
        center,
        r + 4,
        Paint()..color = (sliderTheme.activeTrackColor ?? Colors.white).withValues(alpha: .35),
      );
    }
    canvas.drawCircle(
      center.translate(0, 1),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: .28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final enabled = enableAnimation.value > .5;
    canvas.drawCircle(center, r, Paint()..color = enabled ? color : const Color(0xFFB8BBC2));
    canvas.drawCircle(
      center,
      r - .25,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5
        ..color = Colors.black.withValues(alpha: .12),
    );
  }
}
