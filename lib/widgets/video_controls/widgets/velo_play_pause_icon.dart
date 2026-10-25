import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The approved folded mark opens into pause bars inside the existing
/// transport button. Hit testing, semantics and TV focus belong to its parent.
class VeloPlayPauseIcon extends StatefulWidget {
  const VeloPlayPauseIcon({super.key, required this.isPlaying, required this.color, this.size = 26});

  final bool isPlaying;
  final Color color;
  final double size;

  @override
  State<VeloPlayPauseIcon> createState() => _VeloPlayPauseIconState();
}

class _VeloPlayPauseIconState extends State<VeloPlayPauseIcon> with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: widget.isPlaying ? 1 : 0,
  );

  void _update() {
    final target = widget.isPlaying ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = target;
    } else {
      _motion.animateTo(target, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _motion.value = widget.isPlaying ? 1 : 0;
  }

  @override
  void didUpdateWidget(VeloPlayPauseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) _update();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(size: Size.square(widget.size), painter: _FoldPainter(_motion, widget.color)),
    ),
  );
}

class _FoldPainter extends CustomPainter {
  _FoldPainter(this.motion, this.color) : super(repaint: motion);

  final Animation<double> motion;
  final Color color;

  // Sample once, outside the frame loop, from the canonical branding paths.
  static final _play = [
    _sample(
      Path()
        ..moveTo(363, 275)
        ..cubicTo(339, 261, 310, 278, 310, 306)
        ..lineTo(310, 370)
        ..cubicTo(310, 394, 323, 416, 344, 428)
        ..lineTo(450, 512)
        ..cubicTo(477, 499, 505, 500, 544, 524)
        ..cubicTo(586, 550, 650, 580, 710, 548)
        ..cubicTo(738, 532, 738, 492, 710, 476)
        ..close(),
    ),
    _sample(
      Path()
        ..moveTo(450, 512)
        ..lineTo(344, 596)
        ..cubicTo(323, 608, 310, 630, 310, 654)
        ..lineTo(310, 718)
        ..cubicTo(310, 746, 339, 763, 363, 749)
        ..lineTo(710, 548)
        ..cubicTo(650, 580, 586, 550, 544, 524)
        ..cubicTo(505, 500, 477, 499, 450, 512)
        ..close(),
    ),
  ];

  static Path _bar(double x) => Path()
    ..moveTo(x + 28, 282)
    ..cubicTo(x + 10, 282, x, 294, x, 312)
    ..lineTo(x, 712)
    ..cubicTo(x, 730, x + 10, 742, x + 28, 742)
    ..lineTo(x + 99, 742)
    ..cubicTo(x + 117, 742, x + 127, 730, x + 127, 712)
    ..lineTo(x + 127, 312)
    ..cubicTo(x + 127, 294, x + 117, 282, x + 99, 282)
    ..close();

  static final _pause = [for (var k = 0; k < 2; k++) _align(_play[k], _sample(_bar(k == 0 ? 338 : 560)))];

  static List<Offset> _sample(Path path) {
    final metric = path.computeMetrics().first;
    return List.generate(128, (i) => metric.getTangentForOffset(metric.length * i / 128)!.position);
  }

  static List<Offset> _align(List<Offset> from, List<Offset> to) {
    var best = double.infinity;
    var shift = 0;
    for (var offset = 0; offset < to.length; offset++) {
      var distance = 0.0;
      for (var i = 0; i < from.length; i++) {
        distance += (from[i] - to[(i + offset) % to.length]).distanceSquared;
      }
      if (distance < best) {
        best = distance;
        shift = offset;
      }
    }
    return List.generate(to.length, (i) => to[(i + shift) % to.length]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = size.shortestSide / 540;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-512, -512);
    for (var fold = 0; fold < 2; fold++) {
      final points = List.generate(128, (i) => Offset.lerp(_play[fold][i], _pause[fold][i], motion.value)!);
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path.shift(const Offset(0, 6)), Paint()..color = Color.lerp(color, Colors.black, .24)!);
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(const Offset(330, 280), const Offset(690, 720), [
            color,
            Color.lerp(color, Colors.black, fold == 0 ? .02 : .12)!,
          ]),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoldPainter oldDelegate) => oldDelegate.color != color || oldDelegate.motion != motion;
}
