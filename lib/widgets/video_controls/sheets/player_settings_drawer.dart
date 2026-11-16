import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../app_icon.dart';

import '../../../i18n/strings.g.dart';
import '../../../media/media_item.dart';
import '../../../danmaku/danmaku_session.dart';
import '../../../mpv/mpv.dart';
import '../../../services/settings_service.dart';
import '../../../theme/overlay_tokens.dart';
import '../../../services/video_volume_controller.dart';
import '../../../utils/platform_detector.dart';
import '../../../focus/focus_theme.dart';
import 'player_subtitle_appearance.dart';
import '../../focusable_list_tile.dart';
import '../../overlay_sheet.dart';
import '../../settings_builder.dart';
import '../models/track_controls_state.dart';
import 'base_video_control_sheet.dart';
import 'danmaku_settings_sheet.dart';
import 'track_sheet.dart';
import 'video_settings_sheet.dart';
import 'player_settings_controls.dart';

enum PlayerDrawerTab { video, audio, subtitles, danmaku }

/// The mobile player's "more" drawer: four segmented tabs over the existing
/// sheets, which render headerless inside it ([EmbeddedVideoControlSheet]).
class PlayerSettingsDrawer extends StatefulWidget {
  static double widthFor(BuildContext context) {
    if (!PlatformDetector.isTV()) return PlatformDetector.isTablet(context) ? 400 : OverlayTokens.drawerWidth;
    final width = MediaQuery.sizeOf(context).width;
    final maximum = width * .85;
    final minimum = maximum < 240 ? maximum : 240.0;
    return (width * 580 / 1920).clamp(minimum, maximum).toDouble();
  }

  const PlayerSettingsDrawer({
    super.key,
    required this.player,
    required this.state,
    required this.metadata,
    this.initialTab = PlayerDrawerTab.video,
    this.coreLabel,
    this.onSwitchCore,
    this.volumeController,
    this.danmakuSession,
  });

  final Player player;
  final DanmakuSession? danmakuSession;
  final VideoVolumeController? volumeController;
  final TrackControlsState state;
  final MediaItem? metadata;
  final PlayerDrawerTab initialTab;

  /// Running core label; defaults to the player's reported backend.
  final String? coreLabel;
  final VoidCallback? onSwitchCore;

  @override
  State<PlayerSettingsDrawer> createState() => _PlayerSettingsDrawerState();
}

class _PlayerSettingsDrawerState extends State<PlayerSettingsDrawer> {
  late PlayerDrawerTab _tab = widget.initialTab;
  final _contentFocus = FocusScopeNode(debugLabel: 'PlayerDrawerContent');
  final _tabFocus = List.generate(
    PlayerDrawerTab.values.length,
    (index) => FocusNode(debugLabel: 'PlayerDrawerTab$index'),
  );
  bool _initialContentFocus = true;
  bool _initialFocusScheduled = false;

  @override
  void dispose() {
    for (final node in _tabFocus) {
      node.dispose();
    }
    _contentFocus.dispose();
    super.dispose();
  }

  void _selectTab(PlayerDrawerTab tab) {
    _initialContentFocus = false;
    if (tab != _tab) setState(() => _tab = tab);
  }

  void _focusSelectedContent() {
    if (!mounted) return;
    final nodes = _contentFocus.traversalDescendants.toList();
    for (final node in nodes) {
      final choice = node.context?.findAncestorWidgetOfExactType<PlayerDrawerChoice>();
      if (choice?.selected == true && choice?.tab == false) {
        node.requestFocus();
        return;
      }
    }
    if (nodes.isNotEmpty) nodes.first.requestFocus();
  }

