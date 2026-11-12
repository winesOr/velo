import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../../utils/app_logger.dart';

typedef WakelockPlatformToggle = Future<void> Function(bool enabled);

/// Serializes fire-and-forget wakelock requests around the latest desired state.
class WakelockController {
  factory WakelockController({
    WakelockPlatformToggle? platformToggle,
    Duration refreshInterval = const Duration(seconds: 5),
    // TODO(VELO-P1-01): Tune the configurable retry delays on physical devices.
    List<Duration> retryDelays = const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 5)],
  }) {
    if (refreshInterval <= Duration.zero) {
      throw ArgumentError.value(refreshInterval, 'refreshInterval', 'Must be positive');
    }
    if (retryDelays.isEmpty || retryDelays.any((delay) => delay <= Duration.zero)) {
      throw ArgumentError.value(retryDelays, 'retryDelays', 'Must contain positive delays');
    }
    return WakelockController._(
      platformToggle: platformToggle ?? _togglePlatformWakelock,
      refreshInterval: refreshInterval,
      retryDelays: List<Duration>.unmodifiable(retryDelays),
    );
  }

  WakelockController._({required this._platformToggle, required this._refreshInterval, required this._retryDelays});

  final WakelockPlatformToggle _platformToggle;
  final Duration _refreshInterval;
  final List<Duration> _retryDelays;
  final Set<Object> _enabledOwners = <Object>{};
  Timer? _refreshTimer;
  Timer? _retryTimer;
  int _retryIndex = 0;
  bool? _lastLoggedFailureTarget;
  bool _refreshQueued = false;

  Future<void> _tail = Future<void>.value();
  bool? _effectiveEnabled;
  bool _desiredEnabled = false;
  bool _unownedEnabled = false;

  /// Requests a wakelock state and completes after this queued reconciliation.
  ///
  /// Platform failures are logged and absorbed so detached UI callers cannot
  /// produce unhandled errors. Failed acquisitions retry with a bounded delay
  /// while an owner still needs the lock; explicit requests can retry sooner.
  Future<void> setEnabled(bool enabled) {
    _unownedEnabled = enabled;
    if (!enabled && _requestedEnabled) return _tail;
    return _enqueueReconciliation(reassert: enabled);
  }

  /// Requests a wakelock state on behalf of one independent playback screen.
  ///
  /// A replaced screen can release its request after its successor has already
  /// acquired one without turning the platform lock off beneath the successor.
  Future<void> setEnabledForOwner(Object owner, bool enabled) {
    if (enabled) {
      _enabledOwners.add(owner);
    } else {
      _enabledOwners.remove(owner);
    }
    if (!enabled && _requestedEnabled) return _tail;
    return _enqueueReconciliation(reassert: enabled);
  }

  bool get _requestedEnabled => _unownedEnabled || _enabledOwners.isNotEmpty;

  Future<void> _enqueueReconciliation({required bool reassert}) {
    _desiredEnabled = _requestedEnabled;
    if (!_desiredEnabled) {
      _cancelRefreshTimer();
      _cancelRetryTimer();
    }
    final operation = _tail.then((_) => _reconcile(refreshEnabled: reassert && _desiredEnabled));
    _tail = operation;
    return operation;
  }

  void _refresh() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    final operation = _tail.then((_) => _reconcile(refreshEnabled: true));
    _tail = operation.whenComplete(() => _refreshQueued = false);
  }

  Future<void> _reconcile({bool refreshEnabled = false}) async {
    // The platform can lose its flag independently of our cached state.
    // Reassert only while playback still wants the lock, on the same queue.
    if (refreshEnabled && _desiredEnabled && _effectiveEnabled == true) {
      _effectiveEnabled = null;
    }
    while (_effectiveEnabled != _desiredEnabled) {
      final target = _desiredEnabled;
      try {
        await _platformToggle(target);
        _effectiveEnabled = target;
        _lastLoggedFailureTarget = null;
      } catch (error, stackTrace) {
        // A platform call can apply its side effect before returning an error.
        // An opposing request must therefore reconcile even if the old cache
        // happened to match it.
        _effectiveEnabled = null;
        if (_lastLoggedFailureTarget != target) {
          appLogger.w('Wakelock ${target ? 'enable' : 'disable'} failed', error: error, stackTrace: stackTrace);
          _lastLoggedFailureTarget = target;
        }

        // Do not spin on a persistent failure. If an opposing request arrived
        // during the await, it still gets one attempt before this operation
        // settles. Acquisitions then retry without overlapping platform work.
        if (_desiredEnabled == target) {
          if (target) _scheduleRetry();
          return;
        }
      }
    }
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _cancelRetryTimer();
    if (!_desiredEnabled || _effectiveEnabled != true || _refreshTimer != null) return;
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refresh());
  }

  void _scheduleRetry() {
    _cancelRefreshTimer();
    if (!_desiredEnabled || _retryTimer != null) return;
    final delay = _retryDelays[_retryIndex];
    if (_retryIndex < _retryDelays.length - 1) _retryIndex++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_desiredEnabled) _refresh();
    });
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryIndex = 0;
  }

  void _cancelRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}

Future<void> _togglePlatformWakelock(bool enabled) => WakelockPlus.toggle(enable: enabled);
