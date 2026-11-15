import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/screens/settings/about_screen.dart';
import 'package:plezy/screens/settings/licenses_screen.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/utils/platform_detector.dart';
import 'package:plezy/utils/project_licenses.dart';

void main() {
  testWidgets('about preserves upstream attribution and opens bundled GPL and dependency licenses', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    PackageInfo.setMockInitialValues(
      appName: 'Velo',
      packageName: 'com.velo.app',
      version: '2.23.23',
      buildNumber: '4204',
      buildSignature: '',
    );
    PlatformDetector.debugSetIsDesktopOSOverride(false);
    TvDetectionService.debugSetAppleTVOverride(false);
    addTearDown(() {
      PlatformDetector.debugSetIsDesktopOSOverride(null);
      TvDetectionService.debugSetAppleTVOverride(null);
    });
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ProjectLicenses.register();
    ProjectLicenses.register();
    final projectEntries = await tester.runAsync(() async {
      return LicenseRegistry.licenses.where((entry) => entry.packages.contains('Velo')).toList();
    });
    expect(projectEntries, hasLength(1), reason: 'registration must be idempotent');
    expect(projectEntries!.single.packages, contains('Plezy'));
    expect(projectEntries.single.paragraphs.map((p) => p.text).join('\n'), contains('GNU GENERAL PUBLIC LICENSE'));

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(theme: monoTheme(dark: true), home: const AboutScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.about.projectAttribution), findsOneWidget);
    expect(find.text(t.about.upstreamProject), findsOneWidget);
    expect(find.text('github.com/edde746/plezy'), findsOneWidget);
    expect(find.text('github.com/winesOr/velo'), findsOneWidget);
    expect(find.text(t.about.copyright), findsOneWidget);

    // The bundled-license future was loaded outside fake async. Build its
    // listener there too, then return to the widget clock for route animation.
    await tester.runAsync(() async {
      await tester.tap(find.text(t.about.gplLicense));
      await tester.pump();
      await ProjectLicenses.license;
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(ProjectLicenseScreen), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is SelectableText && w.data!.contains('GNU GENERAL PUBLIC LICENSE')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(t.about.openSourceLicenses));
    await tester.runAsync(() async {
      await tester.tap(find.text(t.about.openSourceLicenses));
      await tester.pump();
      // Registry entries can read assets, which must run on the real clock.
      await LicenseRegistry.licenses.toList();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(LicensesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
