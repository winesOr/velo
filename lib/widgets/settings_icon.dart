import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'app_icon.dart';

/// Settings category glyphs use the approved prototype's 24 × 24 paths.
/// Other settings retain their existing symbols.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {super.key, this.size, this.color});

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final path = switch (icon) {
      Symbols.play_circle_rounded => '<path d="m8 4 12 8-12 8Z" fill="currentColor" stroke-width="0"/>',
      Symbols.subtitles_rounded =>
        '<rect x="2" y="5" width="20" height="14" rx="3"/><path d="M6 11h4m4 0h4M6 15h7m3 0h2"/>',
      Symbols.chat_rounded =>
        '<rect x="2" y="4" width="20" height="15" rx="3"/><path d="M6 9h5m3 0h4M6 14h8m3 0h1M7 19v3l4-3"/>',
      Symbols.dns_rounded =>
        '<rect x="3" y="3" width="18" height="7" rx="2"/><rect x="3" y="14" width="18" height="7" rx="2"/><path d="M7 6.5h.01M7 17.5h.01M16 6.5h2M16 17.5h2"/>',
      Symbols.language_rounded || Symbols.network_check_rounded =>
        '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/>',
      Symbols.info_rounded => '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7h.01"/>',
      Symbols.groups_rounded =>
        '<circle cx="9" cy="8" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3M16 5a3 3 0 0 1 0 6m2 3a5 5 0 0 1 3 4v3"/>',
      Symbols.palette_rounded =>
        '<path d="M12 3a9 9 0 1 0 0 18h1a2 2 0 0 0 0-4h-1a2 2 0 0 1 0-4h4c5 0 6-3 3-6a10 10 0 0 0-7-4Z"/><path d="M7 8h.01M12 6h.01M17 8h.01M5 13h.01" stroke-width="3"/>',
      Symbols.download_rounded => '<path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5"/>',
      _ => null,
    };
    if (path == null) return AppIcon(icon, size: size, color: color);
    final theme = IconTheme.of(context);
    final extent = size ?? theme.size ?? 24;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke="currentColor" stroke-width="1.7" '
      'stroke-linecap="round" stroke-linejoin="round">$path</svg>',
      width: extent,
      height: extent,
      theme: SvgTheme(currentColor: color ?? theme.color ?? Theme.of(context).colorScheme.onSurface),
      excludeFromSemantics: true,
    );
  }
}
