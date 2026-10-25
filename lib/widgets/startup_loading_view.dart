import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../i18n/strings.g.dart';
import '../theme/velo_brand.dart';
import '../utils/platform_detector.dart';

/// A small, transparent mark shared by storage bootstrap and server setup.
/// Crop only the canonical SVG's empty canvas; retain its original folds.
class StartupBrandMark extends StatelessWidget {
  const StartupBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tv = PlatformDetector.isTV();
    final canvas = tv ? 168.0 : 144.0;
    final accent = VeloBrand.foreground(theme.brightness);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: tv ? 88 : 76,
            height: tv ? 102 : 88,
            child: ClipRect(
              child: OverflowBox(
                minWidth: canvas,
                maxWidth: canvas,
                minHeight: canvas,
                maxHeight: canvas,
                child: SvgPicture.asset('assets/velo_glyph.svg', width: canvas, height: canvas),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t.app.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: tv ? 28 : 24,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 72,
          child: LinearProgressIndicator(
            value: MediaQuery.disableAnimationsOf(context) ? .4 : null,
            minHeight: 2,
            borderRadius: BorderRadius.circular(1),
            backgroundColor: accent.withValues(alpha: .10),
            valueColor: AlwaysStoppedAnimation<Color>(accent.withValues(alpha: .72)),
          ),
        ),
      ],
    );
  }
}

/// One flowing layout for portrait, landscape and scaled TV interfaces. The
/// brand remains compact; long connection lists scroll without fixed offsets.
class StartupLoadingView extends StatelessWidget {
  const StartupLoadingView({super.key, this.status, this.servers});

  final Widget? status;
  final Widget? servers;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: Theme.of(context).textTheme.bodyMedium!,
    child: ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: math.max(0, constraints.maxHeight - 64)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const StartupBrandMark(),
                      if (status != null) ...[const SizedBox(height: 24), status!],
                      if (servers != null) ...[const SizedBox(height: 16), servers!],
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
