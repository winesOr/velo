import 'package:flutter/material.dart';

/// Neutral interface surfaces, independent of artwork and the Velo accent.
abstract final class VeloPalette {
  static const darkBackground = Color(0xff121212);
  static const darkSurface = Color(0xff202020);
  static const darkText = Color(0xfff3f3ef);
  static const darkCaption = Color(0xffadada8);
  static const darkEdge = Color(0x18ffffff);
  static const lightBackground = Color(0xfff4f3ef);
  static const lightSurface = Color(0xfffdfcf9);
  static const lightText = Color(0xff242424);
  static const lightCaption = Color(0xff686864);
  static const lightEdge = Color(0x18242424);
  static const oledBackground = Color(0xff000000);
  static const oledSurface = Color(0xff0a0a0a);

  static Color background(Brightness brightness) => brightness == Brightness.dark ? darkBackground : lightBackground;
  static Color surface(Brightness brightness) => brightness == Brightness.dark ? darkSurface : lightSurface;
  static Color text(Brightness brightness) => brightness == Brightness.dark ? darkText : lightText;
  static Color caption(Brightness brightness) => brightness == Brightness.dark ? darkCaption : lightCaption;
  static Color edge(Brightness brightness) => brightness == Brightness.dark ? darkEdge : lightEdge;
}

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
