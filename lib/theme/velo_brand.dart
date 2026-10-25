import 'package:flutter/material.dart';

/// The folded Velo mark supplies the interface accent. Media artwork and
/// backend identities retain their own colours; transport controls stay white.
abstract final class VeloBrand {
  static const accent = Color(0xff6060f5);
  static const heatmapPeak = Color(0x807e70be);
  static const heatmapBase = Color(0x335d5197);

  static Color foreground(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xffb4aaff) : const Color(0xff6256c8);

  static Color selection(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xff36324e) : const Color(0xffe9e5f6);
}
