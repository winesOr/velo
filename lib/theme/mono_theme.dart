import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'glass_slider_thumb_shape.dart';
import '../utils/platform_detector.dart';
import 'mono_tokens.dart';
import 'velo_brand.dart';

final Map<({bool dark, bool oled, TargetPlatform platform, bool tv}), ThemeData> _monoThemeCache = {};

ThemeData monoTheme({required bool dark, bool oled = false}) {
  // ThemeData derives several defaults from defaultTargetPlatform.
  final key = (dark: dark || oled, oled: oled, platform: defaultTargetPlatform, tv: PlatformDetector.isTV());
  final cached = _monoThemeCache[key];
  if (cached != null) return cached;

  final theme = _buildMonoTheme(dark: key.dark, oled: key.oled, platform: key.platform, tv: key.tv);
  _monoThemeCache[key] = theme;
  return theme;
}

/// Handheld and desktop follow the prototype scale (body 14, list title 15,
/// section 18, page 22, caption 12); TV keeps Material's larger sizes for
/// ten-foot reading. Sizes are logical points, so the system text scale still
/// applies on top.
TextTheme _textTheme(Color text, Color muted, {required bool compact}) {
  final base = Typography.englishLike2021.apply(bodyColor: text, displayColor: text);
  if (!compact) {
    return base.copyWith(
      displayLarge: const TextStyle(fontWeight: .w700, letterSpacing: -0.5),
      titleMedium: const TextStyle(fontWeight: .w600),
      titleLarge: TextStyle(color: text, fontSize: 20, fontWeight: .w600),
      bodyMedium: TextStyle(color: text),
      bodySmall: TextStyle(color: muted),
    );
  }
  return base.copyWith(
    displayLarge: const TextStyle(fontWeight: .w700, letterSpacing: -0.5),
    headlineSmall: TextStyle(color: text, fontSize: 22, fontWeight: .w600, height: 1.25, letterSpacing: -0.3),
    titleLarge: TextStyle(color: text, fontSize: 18, fontWeight: .w600, height: 1.3, letterSpacing: -0.2),
    titleMedium: TextStyle(color: text, fontSize: 15, fontWeight: .w600, height: 1.35),
    titleSmall: TextStyle(color: text, fontSize: 14, fontWeight: .w600, height: 1.35),
    bodyLarge: TextStyle(color: text, fontSize: 15, height: 1.45),
    bodyMedium: TextStyle(color: text, fontSize: 14, height: 1.45),
    bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.4),
    labelLarge: TextStyle(color: text, fontSize: 14, fontWeight: .w600),
    labelMedium: TextStyle(color: text, fontSize: 12, fontWeight: .w500),
    labelSmall: TextStyle(color: muted, fontSize: 11, fontWeight: .w500),
  );
}

