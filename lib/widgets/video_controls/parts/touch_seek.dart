part of '../video_controls.dart';

/// Touch swipe-to-seek and the sideways speed slide during a long press.
///
/// Swipe-to-seek shares the pointer stream with the edge brightness/volume
/// tracker: that one only claims vertical movement, this one only horizontal,
/// so whichever axis dominates first wins and the other stays idle. The seek is
/// previewed while dragging and applied once on release, like the timeline.
extension _PlexVideoControlsTouchSeekMethods on _PlexVideoControlsState {
  /// Full-width swipe covers this much of the video, capped by [_swipeSeekMaxSpan].
  static const double _swipeSeekWidthFraction = 1.0;
  static const Duration _swipeSeekMaxSpan = Duration(minutes: 3);
  static const Duration _swipeSeekMinSpan = Duration(seconds: 90);

  /// Horizontal travel per speed step while holding.
  static const double _longPressSlideStep = 48;

  bool get _swipeSeekEnabled =>
      widget.canControl && !widget.isLive && _settings.read(SettingsService.gestureHorizontalSeek);

  void _swipeSeekPointerDown(int pointer, Offset position, Size size) {
    if (_swipeSeekPointer != null || !_swipeSeekEnabled) return;
    final dims = mobileSkipZoneDimensions(size);
    // Leave the timeline/header bands to the controls.
    if (position.dy < dims.topExclude || position.dy > size.height - dims.bottomExclude) return;
    _swipeSeekPointer = pointer;
    _swipeSeekStart = position;
    _swipeSeekActive = false;
  }

  /// Returns true once this pointer has become a seek drag.
  bool _swipeSeekPointerMove(int pointer, Offset position, Size size) {
    if (pointer != _swipeSeekPointer) return false;
    final start = _swipeSeekStart;
    if (start == null) return false;
    final delta = position - start;
    if (!_swipeSeekActive) {
      if (delta.distance < kTouchSlop) return false;
      if (delta.dx.abs() <= delta.dy.abs() * 1.5) {
        _resetSwipeSeek();
        return false;
      }
      final duration = widget.player.state.duration;
      if (duration <= Duration.zero) {
        _resetSwipeSeek();
        return false;
      }
      _swipeSeekActive = true;
      _swipeSeekOrigin = widget.player.state.position;
      _cancelEdgeAdjustmentGesture();
      _suppressTouchTaps();
    }
    final origin = _swipeSeekOrigin!;
    final duration = widget.player.state.duration;
    final spanMs = (duration.inMilliseconds * _swipeSeekWidthFraction).clamp(
      _swipeSeekMinSpan.inMilliseconds.toDouble(),
      _swipeSeekMaxSpan.inMilliseconds.toDouble(),
    );
    final offset = Duration(milliseconds: (delta.dx / size.width * spanMs).round());
    final target = clampSeekPosition(widget.player, origin + offset);
    _swipeSeekTarget = target;
    final travelled = target - origin;
    final sign = travelled.isNegative ? '-' : '+';
    _swipeSeekLabel.value = t.videoControls.seekPreview(
      target: '${formatDurationTimestamp(target)} / ${formatDurationTimestamp(duration)}',
      delta: '$sign${formatDurationTimestamp(travelled.abs())}',
    );
    return true;
  }

  /// Applies the previewed seek. Returns true when the pointer was a seek drag.
  bool _swipeSeekPointerUp(int pointer) {
    if (pointer != _swipeSeekPointer) return false;
    final wasActive = _swipeSeekActive;
    final target = _swipeSeekTarget;
    _resetSwipeSeek();
    if (wasActive && target != null) unawaited(_seekToPosition(target));
    return wasActive;
  }

  void _cancelSwipeSeek() => _resetSwipeSeek();

  void _resetSwipeSeek() {
    _swipeSeekPointer = null;
    _swipeSeekStart = null;
    _swipeSeekOrigin = null;
    _swipeSeekTarget = null;
    _swipeSeekActive = false;
    _swipeSeekLabel.value = null;
  }

  /// While holding, every [_longPressSlideStep] of sideways travel moves one
  /// step through [SettingsService.longPressSpeedOptions]. Not persisted.
  void _updateLongPressSlide(Offset position, Size size) {
    final origin = _longPressSlideOriginX ??= position.dx;
    const options = SettingsService.longPressSpeedOptions;
    final base = _settings.read(SettingsService.longPressSpeed);
    var baseIndex = 0;
    for (var i = 0; i < options.length; i++) {
      if ((options[i] - base).abs() < (options[baseIndex] - base).abs()) baseIndex = i;
    }
    final steps = ((position.dx - origin) / _longPressSlideStep).truncate();
    final rate = options[(baseIndex + steps).clamp(0, options.length - 1)];
    if ((rate - _longPressRate).abs() < 0.001) return;
    _setControlsState(() => _longPressRate = rate);
    unawaited(_requestRate(rate));
  }
}
