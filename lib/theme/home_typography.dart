import 'package:flutter/material.dart';

import 'mono_presentation.dart';
import 'mono_tokens.dart';

/// Home-only type hierarchy. Retains platform fonts and system text scaling.
class HomeTypography extends ThemeExtension<HomeTypography> {
  const HomeTypography({
    required this.heroTitle,
    required this.sectionTitle,
    required this.cardTitle,
    required this.caption,
  });

  final TextStyle heroTitle;
  final TextStyle sectionTitle;
  final TextStyle cardTitle;
  final TextStyle caption;

  static double heroTitleSize({required bool tv, required bool tablet, double viewportWidth = double.infinity}) =>
      tv ? 42 : (viewportWidth < 360 ? 32 : 36);

  static ThemeData apply(ThemeData theme, {required bool tv, bool tablet = false, Color? artworkSurface}) {
    final body = theme.textTheme.bodyMedium!;
    final ink = MonoPresentation.artworkTextColors(
      artworkSurface ?? theme.scaffoldBackgroundColor,
      brightness: theme.brightness,
      highContrastCaption: true,
    );
    final foreground = artworkSurface != null ? ink.foreground : theme.colorScheme.onSurface;
    final caption = ink.caption;
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(onSurface: foreground, onSurfaceVariant: caption),
      textTheme: theme.textTheme.apply(bodyColor: foreground, displayColor: foreground),
      iconTheme: theme.iconTheme.copyWith(color: foreground),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: foreground)),
      extensions: [
        for (final extension in theme.extensions.values)
          if (extension is MonoTokens)
            extension.copyWith(text: foreground, textMuted: caption)
          else if (extension is! HomeTypography)
            extension,
        HomeTypography(
          heroTitle: body.copyWith(
            color: foreground,
            fontSize: heroTitleSize(tv: tv, tablet: tablet),
            fontWeight: FontWeight.w500,
            height: 1.1,
            letterSpacing: -0.3,
          ),
          sectionTitle: body.copyWith(
            color: foreground,
            fontSize: tv ? 24 : (tablet ? 21 : 17),
            fontWeight: FontWeight.w500,
            height: 1.3,
            letterSpacing: 0,
          ),
          cardTitle: body.copyWith(
            color: foreground,
            fontSize: tablet ? 14 : 13,
            fontWeight: FontWeight.w400,
            height: 1.5,
            letterSpacing: 0,
          ),
          caption: body.copyWith(
            color: caption,
            fontSize: tablet ? 12 : 11,
            fontWeight: FontWeight.w500,
            height: 1.5,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  @override
  HomeTypography copyWith({TextStyle? heroTitle, TextStyle? sectionTitle, TextStyle? cardTitle, TextStyle? caption}) =>
      HomeTypography(
        heroTitle: heroTitle ?? this.heroTitle,
        sectionTitle: sectionTitle ?? this.sectionTitle,
        cardTitle: cardTitle ?? this.cardTitle,
        caption: caption ?? this.caption,
      );

  @override
  HomeTypography lerp(covariant HomeTypography? other, double t) => other == null
      ? this
      : HomeTypography(
          heroTitle: TextStyle.lerp(heroTitle, other.heroTitle, t)!,
          sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
          cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
          caption: TextStyle.lerp(caption, other.caption, t)!,
        );
}
