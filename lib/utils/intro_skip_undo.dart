import '../media/media_source_info.dart';

/// One playback session's undo window and intervals the viewer chose to watch.
class IntroSkipUndo {
  final DateTime Function() _now;
  IntroSkipUndo({DateTime Function()? now}) : _now = now ?? DateTime.now;
  static const window = Duration(seconds: 5);
  final Set<(int, int)> _suppressed = {};
  ({MediaMarker marker, Duration position, DateTime expires})? _pending;

  MediaMarker? get marker => available ? _pending!.marker : null;
  bool get available => _pending != null && _now().isBefore(_pending!.expires);
  bool suppresses(MediaMarker marker) => _suppressed.contains((marker.startTimeOffset, marker.endTimeOffset));

  void cancelSuppression(MediaMarker marker) => _suppressed.remove((marker.startTimeOffset, marker.endTimeOffset));

  void offer(MediaMarker marker, Duration position) {
    if (marker.type != 'intro') return;
    _pending = (marker: marker, position: position, expires: _now().add(window));
  }

  Duration? take() {
    if (!available) {
      dismiss();
      return null;
    }
    final pending = _pending!;
    _suppressed.add((pending.marker.startTimeOffset, pending.marker.endTimeOffset));
    dismiss();
    return pending.position;
  }

  void dismiss() => _pending = null;
  void reset() {
    dismiss();
    _suppressed.clear();
  }
}
