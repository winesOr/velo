import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/ambient_palette_extractor.dart';

/// VidHub 风格的全景动态流光毛玻璃背景组件
///
/// 核心视觉设计：
/// 1. [Soft Hero Backdrop]：海报大图经高斯模糊（sigma 30~45）平铺，形成朦胧底蕴；
/// 2. [Ambient Radial Glow]：根据海报提取出的主色调（Dominant Accent），
///    在屏幕中上方与右上角投射动态辐射光晕，形成标志性的电影院氛围灯质感；
/// 3. [Smooth Color Transition]：海报切换或色彩变动时，具备 350ms 平滑补间插值；
/// 4. [Contrast Shield & Fade Scrim]：多阶微透压暗遮罩，保证文字与评分徽章拥有清晰对比度。
class VidHubAmbientBackdrop extends StatefulWidget {
  final Widget backdropChild;
  final Color? accentColor;
  final ImageProvider? imageProviderForExtraction;
  final double blurSigma;
  final double glowIntensity;
  final Color? backgroundColor;
  final Widget? child;
  final bool animateColor;

  /// Keep foreground hero artwork clear; theme tint fades in below its text.
  final bool preserveArtwork;

  const VidHubAmbientBackdrop({
    super.key,
    required this.backdropChild,
    this.accentColor,
    this.imageProviderForExtraction,
    this.blurSigma = 36.0,
    this.glowIntensity = 0.42,
    this.backgroundColor,
    this.child,
    this.animateColor = true,
    this.preserveArtwork = false,
  });

  @override
  State<VidHubAmbientBackdrop> createState() => _VidHubAmbientBackdropState();
}

class _VidHubAmbientBackdropState extends State<VidHubAmbientBackdrop> {
  Color _resolvedAccent = AmbientPaletteExtractor.defaultFallback;
  int _extractionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _updateResolvedColor();
  }

  @override
  void didUpdateWidget(covariant VidHubAmbientBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accentColor != oldWidget.accentColor ||
        widget.imageProviderForExtraction != oldWidget.imageProviderForExtraction ||
        widget.backgroundColor != oldWidget.backgroundColor) {
      _updateResolvedColor();
    }
  }

  void _updateResolvedColor() {
    final generation = ++_extractionGeneration;
    if (widget.accentColor != null) {
      setState(() => _resolvedAccent = widget.accentColor!);
      return;
    }

    final provider = widget.imageProviderForExtraction;
    if (provider != null) {
      AmbientPaletteExtractor.extractFromImageProvider(
        provider,
        fallback: widget.backgroundColor ?? AmbientPaletteExtractor.defaultFallback,
      ).then((color) {
        if (mounted && generation == _extractionGeneration && color != _resolvedAccent) {
          setState(() => _resolvedAccent = color);
        }
      });
    } else {
      _resolvedAccent = widget.backgroundColor ?? AmbientPaletteExtractor.defaultFallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final clearLightArtwork = widget.preserveArtwork && Theme.of(context).brightness == Brightness.light;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 底层：海报大图 + 硬件加速高斯模糊
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: widget.blurSigma,
              sigmaY: widget.blurSigma,
              tileMode: TileMode.clamp,
            ),
            child: widget.backdropChild,
          ),
        ),

        // 2. 动态氛围流光层 (VidHub Ambient Radial Glow)
        Positioned.fill(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(begin: _resolvedAccent, end: _resolvedAccent),
            duration: !widget.animateColor || MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (context, animatedColor, _) {
              final activeColor = animatedColor ?? _resolvedAccent;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 顶部偏右侧主氛围光晕
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.45, -0.65),
                        radius: 1.35,
                        colors: [
                          activeColor.withValues(alpha: widget.glowIntensity),
                          activeColor.withValues(alpha: widget.glowIntensity * 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),

                  // 顶部微透斜向光晕，增加层次厚度
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          activeColor.withValues(alpha: widget.glowIntensity * 0.28),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // 3. 磨砂防过曝暗层，衬托白色文字与按钮
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: clearLightArtwork ? 0 : .22)),
          ),
        ),

        // 4. 底部阶梯消隐渐变，平滑融入整体页面
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  bgColor.withValues(alpha: clearLightArtwork ? .18 : .4),
                  bgColor.withValues(alpha: 0.85),
                  bgColor,
                ],
                stops: clearLightArtwork ? const [0, .6, .78, .92, 1] : const [0, .45, .72, .90, 1],
              ),
            ),
          ),
        ),

        // 5. 前景内容（若有）
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
