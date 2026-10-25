import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum DetailActionGlyph { play, favorite, watched, more, down, next }

/// Linear paths shared with the approved detail prototype (24 × 24 view box).
class DetailActionIcon extends StatelessWidget {
  const DetailActionIcon(this.glyph, {super.key, this.selected = false, this.size = 22});

  final DetailActionGlyph glyph;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = switch (glyph) {
      DetailActionGlyph.play => '<path d="m8 4 12 8-12 8Z" fill="currentColor" stroke-width="0"/>',
      DetailActionGlyph.favorite =>
        '<path d="M20.8 5.6a5.5 5.5 0 0 0-8.8.7 5.5 5.5 0 0 0-8.8-.7C-1 10.5 5.2 16.5 12 21c6.8-4.5 13-10.5 8.8-15.4Z"/>',
      DetailActionGlyph.watched => '<path d="M5 22V3c5-4 9 4 14 0v11c-5 4-9-4-14 0"/>',
      DetailActionGlyph.more =>
        '<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
      DetailActionGlyph.down => '<path d="m6 9 6 6 6-6"/>',
      DetailActionGlyph.next => '<path d="m9 5 7 7-7 7"/>',
    };
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="${selected ? '#ffffff28' : 'none'}" stroke="currentColor" stroke-width="1.7" '
      'stroke-linecap="round" stroke-linejoin="round">$path</svg>',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: IconTheme.of(context).color ?? Colors.white),
      excludeFromSemantics: true,
    );
  }
}
