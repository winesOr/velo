import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../danmaku/danmaku_session.dart';
import '../../i18n/strings.g.dart';
import '../../widgets/overlay_sheet.dart';
import '../../widgets/setting_tile.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/video_controls/sheets/danmaku_settings_sheet.dart';

/// A navigation surface, never a second copy of the playback configuration.
class DanmakuSettingsEntry extends StatefulWidget {
  final DanmakuSession? session;
  final bool grouped;
  final bool compact;

  const DanmakuSettingsEntry({super.key, this.session, this.grouped = true, this.compact = false});

  @override
  State<DanmakuSettingsEntry> createState() => _DanmakuSettingsEntryState();
}

class _DanmakuSettingsEntryState extends State<DanmakuSettingsEntry> {
  late final current = widget.session ?? DanmakuSession.instance;
  late Future<void> _initialization = current.initialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) => ListenableBuilder(
        listenable: current,
        builder: (context, _) {
          final tile = SettingNavigationTile(
            icon: Symbols.chat_rounded,
            title: t.danmaku.title,
            value: widget.compact && !snapshot.hasError
                ? current.sources.isEmpty
                      ? t.settings.noDanmakuSources
                      : t.danmaku.sourceCount(count: current.sources.length)
                : null,
            subtitle: snapshot.hasError
                ? t.danmaku.loadingFailed
                : widget.compact
                ? null
                : '${t.danmaku.fontSizeValue(value: current.fontSize.round().toString())} · '
                      '${t.danmaku.opacity} ${(current.opacity * 100).round()}%',
            onTap: snapshot.hasError
                ? () => setState(() => _initialization = current.initialize())
                : () {
                    if (widget.compact) {
                      Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => DanmakuSettingsPage(session: current)));
                    } else {
                      OverlaySheetController.of(context).show(builder: (_) => DanmakuSettingsSheet(session: current));
                    }
                  },
          );
          return widget.grouped ? SettingsGroup(title: t.danmaku.title, children: [tile]) : tile;
        },
      ),
    );
  }
}
