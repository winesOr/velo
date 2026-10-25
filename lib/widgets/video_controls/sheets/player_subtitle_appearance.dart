import 'package:flutter/material.dart';

import '../../../i18n/strings.g.dart';
import '../../../mpv/mpv.dart';
import '../../../services/settings_service.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/error_message_utils.dart';
import '../../settings_builder.dart';
import 'player_settings_controls.dart';

class PlayerSubtitleAppearance extends StatefulWidget {
  const PlayerSubtitleAppearance({super.key, required this.player});
  final Player player;

  @override
  State<PlayerSubtitleAppearance> createState() => _PlayerSubtitleAppearanceState();
}

class _PlayerSubtitleAppearanceState extends State<PlayerSubtitleAppearance> {
  Future<void> _writes = Future.value();

  void _apply({int? fontSize, int? position}) {
    final player = widget.player;
    _writes = _writes
        .then((_) async {
          final settings = SettingsService.instance;
          if (fontSize != null) await settings.write(SettingsService.subtitleFontSize, fontSize);
          if (position != null) await settings.write(SettingsService.subtitlePosition, position);
          if (player.playerType != 'exoplayer') {
            if (fontSize != null) await player.setProperty('sub-font-size', '$fontSize');
            if (position != null) await player.setProperty('sub-pos', '$position');
          }
          await player.setSubtitleStyle(
            fontSize: settings.read(SettingsService.subtitleFontSize).toDouble(),
            textColor: settings.read(SettingsService.subtitleTextColor),
            borderSize: settings.read(SettingsService.subtitleBorderSize).toDouble(),
            borderColor: settings.read(SettingsService.subtitleBorderColor),
            bgColor: settings.read(SettingsService.subtitleBackgroundColor),
            bgOpacity: settings.read(SettingsService.subtitleBackgroundOpacity),
            subtitlePosition: settings.read(SettingsService.subtitlePosition),
            bold: settings.read(SettingsService.subtitleBold),
            italic: settings.read(SettingsService.subtitleItalic),
            anchorToScreen: settings.read(SettingsService.subtitleAnchorToScreen),
          );
        })
        .catchError((Object error, StackTrace stack) {
          if (mounted) showErrorSnackBar(context, t.messages.errorLoading(error: localizedErrorReason(error)));
        });
  }

  @override
  Widget build(BuildContext context) => SettingsBuilder(
    prefs: [SettingsService.subtitleFontSize, SettingsService.subtitlePosition],
    builder: (context) {
      final settings = SettingsService.instance;
      final font = settings.read(SettingsService.subtitleFontSize);
      final position = settings.read(SettingsService.subtitlePosition);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            PlayerDrawerRange(
              key: const ValueKey('player-subtitle-font-size'),
              label: t.subtitlingStyling.fontSize,
              valueText: '$font',
              value: font.toDouble(),
              min: 20,
              max: 80,
              divisions: 60,
              onChanged: (value) => _apply(fontSize: value.round()),
            ),
            PlayerDrawerRange(
              key: const ValueKey('player-subtitle-position'),
              label: t.subtitlingStyling.position,
              valueText: position == 100 ? t.subtitlingStyling.positionBottom : '$position%',
              value: position.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (value) => _apply(position: value.round()),
            ),
          ],
        ),
      );
    },
  );
}