  void _enterContent(PlayerDrawerTab tab) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tab != tab || !_tabFocus[tab.index].hasFocus) return;
      _focusSelectedContent();
    });
  }

  void _scheduleInitialFocus() {
    if (!PlatformDetector.isTV() || !_initialContentFocus || _initialFocusScheduled) return;
    _initialFocusScheduled = true;
    // The sheet host first installs its focus scope. Select content afterwards,
    // unless the user has already navigated into the tabs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_initialContentFocus) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_initialContentFocus) return;
        _initialContentFocus = false;
        if (_contentFocus.hasFocus) return;
        _focusSelectedContent();
      });
    });
  }

  Widget _drawerBody() => EmbeddedVideoControlSheet(
    child: KeyedSubtree(key: ValueKey(_tab), child: _body()),
  );

  String _label(PlayerDrawerTab tab) => switch (tab) {
    PlayerDrawerTab.video => t.videoControls.tabVideo,
    PlayerDrawerTab.audio => t.videoControls.tabAudio,
    PlayerDrawerTab.subtitles => t.videoControls.tabSubtitles,
    PlayerDrawerTab.danmaku => t.videoControls.tabDanmaku,
  };

  @override
  Widget build(BuildContext context) {
    _scheduleInitialFocus();
    final glass = GlassSheetColors.of(context);
    // One fixed panel for every tab, so switching tabs never resizes it.
    return PlayerDrawerStyle(
      child: SizedBox(
        width: PlayerSettingsDrawer.widthFor(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t.videoControls.playbackSettings, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: t.common.close,
                    onPressed: () => OverlaySheetController.of(context).close(),
                    icon: AppIcon(Symbols.close_rounded, size: 20 * FocusTheme.tvPlayerScale(context)),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: glass.foreground.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  for (final tab in PlayerDrawerTab.values) ...[
                    if (tab != PlayerDrawerTab.video) const SizedBox(width: 2),
                    Expanded(
                      child: PlayerDrawerChoice(
                        tab: true,
                        label: _label(tab),
                        selected: tab == _tab,
                        focusNode: _tabFocus[tab.index],
                        onFocusChange: PlatformDetector.isTV()
                            ? (focused) {
                                if (focused) _selectTab(tab);
                              }
                            : null,
                        onNavigateLeft: PlatformDetector.isTV()
                            ? () => _tabFocus[tab.index == 0 ? 0 : tab.index - 1].requestFocus()
                            : null,
                        onNavigateRight: PlatformDetector.isTV()
                            ? () => _tabFocus[tab.index == _tabFocus.length - 1 ? tab.index : tab.index + 1]
                                  .requestFocus()
                            : null,
                        onNavigateDown: PlatformDetector.isTV() ? () => _enterContent(tab) : null,
                        onTap: () {
                          _selectTab(tab);
                          if (PlatformDetector.isTV()) _enterContent(tab);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: PlatformDetector.isTV()
                  ? FocusScope(
                      node: _contentFocus,
                      child: FocusTraversalGroup(
                        policy: _PlayerDrawerTraversalPolicy(onLeaveUp: () => _tabFocus[_tab.index].requestFocus()),
                        child: _drawerBody(),
                      ),
                    )
                  : _drawerBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() => switch (_tab) {
    PlayerDrawerTab.video => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _AspectRatioRow(state: widget.state),
        if (!widget.state.isLive) const _AutoSkipRow(),
        PlayerDrawerHeading(t.videoControls.moreButton),
        FocusableListTile(
          leading: const AppIcon(Symbols.play_arrow_rounded, size: 18),
          title: Text(t.settings.playerBackend),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.coreLabel ?? widget.player.playerType, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 4),
              const AppIcon(Symbols.chevron_right_rounded, size: 16),
            ],
          ),
          onTap: widget.onSwitchCore == null
              ? null
              : () {
                  OverlaySheetController.of(context).close();
                  widget.onSwitchCore!();
                },
        ),
        VideoSettingsSheet(
          player: widget.player,
          trackControlsState: widget.state,
          section: VideoSettingsSection.video,
        ),
      ],
    ),
    PlayerDrawerTab.audio => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        PlayerDrawerHeading(t.videoControls.drawerAudioTracks),
        TrackSheet(player: widget.player, trackControlsState: widget.state, only: TrackSheetKind.audio),
        VideoSettingsSheet(
          player: widget.player,
          trackControlsState: widget.state,
          section: VideoSettingsSection.audio,
          audioVolumeControl: widget.volumeController == null
              ? null
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ValueListenableBuilder<double>(
                    valueListenable: widget.volumeController!,
                    builder: (context, volume, _) => PlayerDrawerRange(
                      label: t.companionRemote.remote.volume,
                      valueText: '${volume.round()}%',
                      value: volume,
                      min: 0,
                      max: SettingsService.instance.read(SettingsService.maxVolume).toDouble(),
                      onChanged: widget.volumeController!.preview,
                      onChangeEnd: widget.volumeController!.commit,
                    ),
                  ),
                ),
        ),
      ],
    ),
    PlayerDrawerTab.subtitles => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        PlayerDrawerHeading(t.videoControls.drawerPrimarySubtitle),
        TrackSheet(
          player: widget.player,
          trackControlsState: widget.state,
          only: TrackSheetKind.subtitles,
          showSubtitleActions: false,
        ),
        VideoSettingsSheet(
          player: widget.player,
          trackControlsState: widget.state,
          section: VideoSettingsSection.subtitle,
        ),
        if (!widget.state.burnsSelectedSubtitle) PlayerSubtitleAppearance(player: widget.player),
        SubtitleSourceActions(state: widget.state),
      ],
    ),
    PlayerDrawerTab.danmaku => DanmakuSettingsSheet(metadata: widget.metadata, session: widget.danmakuSession),
  };
}

