import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../i18n/strings.g.dart';
import '../../services/settings_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/dialogs.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/setting_tile.dart';
import '../../widgets/settings_page.dart';
import '../../widgets/settings_section.dart';
import 'playback_settings_screen.dart';
import 'server_routes_screen.dart';

class NetworkCacheSettingsScreen extends StatefulWidget {
  const NetworkCacheSettingsScreen({super.key, this.imageCacheClearer});

  @visibleForTesting
  final Future<void> Function()? imageCacheClearer;

  @override
  State<NetworkCacheSettingsScreen> createState() => _NetworkCacheSettingsScreenState();
}

class _NetworkCacheSettingsScreenState extends State<NetworkCacheSettingsScreen> {
  bool _pending = false;
  bool _clearing = false;

  Future<void> _clearImageCache() async {
    if (_pending) return;
    _pending = true;
    try {
      final confirmed = await showConfirmDialog(
        context,
        title: t.settings.clearImageCache,
        message: t.settings.clearImageCacheDescription,
        confirmText: t.common.clear,
      );
      if (!confirmed || !mounted) return;
      setState(() => _clearing = true);
      await (widget.imageCacheClearer ?? SettingsService.instance.clearImageCache)();
      if (mounted) showSuccessSnackBar(context, t.settings.clearImageCacheSuccess);
    } catch (error, stackTrace) {
      appLogger.e('Image cache cleanup failed', error: error, stackTrace: stackTrace);
      if (mounted) showErrorSnackBar(context, t.settings.clearImageCacheFailed);
    } finally {
      _pending = false;
      if (mounted && _clearing) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: Text(t.settings.networkCache),
    children: [
      SettingsGroup(
        title: t.routes.title,
        children: [
          SettingNavigationTile(
            icon: Symbols.route_rounded,
            title: t.routes.serverRoutes,
            subtitle: t.routes.entryDescription,
            destinationBuilder: (_) => const ServerRoutesScreen(),
          ),
        ],
      ),
      SettingsGroup(
        title: t.settings.homeCache,
        children: [
          ListTile(
            leading: const AppIcon(Symbols.home_rounded),
            title: Text(t.settings.homeCacheAutomatic),
            subtitle: Text(t.settings.homeCacheAutomaticDescription),
          ),
        ],
      ),
      SettingsGroup(
        title: t.settings.imageCache,
        children: [
          SettingNavigationTile(
            icon: Symbols.cleaning_services_rounded,
            title: t.settings.clearImageCache,
            subtitle: t.settings.clearImageCacheDescription,
            value: _clearing ? t.common.loading : null,
            onTap: _clearImageCache,
          ),
        ],
      ),
      SettingsGroup(
        title: t.settings.playbackBuffer,
        children: [
          SettingNavigationTile(
            icon: Symbols.play_circle_rounded,
            title: t.settings.videoPlayback,
            subtitle: t.settings.playbackCacheDescription,
            destinationBuilder: (_) => const PlaybackSettingsScreen(),
          ),
        ],
      ),
    ],
  );
}
