import 'package:flutter/material.dart';

import '../utils/media_quality_labels.dart';

/// Badge sizes shared by every surface that names a media format.
///
/// [small] sits in the player header, [medium] on the detail spec row and in
/// the file information sheet, [large] on TV player and detail surfaces. Every
/// size is multiplied by the caller's `scale` (TV layout scale).
enum MediaFormatBadgeSize {
  small(height: 16, fontSize: 9, padding: 4, radius: 3.5, border: 1.2),
  medium(height: 19, fontSize: 10.5, padding: 5, radius: 4, border: 1.5),
  large(height: 24, fontSize: 13, padding: 7, radius: 5, border: 1.5);

  const MediaFormatBadgeSize({
    required this.height,
    required this.fontSize,
    required this.padding,
    required this.radius,
    required this.border,
  });

  final double height;
  final double fontSize;
  final double padding;
  final double radius;
  final double border;
}

/// Outlined wordmark for one [MediaFormat]. Dolby formats use two weights
/// ("DOLBY" heavy, "VISION" light); HDR and DTS formats use one. No icon: the
/// wordmark alone identifies the format and matches the content-rating box.
///
/// The colour follows [color] or the ambient text colour, so the badge works
/// on themed surfaces and on artwork-tinted detail heroes alike.
class MediaFormatBadge extends StatelessWidget {
  const MediaFormatBadge(this.format, {super.key, this.size = MediaFormatBadgeSize.medium, this.scale = 1, this.color});

  final MediaFormat format;
  final MediaFormatBadgeSize size;
  final double scale;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? DefaultTextStyle.of(context).style.color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: format.label,
      excludeSemantics: true,
      child: _BadgeBox(
        size: size,
        scale: scale,
        border: Border.all(color: foreground.withValues(alpha: .78), width: size.border * scale),
        child: _FormatWordmark(format: format, size: size, scale: scale, color: foreground),
      ),
    );
  }
}

/// Resolution label ("4K", "1080P") that starts a spec row: a tinted fill in
/// the text colour instead of an outline, so it reads as the row's anchor.
class MediaResolutionBadge extends StatelessWidget {
  const MediaResolutionBadge(
    this.label, {
    super.key,
    this.size = MediaFormatBadgeSize.medium,
    this.scale = 1,
    this.color,
  });

  final String label;
  final MediaFormatBadgeSize size;
  final double scale;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? DefaultTextStyle.of(context).style.color ?? Theme.of(context).colorScheme.onSurface;
    return _BadgeBox(
      size: size,
      scale: scale,
      color: foreground.withValues(alpha: .2),
      child: Text(label.toUpperCase(), maxLines: 1, style: _wordmarkStyle(size, scale, foreground, FontWeight.w600)),
    );
  }
}

/// Poster-corner badge: the best video format and a premium audio format in
/// one segmented chip on the same dark block as the rating badge
/// (20 px tall, 6 px radius, #000 at 80%). Use [mediaPosterFormats] to pick
/// the formats.
class MediaFormatPosterBadge extends StatelessWidget {
  const MediaFormatPosterBadge(this.formats, {super.key, this.scale = 1});

  final List<MediaFormat> formats;
  final double scale;

  static const background = Color(0xCC000000);
  static const height = 20.0;
  static const radius = 6.0;

  @override
  Widget build(BuildContext context) {
    if (formats.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: formats.map((format) => format.label).join(', '),
      excludeSemantics: true,
      child: Container(
        height: height * scale,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius * scale)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, format) in formats.indexed)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                alignment: Alignment.center,
                decoration: index == 0
                    ? null
                    : const BoxDecoration(
                        border: Border(left: BorderSide(color: Color(0x38FFFFFF))),
                      ),
                child: Text(
                  format.shortLabel,
                  maxLines: 1,
                  style: TextStyle(
                    inherit: false,
                    color: Colors.white,
                    fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                    fontFamilyFallback: DefaultTextStyle.of(context).style.fontFamilyFallback,
                    fontSize: 9.5 * scale,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .5 * scale,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BadgeBox extends StatelessWidget {
  const _BadgeBox({required this.size, required this.scale, required this.child, this.border, this.color});

  final MediaFormatBadgeSize size;
  final double scale;
  final Widget child;
  final BoxBorder? border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.height * scale,
      padding: EdgeInsets.symmetric(horizontal: size.padding * scale),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, border: border, borderRadius: BorderRadius.circular(size.radius * scale)),
      child: child,
    );
  }
}

class _FormatWordmark extends StatelessWidget {
  const _FormatWordmark({required this.format, required this.size, required this.scale, required this.color});

  final MediaFormat format;
  final MediaFormatBadgeSize size;
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final heavy = _wordmarkStyle(size, scale, color, FontWeight.w600);
    final dolbyProduct = format.dolbyProduct;
    if (dolbyProduct == null) return Text(format.shortLabel, maxLines: 1, style: heavy);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'DOLBY ', style: heavy),
          TextSpan(
            text: dolbyProduct,
            style: heavy.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}

TextStyle _wordmarkStyle(MediaFormatBadgeSize size, double scale, Color color, FontWeight weight) => TextStyle(
  color: color,
  fontSize: size.fontSize * scale,
  height: 1,
  fontWeight: weight,
  letterSpacing: .5 * scale,
  fontFeatures: const [FontFeature.tabularFigures()],
);
