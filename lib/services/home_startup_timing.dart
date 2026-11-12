import '../utils/app_logger.dart';

/// One measurement per Dart process launch, ending after the first frame
/// that can display home content. Device/profile runs can compare five
/// samples without confusing gate time with process-start time.
abstract final class HomeStartupTiming {
  static Stopwatch? _clock;
  static bool _reported = false;

  static void start() {
    _clock = Stopwatch()..start();
    _reported = false;
  }

  static void markContentVisible({required bool fromSnapshot}) {
    if (_reported || _clock == null) return;
    _reported = true;
    _clock!.stop();
    appLogger.i(
      'Startup home content visible',
      error: {'elapsedMs': _clock!.elapsedMilliseconds, 'source': fromSnapshot ? 'authorized-cache' : 'network'},
    );
  }
}
