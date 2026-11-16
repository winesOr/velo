import 'package:flutter/material.dart';

import 'mono_presentation.dart';
import 'velo_brand.dart';

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
      tv ? 48 : (viewportWidth < 360 ? 37 : 45);

  static ThemeData apply(ThemeData theme, {required bool tv, bool tablet = false, Color? artworkSurface}) {
    final body = theme.textTheme.bodyMedium!;
    final artworkColors = artworkSurface == null ? null : MonoPresentation.artworkTextColors(artworkSurface);
    final foreground = artworkColors?.foreground ?? theme.colorScheme.onSurface;
    final caption = artworkColors?.caption ?? VeloPalette.caption(theme.brightness);
    return theme.copyWith(
      colorScheme: artworkSurface != null
          ? theme.colorScheme.copyWith(onSurface: foreground, onSurfaceVariant: caption)
          : theme.colorScheme,
      textTheme: theme.textTheme.apply(bodyColor: foreground, displayColor: foreground),
      iconTheme: theme.iconTheme.copyWith(color: foreground),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: foreground)),
      extensions: [
        ...theme.extensions.values.where((extension) => extension is! HomeTypography),
        HomeTypography(
          heroTitle: body.copyWith(
            color: foreground,
            fontSize: heroTitleSize(tv: tv, tablet: tablet),
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: -1.5,
          ),
          sectionTitle: body.copyWith(
            color: foreground,
            fontSize: tv ? 26 : (tablet ? 22 : 18),
            fontWeight: FontWeight.w600,
            height: 1.3,
            letterSpacing: -.3,
          ),
          cardTitle: body.copyWith(
            color: foreground,
            fontSize: tablet ? 14 : 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
            letterSpacing: 0,
          ),
          caption: body.copyWith(
            color: caption,
            fontSize: tablet ? 12 : 11,
            fontWeight: FontWeight.w400,
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
