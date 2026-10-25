import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../i18n/strings.g.dart';
import '../screens/settings/settings_utils.dart';
import '../services/settings_service.dart';
import 'setting_tile.dart';

List<DialogOption<bool>> _coreOptions() => [
  DialogOption(value: false, title: t.settings.mpv),
  DialogOption(value: true, title: t.settings.exoPlayer),
];

/// Returns a choice without changing the preference or the running player.
Future<bool?> showPlayerCorePicker(BuildContext context, {required bool currentUsesExo}) async {
  final picked = await showSelectionDialog<bool>(
    context: context,
    title: t.settings.playerBackend,
    currentValue: currentUsesExo,
    options: _coreOptions(),
  );
  return picked?.value;
}

class PlayerCoreSettingTile extends StatelessWidget {
  const PlayerCoreSettingTile({super.key});

  @override
  Widget build(BuildContext context) => SettingSelectionTile<bool>(
    pref: SettingsService.useExoPlayer,
    icon: Symbols.play_circle_rounded,
    title: t.settings.playerBackend,
    subtitleBuilder: (useExo) => useExo ? t.settings.exoPlayer : t.settings.mpv,
    options: _coreOptions(),
  );
}
