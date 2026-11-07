import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../../utils/app_logger.dart';

typedef WakelockPlatformToggle = Future<void> Function(bool enabled);

/// Serializes fire-and-forget wakelock requests around the latest desired state.
class WakelockController {
  factory WakelockController({
    WakelockPlatformToggle? platformToggle,
    Duration refreshInterval = const Duration(seconds: 5),
  }) =>
      WakelockController._(platformToggle: platformToggle ?? _togglePlatformWakelock, refreshInterval: refreshInterval);

  WakelockController._({required this._platformToggle, required this._refreshInterval});

  final WakelockPlatformToggle _platformToggle;
  final Duration _refreshInterval;
  final Set<Object> _enabledOwners = <Object>{};
  Timer? _refreshTimer;
  bool _refreshQueued = false;

  Future<void> _tail = Future<void>.value();
  bool? _effectiveEnabled;
  bool _desiredEnabled = false;
  bool _unownedEnabled = false;

  /// Requests a wakelock state and completes after this queued reconciliation.
  ///
  /// Platform failures are logged and absorbed so detached UI callers cannot
  /// produce unhandled errors. A failed state is not recorded as effective;
  /// the same value can therefore be retried by a later explicit request.
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
    if (!_desiredEnabled) _cancelRefreshTimer();
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
      } catch (error, stackTrace) {
        appLogger.w('Wakelock ${target ? 'enable' : 'disable'} failed', error: error, stackTrace: stackTrace);

        // Do not spin on a persistent failure. If an opposing request arrived
        // during the await, it still gets one attempt before this operation
        // settles; an identical state retries only through another setEnabled.
        if (_desiredEnabled == target) {
          if (target) _cancelRefreshTimer();
          return;
        }
      }
    }
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    if (!_desiredEnabled || _effectiveEnabled != true || _refreshTimer != null) return;
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refresh());
  }

  void _cancelRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}

Future<void> _togglePlatformWakelock(bool enabled) => WakelockPlus.toggle(enable: enabled);
