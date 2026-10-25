import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/mono_tokens.dart';

/// Shared loading language for the two full-screen transitions in the app:
/// the home feed and media detail. It deliberately avoids a centred spinner;
/// the ambient wash and low-contrast placeholders keep the screen legible
/// while the server answers.
class AmbientSkeletonScope extends StatefulWidget {
  const AmbientSkeletonScope({super.key, required this.child, this.animate = true});

  final Widget child;

  /// Set false for static screenshot/golden surfaces.
  final bool animate;

  @override
  State<AmbientSkeletonScope> createState() => _AmbientSkeletonScopeState();
}

class _AmbientSkeletonScopeState extends State<AmbientSkeletonScope> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AmbientSkeletonScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncAnimation();
  }

  void _syncAnimation() {
    final shouldAnimate =
        widget.animate && TickerMode.valuesOf(context).enabled && !MediaQuery.disableAnimationsOf(context);
    if (!shouldAnimate) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AmbientSkeletonAnimation(animation: _controller, child: widget.child);
  }
}

class _AmbientSkeletonAnimation extends InheritedWidget {
  const _AmbientSkeletonAnimation({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_AmbientSkeletonAnimation oldWidget) => animation != oldWidget.animation;

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AmbientSkeletonAnimation>()?.animation;
}

/// The soft, colour-washed background behind both loading layouts.
class AmbientSkeletonBackdrop extends StatelessWidget {
  const AmbientSkeletonBackdrop({super.key, this.accent, this.brandMark = false, this.flattened = false});

  final Color? accent;
  final bool brandMark;

  /// Paints only the theme surface. Used by the startup gate, whose frame must
  /// remain the persisted scaffold colour until its theme resolves.
  final bool flattened;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surface = theme.scaffoldBackgroundColor;
    final accentColor = accent ?? (dark ? const Color(0xff5b5cff) : const Color(0xff4d5bd8));
    final secondary = dark ? const Color(0xff22e1ff) : const Color(0xffe3a26d);
    final highlight = Color.lerp(surface, accentColor, dark ? .20 : .11)!;

    if (flattened) return ColoredBox(color: surface);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: surface),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-.72, -.82),
              radius: 1.25,
              colors: [
                accentColor.withValues(alpha: dark ? .20 : .13),
                accentColor.withValues(alpha: dark ? .06 : .035),
                Colors.transparent,
              ],
              stops: const [0, .43, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(.92, -.3),
              radius: .9,
              colors: [
                secondary.withValues(alpha: dark ? .10 : .065),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                highlight.withValues(alpha: dark ? .14 : .08),
                Colors.transparent,
                surface.withValues(alpha: .58),
                surface,
              ],
              stops: const [0, .38, .78, 1],
            ),
          ),
        ),
        if (brandMark)
          Positioned(
            right: -64,
            bottom: 72,
            child: ExcludeSemantics(
              child: Opacity(
                opacity: dark ? .055 : .045,
                child: SvgPicture.asset('assets/velo_glyph.svg', width: 280, height: 280),
              ),
            ),
          ),
      ],
    );
  }
}

/// A single skeleton surface with a restrained highlight travelling across it.
class AmbientSkeletonBox extends StatelessWidget {
  const AmbientSkeletonBox({super.key, this.width, this.height, this.borderRadius, this.shape = BoxShape.rectangle});

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = colors.onSurface.withValues(alpha: dark ? .075 : .055);
    final shine = colors.onSurface.withValues(alpha: dark ? .135 : .095);
    final radius = borderRadius ?? BorderRadius.circular(tokens(context).radiusSm);
    final animation = _AmbientSkeletonAnimation.maybeOf(context);

    Widget box(double highlightPosition) {
      final start = (highlightPosition - .32).clamp(0.0, 1.0);
      final middle = highlightPosition.clamp(0.0, 1.0);
      final end = (highlightPosition + .32).clamp(0.0, 1.0);
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: shape == BoxShape.rectangle ? radius : null,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: middle <= start
                ? [base, base]
                : middle >= end
                ? [base, base]
                : [base, shine, base],
            stops: middle <= start
                ? [0, 1]
                : middle >= end
                ? [0, 1]
                : [start, middle, end],
          ),
        ),
      );
    }

    if (animation == null) return box(.5);
    return AnimatedBuilder(animation: animation, builder: (context, _) => box((animation.value * 1.7) - .35));
  }
}

/// Matches the geometry of a [MediaCard] row, including the title lines.
class AmbientSkeletonCard extends StatelessWidget {
  const AmbientSkeletonCard({super.key, required this.width, required this.posterHeight, this.titleWidthFactor = .86});

  final double width;
  final double posterHeight;
  final double titleWidthFactor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(tokens(context).radiusSm);
    return SizedBox(
      width: width,
      height: posterHeight + 36,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AmbientSkeletonBox(width: width, height: posterHeight, borderRadius: radius),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: titleWidthFactor,
            alignment: Alignment.centerLeft,
            child: const AmbientSkeletonBox(height: 12, borderRadius: BorderRadius.all(Radius.circular(4))),
          ),
          const SizedBox(height: 6),
          FractionallySizedBox(
            widthFactor: .56,
            alignment: Alignment.centerLeft,
            child: const AmbientSkeletonBox(height: 10, borderRadius: BorderRadius.all(Radius.circular(4))),
          ),
        ],
      ),
    );
  }
}
