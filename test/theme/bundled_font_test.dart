import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/theme/home_typography.dart';
import 'package:plezy/theme/mono_theme.dart';

void main() {
  tearDown(() => LocaleSettings.setLocale(AppLocale.en));

  test('theme uses the bundled Noto Sans SC except for ja and ko', () async {
    await LocaleSettings.setLocale(AppLocale.zh);
    expect(monoTheme(dark: false).textTheme.bodyMedium!.fontFamily, 'Noto Sans SC');
    await LocaleSettings.setLocale(AppLocale.ja);
    expect(monoTheme(dark: false).textTheme.bodyMedium!.fontFamily, isNot('Noto Sans SC'));
    await LocaleSettings.setLocale(AppLocale.ko);
    expect(monoTheme(dark: true).textTheme.bodyMedium!.fontFamily, isNot('Noto Sans SC'));
  });

  test('home typography follows the revised scale and weights', () {
    expect(HomeTypography.heroTitleSize(tv: false, tablet: false), 36);
    expect(HomeTypography.heroTitleSize(tv: false, tablet: false, viewportWidth: 320), 32);
    expect(HomeTypography.heroTitleSize(tv: true, tablet: false), 42);
    final t = HomeTypography.apply(monoTheme(dark: true), tv: false).extension<HomeTypography>()!;
    expect(t.heroTitle.fontWeight, FontWeight.w500);
    expect(t.heroTitle.letterSpacing, -0.3);
    expect(t.sectionTitle.fontSize, 17);
    expect(t.sectionTitle.fontWeight, FontWeight.w500);
    expect(t.cardTitle.fontWeight, FontWeight.w400);
  });
}