ThemeData _buildMonoTheme({required bool dark, required bool oled, required TargetPlatform platform, bool tv = false}) {
  // Pearl neutrals carry a restrained hint of the folded mark's violet.
  final ({Color bg, Color surface, Color outline, Color text, Color textMuted}) c;
  if (oled) {
    c = (
      bg: const Color(0xFF000000), // Pure black for OLED
      surface: const Color(0xFF0A0A0A), // Very dark gray
      outline: const Color(0x1FFFFFFF),
      text: const Color(0xFFEDEDED),
      textMuted: const Color(0x99EDEDED),
    );
  } else if (dark) {
    c = (
      bg: const Color(0xFF000000),
      surface: const Color(0xFF20212B),
      outline: const Color(0x14FFFFFF),
      text: const Color(0xFFECECF3),
      textMuted: const Color(0xFFA6A7B8),
    );
  } else {
    c = (
      bg: const Color(0xFFF1F0F6),
      surface: const Color(0xFFFFFFFF),
      outline: const Color(0x19000000),
      text: const Color(0xFF2D2E40),
      textMuted: const Color(0xFF686B80),
    );
  }

  final isDark = dark || oled;
  final clickableCursor = WidgetStateProperty.resolveWith<MouseCursor>(
    (states) => states.contains(WidgetState.disabled) ? MouseCursor.defer : SystemMouseCursors.click,
  );

  // Disabled buttons use the Material disabled opacities over the text colour;
  // a flat colour for every state made them look pressable.
  final buttonStyle = ButtonStyle(
    mouseCursor: clickableCursor,
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? c.text.withValues(alpha: 0.12) : VeloBrand.accent,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? c.text.withValues(alpha: 0.38) : Colors.white,
    ),
    shape: const WidgetStatePropertyAll(StadiumBorder()),
  );

  final base = ThemeData(
    platform: platform,
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    // Linux resolves UI text through fontconfig, which on a minimal desktop
    // may have no CJK font at all; the bundled subtitle fonts (pubspec
    // `fonts:`) cover it. Other platforms keep their native CJK fonts.
    fontFamilyFallback: platform == TargetPlatform.linux ? const ['Go Noto Current', 'Go Noto Current Hangul'] : null,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: VeloBrand.foreground(isDark ? Brightness.dark : Brightness.light),
      onPrimary: isDark ? const Color(0xff211b3b) : Colors.white,
      secondary: VeloBrand.foreground(isDark ? Brightness.dark : Brightness.light),
      onSecondary: isDark ? const Color(0xff211b3b) : Colors.white,
      surface: c.surface,
      onSurface: c.text,
      error: const Color(0xFFB00020),
      onError: Colors.white,
      tertiary: VeloBrand.foreground(isDark ? Brightness.dark : Brightness.light),
      onTertiary: isDark ? const Color(0xff211b3b) : Colors.white,
      primaryContainer: VeloBrand.selection(isDark ? Brightness.dark : Brightness.light),
      onPrimaryContainer: VeloBrand.foreground(isDark ? Brightness.dark : Brightness.light),
      secondaryContainer: VeloBrand.selection(isDark ? Brightness.dark : Brightness.light),
      onSecondaryContainer: VeloBrand.foreground(isDark ? Brightness.dark : Brightness.light),
      surfaceContainerHighest: c.surface,
      surfaceContainerLow: c.bg,
      surfaceDim: c.bg,
      surfaceBright: c.surface,
      outline: c.outline,
      shadow: Colors.transparent,
      scrim: Colors.black,
      inverseSurface: c.text,
      onInverseSurface: c.bg,
      inversePrimary: c.bg,
    ),
    // remove "Material feel"
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // Explicit mono-derived tile highlights: ListTile's native focus/hover
    // fill is the dpad focus visual inside M3E grouped-list cards.
    focusColor: c.text.withValues(alpha: 0.12),
    hoverColor: c.text.withValues(alpha: 0.05),
    dividerColor: c.outline,
    scaffoldBackgroundColor: c.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: c.text,
      titleTextStyle: TextStyle(color: c.text, fontSize: 22, fontWeight: .w600, letterSpacing: -0.4),
    ),
    textTheme: _textTheme(c.text, c.textMuted, compact: !tv),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: .zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),
    inputDecorationTheme: _inputDecorationTheme(c.text, c.textMuted),
    elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: ButtonStyle(mouseCursor: clickableCursor)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(mouseCursor: clickableCursor)),
    iconButtonTheme: IconButtonThemeData(style: ButtonStyle(mouseCursor: clickableCursor)),
    sliderTheme: SliderThemeData(
      // The mono scheme maps surfaceContainerHighest (the M3 default inactive
      // track) to the same color as surface cards, which makes the inactive
      // track invisible inside grouped-list items.
      // Slim rounded track with a white knob; replaces the thick gapped M3
      // track, which read as a heavy block in the player's glass panels.
      activeTrackColor: c.text.withValues(alpha: 0.92),
      inactiveTrackColor: c.text.withValues(alpha: 0.16),
      trackHeight: 4,
      trackShape: const RoundedRectSliderTrackShape(),
      thumbShape: const GlassSliderThumbShape(),
      overlayShape: SliderComponentShape.noOverlay,
      tickMarkShape: SliderTickMarkShape.noTickMark,
      // ignore: deprecated_member_use — opting into the 2024 slider appearance until the default flips
      year2023: false,
    ),
    dividerTheme: DividerThemeData(space: 0, thickness: 1, color: c.outline),
    listTileTheme: ListTileThemeData(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      iconColor: c.text,
      textColor: c.text,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.bg,
      elevation: 0,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(color: c.textMuted, fontSize: 11)),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(
          opacity: active ? 1 : 0.6,
          size: 22,
          color: active ? VeloBrand.foreground(isDark ? Brightness.dark : Brightness.light) : c.text,
        );
      }),
    ),
    // Floating snackbars auto-offset above the Scaffold's bottom NavigationBar,
    // so they don't cover it on mobile. Background color tracks the theme to
    // avoid jarring brightness on HDR playback / dark mode.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surface,
      contentTextStyle: TextStyle(color: c.text),
      actionTextColor: c.text,
      elevation: 6,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      insetPadding: const EdgeInsets.all(16),
    ),
  );

  return base.copyWith(
    extensions: [
      MonoTokens(
        radiusSm: 8,
        radiusMd: 12,
        radiusLg: 20,
        radiusXs: 5,
        groupGap: 2,
        space: 12,
        fast: const Duration(milliseconds: 120),
        normal: const Duration(milliseconds: 200),
        slow: const Duration(milliseconds: 300),
        expressive: const Duration(milliseconds: 350),
        bg: c.bg,
        surface: c.surface,
        outline: c.outline,
        text: c.text,
        textMuted: c.textMuted,
      ),
    ],
  );
}

/// Brighter fill on focus so input focus is visible inside TV overscan.
InputDecorationTheme _inputDecorationTheme(Color text, Color textMuted) {
  final unfocusedFill = text.withValues(alpha: 0.08);
  final focusedFill = text.withValues(alpha: 0.18);
  const border = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none);
  return InputDecorationTheme(
    filled: true,
    fillColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.focused) ? focusedFill : unfocusedFill,
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    hintStyle: TextStyle(color: textMuted),
  );
}
