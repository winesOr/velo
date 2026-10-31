import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../widgets/settings_page.dart';
import '../../widgets/setting_tile.dart';
import '../../widgets/settings_section.dart';
import '../../i18n/strings.g.dart';
import '../../theme/mono_tokens.dart';
import 'licenses_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final appName = t.app.title;

    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snapshot) {
        final appVersion = snapshot.data?.version ?? '';
        return SettingsPage.slivers(
          title: Text(t.about.title),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Image.asset('assets/velo.png', width: 80, height: 80),
                        const SizedBox(height: 16),
                        Text(appName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: .bold)),
                        const SizedBox(height: 8),
                        Text(
                          t.about.versionLabel(version: appVersion),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens(context).textMuted),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            t.about.appDescription,
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  SettingsGroup(
                    children: [
                      SettingNavigationTile(
                        icon: Symbols.description_rounded,
                        title: t.about.openSourceLicenses,
                        subtitle: t.about.viewLicensesDescription,
                        destinationBuilder: (context) => const LicensesScreen(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}