class _PlayerDrawerTraversalPolicy extends ReadingOrderTraversalPolicy {
  _PlayerDrawerTraversalPolicy({required this.onLeaveUp});

  final VoidCallback onLeaveUp;

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final moved = super.inDirection(currentNode, direction);
    if (!moved && direction == TraversalDirection.up) {
      onLeaveUp();
      return true;
    }
    return moved;
  }
}

/// Fit / fill / stretch as one row of choices. The player only cycles modes,
/// so a pick cycles until the target is current.
class _AspectRatioRow extends StatefulWidget {
  const _AspectRatioRow({required this.state});
  final TrackControlsState state;
  @override
  State<_AspectRatioRow> createState() => _AspectRatioRowState();
}

class _AspectRatioRowState extends State<_AspectRatioRow> {
  late int _selected = widget.state.boxFitMode;
  @override
  void didUpdateWidget(covariant _AspectRatioRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.boxFitMode != widget.state.boxFitMode) _selected = widget.state.boxFitMode;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cycle = state.onCycleBoxFitMode;
    if (cycle == null) return const SizedBox.shrink();
    const modes = [0, 2, 1];
    final labels = [t.fileInfo.flagDefault, t.videoControls.aspectStretch, t.videoControls.aspectCover];
    return _ChoiceRow(
      title: t.videoControls.aspectRatioSection,
      labels: labels,
      selected: modes.indexOf(_selected).clamp(0, labels.length - 1),
      onSelected: (index) {
        final target = modes[index];
        var steps = (target - _selected) % labels.length;
        while (steps-- > 0) {
          cycle();
        }
        setState(() => _selected = target);
      },
    );
  }
}

/// Auto-skip for intro and credits together: on = auto, off = show the button.
class _AutoSkipRow extends StatelessWidget {
  const _AutoSkipRow();

  @override
  Widget build(BuildContext context) {
    return SettingsBuilder(
      prefs: const [SettingsService.skipIntroMode, SettingsService.skipCreditsMode],
      builder: (context) {
        final settings = SettingsService.instance;
        final on =
            settings.read(SettingsService.skipIntroMode) == SkipMarkerMode.auto &&
            settings.read(SettingsService.skipCreditsMode) == SkipMarkerMode.auto;
        Future<void> set(bool value) async {
          final mode = value ? SkipMarkerMode.auto : SkipMarkerMode.button;
          await settings.write(SettingsService.skipIntroMode, mode);
          await settings.write(SettingsService.skipCreditsMode, mode);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlayerDrawerHeading(t.videoControls.autoSkipSection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PlayerDrawerToggle(label: t.videoControls.autoSkipToggle, value: on, onChanged: set),
            ),
          ],
        );
      },
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.title, required this.labels, required this.selected, required this.onSelected});

  final String title;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final glass = GlassSheetColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: glass.muted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < labels.length; i++)
                PlayerDrawerChoice(label: labels[i], selected: i == selected, onTap: () => onSelected(i)),
            ],
          ),
        ],
      ),
    );
  }
}
