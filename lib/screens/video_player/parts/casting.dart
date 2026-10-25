part of '../../video_player_screen.dart';

extension _VideoPlayerCastingMethods on VideoPlayerScreenState {
  void _showCastSheet() {
    final unavailable = !Platform.isAndroid
        ? t.videoControls.castUnavailable
        : widget.isLive
        ? t.casting.liveUnavailable
        : _isOfflinePlayback
        ? t.casting.offlineUnavailable
        : (_watchTogetherProvider?.isInSession ?? false)
        ? t.casting.roomUnavailable
        : null;
    var sending = false;
    _chromeController.cancelAutoHide();
    final sheet = OverlaySheetController.of(_sheetContext);
    unawaited(
      sheet
          .show<void>(
            style: OverlaySheetStyle.glass,
            alignment: Alignment.centerRight,
            constraints: BoxConstraints(maxWidth: 360, maxHeight: MediaQuery.sizeOf(context).height - 24),
            canDismiss: () => !sending,
            builder: (_) => DlnaCastSheet(
              unavailableReason: unavailable,
              onClose: sheet.close,
              discover: () => DlnaDiscovery(
                acquireMulticast: () => deviceChannel.invokeMethod<void>('acquireDlnaMulticast'),
                releaseMulticast: () => deviceChannel.invokeMethod<void>('releaseDlnaMulticast'),
              ).scan(),
              onSend: (device) async {
                if (sending) throw const DlnaException(DlnaFailure.unavailable);
                sending = true;
                try {
                  final result = await _sendToDlna(device);
                  if (mounted) {
                    sheet.close();
                    showSnackBar(
                      context,
                      result.resumeAccepted
                          ? t.casting.success(device: device.name)
                          : t.casting.successWithoutResume(device: device.name),
                    );
                    await _exitPlayerRoute(navigateHome: false);
                  }
                  return result;
                } finally {
                  sending = false;
                }
              },
            ),
          )
          .whenComplete(() {
            if (mounted) _chromeController.startAutoHide();
          }),
    );
  }

  Future<DlnaHandoffResult> _sendToDlna(DlnaDevice device) async {
    final currentPlayer = player;
    final session = _playbackSession;
    final client = session?.reportingClient;
    if (currentPlayer == null ||
        client == null ||
        widget.isLive ||
        _isOfflinePlayback ||
        (_watchTogetherProvider?.isInSession ?? false)) {
      throw const DlnaException(DlnaFailure.unsupportedSource);
    }
    final lease = _transitionGate.tryAcquire(PlaybackTransition.casting);
    if (lease == null) throw const DlnaException(DlnaFailure.unavailable);
    final position = currentPlayer.state.position;
    final wasPlaying = currentPlayer.state.playing;
    final sender = DlnaSender();
    bool current() => mounted && identical(player, currentPlayer) && _transitionGate.owns(lease);
    try {
      return await const CastHandoff().run(
        wasPlaying: wasPlaying,
        pause: currentPlayer.pause,
        resume: () async {
          if (current()) await currentPlayer.play();
        },
        resolve: () async {
          final media = await const CastMediaResolver()
              .resolve(
                client: client,
                item: session!.metadata,
                position: position,
                mediaIndex: session.mediaIndex,
                mediaSourceId: session.mediaSourceId,
              )
              .timeout(const Duration(seconds: 20));
          if (!current()) throw const DlnaException(DlnaFailure.unavailable);
          return media;
        },
        send: (media) => sender.send(device, media),
      );
    } finally {
      sender.close();
      _transitionGate.release(lease);
    }
  }
}
