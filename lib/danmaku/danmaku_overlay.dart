import 'dart:async';
import 'dart:math' as math;

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../mpv/player/player.dart';
import 'danmaku_comment.dart';
import 'danmaku_session.dart';

/// Draws loaded comments over the video, driven only by the player clock.
class DanmakuOverlay extends StatefulWidget {
  final Player player;
  final DanmakuSession? session;

  const DanmakuOverlay({super.key, required this.player, this.session});

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay> with SingleTickerProviderStateMixin {
  // Interpolate coarse native position updates only while playback is active.
  // A stalled position stream must not let comments run arbitrarily ahead.
  static const _maxExtrapolation = Duration(seconds: 1);
  late final Ticker _ticker;
  Duration _frameElapsed = Duration.zero;
  Duration _anchorElapsed = Duration.zero;
  Duration _anchorPosition = Duration.zero;
  Duration _lastDispatch = Duration.zero;
  double _rate = 1;
  bool _buffering = false;

  DanmakuController? _controller;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<double>? _rateSub;
  StreamSubscription<Duration?>? _jumpSub;
  List<DanmakuComment> _comments = const [];
  int _cursor = 0;
  Duration _lastPosition = Duration.zero;
  bool _running = true;
  Object? _layoutSignature;
  DanmakuSession get _session => widget.session ?? DanmakuSession.instance;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    _session.addListener(_onSession);
    _bindPlayer();
    _onSession();
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      (oldWidget.session ?? DanmakuSession.instance).removeListener(_onSession);
      _session.addListener(_onSession);
      _onSession();
    }
    if (oldWidget.player == widget.player) return;
    _unbindPlayer();
    _bindPlayer();
    _resetCursor();
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _unbindPlayer();
    _ticker.dispose();
    super.dispose();
  }

  void _unbindPlayer() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _rateSub?.cancel();
    _jumpSub?.cancel();
  }

  void _bindPlayer() {
    final state = widget.player.state;
    _running = state.playing;
    _buffering = state.buffering;
    _rate = state.rate.isFinite && state.rate > 0 ? state.rate : 1;
    _lastPosition = _anchorPosition = _lastDispatch = widget.player.currentPosition;
    _anchorElapsed = _frameElapsed;
    _positionSub = widget.player.streams.position.listen(_onPosition);
    _playingSub = widget.player.streams.playing.listen(_onPlaying);
    _bufferingSub = widget.player.streams.buffering.listen((buffering) {
      _reanchor();
      _buffering = buffering;
      _syncRunning();
    });
    _rateSub = widget.player.streams.rate.listen((rate) {
      if (!rate.isFinite || rate <= 0) return;
      _reanchor();
      _rate = rate;
    });
    _jumpSub = widget.player.streams.playheadJump.listen((target) => _resetCursor(position: target));
    _syncRunning();
  }

  Duration get _clockPosition {
    if (!_ticker.isActive) return _anchorPosition;
    final elapsed = _frameElapsed - _anchorElapsed;
    final bounded = elapsed > _maxExtrapolation ? _maxExtrapolation : elapsed;
    return _anchorPosition + Duration(microseconds: (bounded.inMicroseconds * _rate).round());
  }

  void _reanchor() {
    _anchorPosition = _clockPosition;
    _anchorElapsed = _frameElapsed;
  }

  void _syncRunning() {
    final animate = _running && !_buffering && _session.enabled && _comments.isNotEmpty;
    if (animate) {
      _controller?.resume();
    } else {
      _controller?.pause();
    }
    if (animate && _cursor < _comments.length) {
      if (!_ticker.isActive) {
        _frameElapsed = _anchorElapsed = Duration.zero;
        _ticker.start();
      }
    } else {
      _reanchor();
      _ticker.stop();
    }
  }

  void _onFrame(Duration elapsed) {
    _frameElapsed = elapsed;
    if (_running && !_buffering) _dispatch(_clockPosition);
  }

  void _onSession() {
    final session = _session;
    final style = session.presentation;
    final signature = (
      style.fontSize,
      style.speed,
      style.maxOnScreen,
      style.scrollLines,
      style.topLines,
      style.bottomLines,
      style.preventOverlap,
    );
    if (_layoutSignature != signature) {
      _layoutSignature = signature;
      _controller?.clear();
    }
    _controller?.updateOption(_option);
    if (!session.enabled || session.comments.isEmpty) {
      _comments = const [];
      _syncRunning();
      // canvas_danmaku only invalidates its scrolling painter on clear when
      // its ticker is stopped. Pause first so the last painted frame is erased.
      _controller?.clear();
      return;
    }
    if (!identical(_comments, session.comments)) {
      _comments = session.comments;
      _controller?.clear();
      _resetCursor();
    }
    _syncRunning();
  }

  DanmakuOption get _option {
    final style = _session.presentation;
    return DanmakuOption(
      fontSize: style.fontSize,
      opacity: style.opacity,
      duration: 8 / style.speed,
      massiveMode: !style.preventOverlap,
      hideScroll: style.scrollLines == 0,
      hideTop: style.topLines == 0,
      hideBottom: style.bottomLines == 0,
    );
  }

  void _addComment(
    DanmakuController controller,
    DanmakuComment comment,
    List<DanmakuItem> active,
    Map<DanmakuItemType, int> kindCounts,
  ) {
    final style = _session.presentation;
    final type = _type(comment.mode);
    final limit = switch (type) {
      DanmakuItemType.top => style.topLines,
      DanmakuItemType.bottom => style.bottomLines,
      _ => style.scrollLines,
    };
    // Scrolling rows are lanes, not concurrent-item caps. A lane can admit
    // another comment as soon as the previous tail has cleared its entry.
    if (limit == 0 ||
        active.length >= style.maxOnScreen ||
        (type != DanmakuItemType.scroll && (kindCounts[type] ?? 0) >= limit)) {
      return;
    }
    final target = type == DanmakuItemType.scroll ? controller.scrollDanmaku : controller.staticDanmaku;
    final before = target.length;
    controller.addDanmaku(DanmakuContentItem(comment.text, color: _color(comment.color), type: type));
    if (target.length == before) return;
    final added = target.last;
    final step = math.max(style.fontSize * 1.6, added.height + 4);
    final height = controller.viewHeight;
    final availableRows = math.max(0, (height / step).floor() - 1);
    final rows = type == DanmakuItemType.scroll ? math.min(limit, availableRows) : availableRows;
    final gap = math.max(12.0, style.fontSize * .7);
    final width = controller.viewWidth;
    final duration = _option.durationInMilliseconds;
    for (var offset = 0; offset < rows; offset++) {
      final row = style.preventOverlap ? offset : ((kindCounts[type] ?? 0) + offset) % rows;
      final top = type == DanmakuItemType.bottom ? height - (row + 2) * step : row * step;
      final occupied =
          style.preventOverlap &&
          active.any((item) {
            final otherTop = item.content.type == DanmakuItemType.bottom
                ? height - item.yPosition - item.height
                : item.yPosition;
            if (top >= otherTop + item.height + 2 || top + added.height + 2 <= otherTop) return false;
            if (type != DanmakuItemType.scroll || item.content.type != DanmakuItemType.scroll) return true;
            final tail = item.xPosition + item.width;
            final separation = width - tail - gap;
            if (separation < 0) return true;
            final previousSpeed = (width + item.width) / duration;
            final nextSpeed = (width + added.width) / duration;
            // A wider following comment moves faster. Keep enough separation to
            // avoid catching the previous comment before its tail leaves the view.
            return nextSpeed > previousSpeed &&
                separation < (nextSpeed - previousSpeed) * math.max(0, tail / previousSpeed);
          });
      if (!occupied) {
        added.yPosition = type == DanmakuItemType.bottom ? height - top - added.height : top;
        active.add(added);
        kindCounts.update(type, (count) => count + 1, ifAbsent: () => 1);
        return;
      }
    }
    target.removeLast().dispose();
  }

  void _resetCursor({Duration? position}) {
    _lastPosition = _anchorPosition = _lastDispatch = position ?? widget.player.currentPosition;
    _anchorElapsed = _frameElapsed;
    _cursor = _lowerBound(_lastPosition);
    _controller?.clear();
    _syncRunning();
  }

  void _onPlaying(bool playing) {
    _reanchor();
    _running = playing;
    _syncRunning();
  }

  void _onPosition(Duration position) {
    if (position == _lastPosition) {
      if (_running && !_buffering) _dispatch(_anchorPosition);
      return;
    }
    if ((position - _lastPosition).abs() > const Duration(seconds: 2)) {
      _resetCursor(position: position);
    } else {
      _lastPosition = position;
      // Native events can arrive a frame late. Only an explicit jump rewinds
      // the emission cursor; ordinary jitter must not replay or stall comments.
      _anchorPosition = position < _lastDispatch ? _lastDispatch : position;
      _anchorElapsed = _frameElapsed;
    }
    if (_running && !_buffering) _dispatch(_anchorPosition);
  }

  void _dispatch(Duration position) {
    final controller = _controller;
    if (controller == null || !_session.enabled || _comments.isEmpty) return;
    if (position < _lastDispatch) return;
    _lastDispatch = position;
    if (_cursor >= _comments.length || _comments[_cursor].timeMs > position.inMilliseconds) return;
    // Snapshot only when comments are due, not on every animation frame. Rejected dense comments must not each
    // allocate and scan another copy of the entire live engine list.
    final active = <DanmakuItem>[
      for (final item in controller.scrollDanmaku)
        if (!item.expired) item,
      for (final item in controller.staticDanmaku)
        if (!item.expired) item,
    ];
    final kindCounts = <DanmakuItemType, int>{};
    for (final item in active) {
      kindCounts.update(item.content.type, (count) => count + 1, ifAbsent: () => 1);
    }
    while (_cursor < _comments.length && _comments[_cursor].timeMs <= position.inMilliseconds) {
      final comment = _comments[_cursor];
      if (comment.timeMs >= position.inMilliseconds - 500) {
        _addComment(controller, comment, active, kindCounts);
      }
      _cursor++;
    }
    if (_cursor >= _comments.length) _syncRunning();
  }

  int _lowerBound(Duration position) {
    var low = 0;
    var high = _comments.length;
    final target = position.inMilliseconds;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_comments[mid].timeMs < target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  Color _color(int rgb) => Color(0xFF000000 | (rgb & 0xFFFFFF));

  DanmakuItemType _type(int mode) {
    return switch (mode) {
      4 => DanmakuItemType.bottom,
      5 => DanmakuItemType.top,
      _ => DanmakuItemType.scroll,
    };
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => DanmakuScreen(
          // The engine only recalculates available tracks on resize; it does
          // not relocate active items. Recreate it to avoid top/bottom overlap
          // and out-of-bounds lanes after rotation or window resizing.
          key: ValueKey((constraints.maxWidth, constraints.maxHeight)),
          option: _option,
          createdController: (controller) {
            _controller = controller;
            _onPlaying(widget.player.state.playing);
            _onSession();
            _resetCursor();
          },
        ),
      ),
    );
  }
}
