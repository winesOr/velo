import 'dlna_http.dart';
import 'dlna_sender.dart';

/// Local rollback is safe only before sending Play, or after an explicit
/// receiver failure. An uncertain result must not start a second audible player.
class CastHandoff {
  const CastHandoff();

  Future<DlnaHandoffResult> run({
    required bool wasPlaying,
    required Future<void> Function() pause,
    required Future<void> Function() resume,
    required Future<DlnaMedia> Function() resolve,
    required Future<DlnaHandoffResult> Function(DlnaMedia) send,
  }) async {
    var paused = false;
    var sending = false;
    try {
      await pause();
      paused = true;
      final media = await resolve();
      sending = true;
      return await send(media);
    } catch (error) {
      final safeToResume = error is DlnaException ? !error.mayBePlaying : !sending;
      if (paused && wasPlaying && safeToResume) await resume();
      rethrow;
    }
  }
}
