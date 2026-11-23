import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../focus/focus_theme.dart';
import '../../../mpv/mpv.dart';
import '../../../utils/media_quality_labels.dart';
import '../../media_format_badge.dart';

typedef _PlaybackFormats = ({MediaFormat? video, MediaFormat? audio});

class DolbyPlaybackIndicator extends StatefulWidget {
  const DolbyPlaybackIndicator({super.key, required this.player});

  final Player player;

  @override
  State<DolbyPlaybackIndicator> createState() => _DolbyPlaybackIndicatorState();
}

class _DolbyPlaybackIndicatorState extends State<DolbyPlaybackIndicator> {
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
    if (_status == _inactive) return const SizedBox.shrink();
    final scale = FocusTheme.tvPlayerScale(context);
    return Padding(
      padding: EdgeInsets.only(top: 4 * scale),
      child: Wrap(
        spacing: 6 * scale,
        runSpacing: 4 * scale,
        children: [
          if (_status.video case final video?) MediaFormatBadge(video, onArtwork: true, scale: scale),
          if (_status.audio case final audio?) MediaFormatBadge(audio, onArtwork: true, scale: scale),
        ],
      ),
    );
  }
}
