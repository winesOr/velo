import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../focus/focus_theme.dart';
import '../../../mpv/mpv.dart';
import '../../../utils/platform_detector.dart';
import '../../../utils/media_quality_labels.dart';
import '../../media_format_badge.dart';

typedef _PlaybackFormats = ({MediaFormat? video, MediaFormat? audio});

class DolbyPlaybackIndicator extends StatefulWidget {
  const DolbyPlaybackIndicator({super.key, required this.player, this.inline = false});

  final Player player;

  /// True when sitting beside the subtitle on the same row; false when it
  /// gets its own row under the title.
  final bool inline;

  @override
  State<DolbyPlaybackIndicator> createState() => _DolbyPlaybackIndicatorState();
}

class _DolbyPlaybackIndicatorState extends State<DolbyPlaybackIndicator> {
  static const _scrim = Color(0x4D000000);
  static const _inactive = (video: null, audio: null);
  _PlaybackFormats _status = _inactive;
  late final Timer _poll;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => unawaited(_refresh()));
  }

  @override
  void dispose() {
    _poll.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_reading) return;
    _reading = true;
    _PlaybackFormats next = _inactive;
    try {
      next = await _readOutput(widget.player);
    } catch (_) {
      next = _inactive;
    } finally {
      _reading = false;
    }
    if (mounted && _status != next) setState(() => _status = next);
  }

  Future<_PlaybackFormats> _readOutput(Player player) async {
    if (player.providesNativeStats) {
      final stats = await player.getStats();
      return (
        video: switch (stats) {
          {'dolbyVisionActive': true} => MediaFormat.dolbyVision,
          {'hdrActive': true} => MediaFormat.hdr,
          _ => null,
        },
        audio: _dolbyAudio(stats['audioOutputEncodingName'] ?? stats['audio-out-params/format']),
      );
    }

    final mode = await player.getAudioRenderingMode();
    if (mode != null && mode.isConclusive) {
      return (
        video: null,
        audio: mode.isDolbyAtmos ? MediaFormat.dolbyAtmos : (mode.isDolbyAudio ? MediaFormat.dolbyAudio : null),
      );
    }
    if (Platform.isIOS) return _inactive;
    return (video: null, audio: _dolbyAudio(await player.getProperty('audio-out-params/format')));
  }

  MediaFormat? _dolbyAudio(Object? encoding) => switch (encoding) {
    'eac3-joc' => MediaFormat.dolbyAtmos,
    'ac3' || 'eac3' || 'truehd' || 'spdif-ac3' || 'spdif-eac3' || 'spdif-truehd' => MediaFormat.dolbyAudio,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: _status == _inactive
          ? const SizedBox.shrink(key: ValueKey('dolby-indicator-idle'))
          : _buildBadges(context, FocusTheme.tvPlayerScale(context)),
    );
  }

  Widget _buildBadges(BuildContext context, double scale) {
    final size = PlatformDetector.isTV() ? MediaFormatBadgeSize.large : MediaFormatBadgeSize.small;
    final formats = [?_status.video, ?_status.audio];
    final badges = Wrap(
      key: ValueKey(_status),
      spacing: 6 * scale,
      runSpacing: 4 * scale,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final format in formats)
          // Dark scrim keeps the white wordmark legible over bright video.
          DecoratedBox(
            decoration: BoxDecoration(color: _scrim, borderRadius: BorderRadius.circular(size.radius * scale)),
            child: MediaFormatBadge(format, size: size, scale: scale, color: Colors.white),
          ),
      ],
    );
    return Padding(
      padding: widget.inline ? EdgeInsetsDirectional.only(start: 8 * scale) : EdgeInsets.only(top: 4 * scale),
      child: badges,
    );
  }
}
