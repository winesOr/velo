import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/theme/home_typography.dart';
import 'package:plezy/theme/mono_presentation.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/app_icon.dart';

/// `monoTheme` builds a full `ColorScheme`, an applied+copyWith'd Typography
/// `TextTheme`, ~14 sub-theme objects, and then clones the whole `ThemeData`
/// again via `copyWith(extensions:)`. It used to run five times per cold start —
/// two of them before `runApp`, on the critical path to first frame — and twice
/// more on every app-shell rebuild. It is memoized now, so these tests pin the
/// two properties that make that safe: stable identity per palette, and a cache
/// key that includes every input the builder actually reads.
void main() {
  testWidgets('shared page titles are compact and default action icons remain linear', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: monoTheme(dark: false),
        home: Builder(
          builder: (context) => Column(
            children: [
              Text('Settings', style: MonoPresentation.pageTitle(context)),
              const AppIcon(Symbols.settings_rounded),
            ],
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('Settings')).style!.fontSize, 22);
    final icon = tester.widget<Icon>(find.byIcon(Symbols.settings_rounded));
    expect(icon.fill, 0);
    expect(icon.weight, 400);
    final light = monoTheme(dark: false);
    final dark = monoTheme(dark: true);
    expect(light.scaffoldBackgroundColor, const Color(0xfff1f0f6));
    expect(light.colorScheme.onSurface, const Color(0xff2d2e40));
    expect(dark.colorScheme.onSurface, const Color(0xffececf3));
  });

  test('repeated calls return the identical instance per palette', () {
    expect(identical(monoTheme(dark: false), monoTheme(dark: false)), isTrue);
    expect(identical(monoTheme(dark: true), monoTheme(dark: true)), isTrue);
    expect(identical(monoTheme(dark: true, oled: true), monoTheme(dark: true, oled: true)), isTrue);
  });

  test('the three palettes are distinct instances', () {
    final light = monoTheme(dark: false);
    final dark = monoTheme(dark: true);
    final oled = monoTheme(dark: true, oled: true);

    expect(identical(light, dark), isFalse);
    expect(identical(dark, oled), isFalse);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    // Both use a black page; OLED retains darker raised surfaces.
    expect(oled.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(oled.colorScheme.surface, isNot(dark.colorScheme.surface));
  });

  test('oled normalizes dark, so it cannot produce a light OLED theme', () {
    // ThemeProvider.darkThemeFor only ever asks for oled alongside dark, but the
    // signature allows dark:false — collapsing it keeps the cache at three
    // palette states instead of four, and a light OLED theme is meaningless.
    expect(identical(monoTheme(dark: false, oled: true), monoTheme(dark: true, oled: true)), isTrue);
    expect(monoTheme(dark: false, oled: true).brightness, Brightness.dark);
  });

  test('palette colours are unchanged by memoization', () {
    // Guards against a cache key that accidentally collapses two palettes.
    final light = monoTheme(dark: false);
    final dark = monoTheme(dark: true);

    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, isNot(dark.scaffoldBackgroundColor));
    expect(light.colorScheme.onSurface, isNot(dark.colorScheme.onSurface));
  });

  test('home text stays white in both appearances and across artwork palettes', () {
    for (final dark in [false, true]) {
      for (final surface in const [Color(0xff550b08), Color(0xffe4ca98)]) {
        final home = HomeTypography.apply(monoTheme(dark: dark), tv: false, artworkSurface: surface);
        final typography = home.extension<HomeTypography>()!;
        expect(home.brightness, dark ? Brightness.dark : Brightness.light);
        expect(typography.heroTitle.color, Colors.white);
        expect(typography.sectionTitle.color, Colors.white);
        expect(typography.caption.color, Colors.white);
        expect(typography.cardTitle.color, Colors.white);
        expect(home.textTheme.bodyMedium!.color, Colors.white);
      }
    }
  });

  test('artwork surface retains the sampled color in both appearances', () {
    const sampled = Color(0xff550b08);
    expect(MonoPresentation.artworkSurface(sampled, Brightness.light), sampled);
    expect(MonoPresentation.artworkSurface(sampled, Brightness.dark), sampled);
  });

  test('artwork foreground and captions use the same fixed white ink', () {
    for (final surface in const [Color(0xff550b08), Color(0xff142540), Color(0xffe4ca98)]) {
      expect(MonoPresentation.artworkTextColors(surface), (foreground: Colors.white, caption: Colors.white));
    }
  });

  test('filled and elevated buttons look disabled when disabled', () {
    for (final theme in [monoTheme(dark: false), monoTheme(dark: true)]) {
      for (final style in [theme.filledButtonTheme.style!, theme.elevatedButtonTheme.style!]) {
        final enabledBackground = style.backgroundColor!.resolve(const {});
        final disabledBackground = style.backgroundColor!.resolve(const {WidgetState.disabled});
        final enabledForeground = style.foregroundColor!.resolve(const {});
        final disabledForeground = style.foregroundColor!.resolve(const {WidgetState.disabled});

        expect(disabledBackground, isNot(enabledBackground));
        expect(disabledForeground, isNot(enabledForeground));
        expect(disabledBackground!.a, lessThan(enabledBackground!.a));
      }
    }
  });

  group('target platform is part of the cache key', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('each platform gets a theme carrying that platform', () {
      // ThemeData() derives platform defaults (tap target size, visual density,
      // typography) from defaultTargetPlatform. Keying only on the palette would
      // hand an Android-derived theme to a test or debug run overriding to iOS.
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(monoTheme(dark: true).platform, platform);
      }
    });

    test('two platforms do not share an instance, and returning restores identity', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final android = monoTheme(dark: true);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = monoTheme(dark: true);
      expect(identical(android, ios), isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(identical(monoTheme(dark: true), android), isTrue);
    });

    test('only Linux falls back to the bundled CJK fonts', () {
      // Linux resolves UI text through fontconfig, which on a minimal desktop
      // has no CJK font; the bundled fallback must reach the styles widgets
      // read, including the ones mono_theme replaces via copyWith, despite the
      // explicit textTheme being merged over ThemeData's platform defaults.
      const bundled = ['Go Noto Current', 'Go Noto Current Hangul'];
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final linux = monoTheme(dark: true).textTheme;
      expect(linux.bodyMedium!.fontFamilyFallback, bundled);
      expect(linux.titleMedium!.fontFamilyFallback, bundled);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(monoTheme(dark: true).textTheme.bodyMedium!.fontFamilyFallback, isNull);
    });
  });
}
