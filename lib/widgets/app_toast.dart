import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../i18n/strings.g.dart';
import '../services/device_performance.dart';
import '../utils/platform_detector.dart';
import 'app_icon.dart';

/// Notification severity is independent of the legacy snackbar helper API.
enum AppToastType { info, success, error, loading }

/// An owner token: a completed/stale operation cannot replace a newer notice.
class AppToastHandle {
  AppToastHandle._(this._id);
  final Object _id;
  Timer? _pending;
  bool _cancelled = false;

  void update(
    String message, {
    AppToastType type = AppToastType.success,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (_cancelled || AppToast._owner != _id) return;
    _pending?.cancel();
    AppToast._present(_id, message, type: type, duration: duration, actionLabel: actionLabel, onAction: onAction);
  }

  void dismiss() {
    _cancelled = true;
    _pending?.cancel();
    if (AppToast._owner == _id) AppToast.dismiss();
  }
}

/// Root overlay host: notices survive route changes without a modal barrier.
class AppToastHost extends StatefulWidget {
  const AppToastHost({super.key, required this.child});
  final Widget child;
  @override
  State<AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends State<AppToastHost> {
  final _overlayKey = GlobalKey<OverlayState>();
  late final _content = OverlayEntry(builder: (_) => widget.child);
  @override
  void initState() {
    super.initState();
    AppToast._host = this;
  }

  @override
  void didUpdateWidget(AppToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _content.markNeedsBuild();
  }

  @override
  void dispose() {
    if (AppToast._host == this) {
      AppToast.dismiss(immediately: true);
      AppToast._host = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(key: _overlayKey, initialEntries: [_content]);
}

/// Registers real toolbar geometry; invisible tabs and covered routes are ignored.
class AppToastAnchor extends StatefulWidget {
  const AppToastAnchor({super.key, required this.child, this.bottomInset = 0});
  final Widget child;
  final double bottomInset;
  @override
  State<AppToastAnchor> createState() => _AppToastAnchorState();
}

class _AppToastAnchorState extends State<AppToastAnchor> {
  @override
  void initState() {
    super.initState();
    AppToast._anchors.add(this);
  }

  @override
  void dispose() {
    AppToast._anchors.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Actual player chrome state, including the period when its header is unmounted.
class AppToastPlayerRegion extends StatefulWidget {
  const AppToastPlayerRegion({super.key, required this.controlsVisible, required this.child, this.canHandleMenu});
  final bool controlsVisible;
  final bool Function()? canHandleMenu;
  final Widget child;
  @override
  State<AppToastPlayerRegion> createState() => _AppToastPlayerRegionState();
}

class _AppToastPlayerRegionState extends State<AppToastPlayerRegion> {
  @override
  void initState() {
    super.initState();
    AppToast._players.add(this);
  }

  @override
  void dispose() {
    AppToast._players.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ToastNotice {
  const _ToastNotice(this.message, this.type, this.duration, this.dismissible, this.actionLabel, this.onAction);
  final String message;
  final AppToastType type;
  final Duration? duration;
  final bool dismissible;
  final String? actionLabel;
  final VoidCallback? onAction;
  bool get hasAction => actionLabel != null && onAction != null;
}

/// One global slot. Existing snackbar entry points delegate here unchanged.
class AppToast extends StatefulWidget {
  const AppToast._(this._initial, {required super.key});
  final _ToastNotice _initial;
  static _AppToastHostState? _host;
  static OverlayEntry? _entry;
  static OverlayState? _overlay;
  static GlobalKey<_AppToastState>? _key;
  static Object? _owner;
  static WeakReference<BuildContext>? _source;
  static _ToastNotice? _next;
  static int _queuedCount = 1;
  static final _anchors = <_AppToastAnchorState>{};
  static final _players = <_AppToastPlayerRegionState>{};

  static AppToastHandle show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    Duration? duration,
    bool dismissible = true,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final id = Object();
    if (!context.mounted) return AppToastHandle._(id).._cancelled = true;
    final overlay = _host?._overlayKey.currentState ?? Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return AppToastHandle._(id).._cancelled = true;
    if (_overlay != null && _overlay != overlay) dismiss(immediately: true);
    _overlay = overlay;
    _owner = id;
    _source = WeakReference(context);
    _present(
      id,
      message,
      type: type,
      duration: duration,
      dismissible: dismissible,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    return AppToastHandle._(id);
  }

  /// Delayed busy notice; complete using the returned handle, with no fake work.
  static AppToastHandle pending(BuildContext context, {String? message}) {
    final id = Object();
    final handle = AppToastHandle._(id);
    if (!context.mounted) return handle.._cancelled = true;
    final overlay = _host?._overlayKey.currentState ?? Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return handle.._cancelled = true;
    if (_overlay != null && _overlay != overlay) dismiss(immediately: true);
    // Retire an unrelated slot before reserving the delayed operation. Its old
    // expiry must not clear this operation's overlay during the 300 ms wait.
    dismiss(immediately: true);
    _overlay = overlay;
    _owner = id;
    _source = WeakReference(context);
    handle._pending = Timer(const Duration(milliseconds: 300), () {
      if (!handle._cancelled && _owner == id && overlay.mounted) {
        _present(id, message ?? t.common.loading, type: AppToastType.loading);
      }
    });
    return handle;
  }

  static void _present(
    Object id,
    String message, {
    required AppToastType type,
    Duration? duration,
    bool dismissible = true,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = _overlay;
    if (_owner != id || overlay == null || !overlay.mounted) return;
    final notice = _ToastNotice(message, type, duration, dismissible, actionLabel, onAction);
    if (_entry != null) {
      final state = _key?.currentState;
      if (state == null) {
        _queuedCount = _next?.message == message && _next?.type == type ? _queuedCount + 1 : 1;
      }
      _next = notice;
      state?._replace(notice);
      return;
    }
    _queuedCount = 1;
    _next = notice;
    final key = GlobalKey<_AppToastState>();
    _key = key;
    _entry = OverlayEntry(builder: (_) => AppToast._(_next ?? notice, key: key));
    overlay.insert(_entry!);
  }

  static void dismiss({bool immediately = false}) {
    _owner = null;
    final state = _key?.currentState;
    if (!immediately && state != null) {
      state._dismiss();
      return;
    }
    _remove();
  }

  static void _remove() {
    final entry = _entry;
    _entry = null;
    _key = null;
    _next = null;
    _overlay = null;
    _source = null;
    entry?.remove();
    entry?.dispose();
  }

  /// Also consulted by the player's hardware handler, which runs outside Focus.
  /// Repeated dispatch of the same key cannot execute an action twice.
  static bool handleMenuKey(KeyEvent event) => _key?.currentState?._handleMenuKey(event) ?? false;

  static bool _active(BuildContext context) {
    if (!context.mounted || !TickerMode.valuesOf(context).enabled) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  @override
  State<AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<AppToast> with TickerProviderStateMixin {
  late _ToastNotice _notice;
  late final AnimationController _entrance;
  late final AnimationController _swap;
  late final AnimationController _pulse;
  late final AnimationController _remaining;
  late final AnimationController _spinner;
  final _focusNode = FocusNode(skipTraversal: true);
  final _pauses = <String>{};
  int _count = 1;
  bool _actionUsed = false;
  bool _closing = false;
  bool _menuHeld = false;
  bool _reducedMotion = false;
  bool _animationsDisabled = false;
  bool _tv = false;
  bool _player = false;
  bool _initialized = false;
  double? _top;
  double _drag = 0;
  _AppToastPlayerRegionState? _playerRegion;

  @override
  void initState() {
    super.initState();
    _notice = widget._initial;
    _count = AppToast._queuedCount;
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _swap = AnimationController(vsync: this, value: 1, duration: const Duration(milliseconds: 120));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _remaining = AnimationController(vsync: this, animationBehavior: AnimationBehavior.preserve)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _dismiss();
      });
    _spinner = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    FocusManager.instance.addEarlyKeyEventHandler(_earlyKey);
    WidgetsBinding.instance.addPostFrameCallback(_trackPlacement);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tv = PlatformDetector.isTV();
    // Accessible navigation is a reduced-motion preference. Fully disabled
    // platform animations remain zero-duration, a distinct stronger setting.
    _reducedMotion = MediaQuery.accessibleNavigationOf(context) || DevicePerformance.isReduced;
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (!_initialized) {
      _initialized = true;
      _entrance.duration = _duration(220, 150);
      _entrance.forward();
      _restartClock();
      _announce();
    }
  }

  Duration _duration(int full, int reduced) => Duration(
    milliseconds: _animationsDisabled
        ? 0
        : _reducedMotion
        ? reduced
        : full,
  );

  Duration? _lifetime() {
    if (_notice.type == AppToastType.loading) return null;
    final base =
        _notice.duration ??
        Duration(
          milliseconds: _notice.hasAction
              ? 5000
              : _notice.type == AppToastType.error
              ? 4000
              : 2500,
        );
    return base + (_tv ? const Duration(seconds: 1) : Duration.zero);
  }

  void _restartClock() {
    _remaining.stop();
    final duration = _lifetime();
    _remaining.value = 0;
    if (duration != null) {
      _remaining.duration = duration;
      if (_pauses.isEmpty) _remaining.forward();
    }
    _spinner.stop();
    if (_notice.type == AppToastType.loading && !_animationsDisabled && !_reducedMotion) _spinner.repeat();
  }

  void _pause(String reason, bool pause) {
    if (pause) {
      _pauses.add(reason);
      _remaining.stop();
    } else {
      _pauses.remove(reason);
      if (_pauses.isEmpty && _lifetime() != null && !_closing) _remaining.forward();
    }
  }

  void _replace(_ToastNotice next) {
    if (!mounted) return;
    final same = next.message == _notice.message && next.type == _notice.type;
    _remaining.stop();
    _swap.stop();
    _closing = false;
    _entrance.forward();
    if (same) {
      _swap.forward();
      setState(() {
        _notice = next;
        _count++;
        _actionUsed = false;
      });
      if (!_reducedMotion && !_animationsDisabled) _pulse.forward(from: 0);
      _restartClock();
      _announce();
    } else {
      _swap.duration = _duration(120, 120);
      _swap.reverse().then((_) {
        if (!mounted || AppToast._next != next) return;
        setState(() {
          _notice = next;
          _count = 1;
          _actionUsed = false;
        });
        _swap.forward();
        _restartClock();
        _announce();
      });
    }
  }

  void _announce() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The live region handles ordinary status; assertiveness is explicit for errors.
      if (_notice.type == AppToastType.error) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          _semanticLabel,
          Directionality.of(context),
          assertiveness: Assertiveness.assertive,
        );
      }
    });
  }

  String get _semanticLabel =>
      _count > 1 ? '${_notice.message}, ${t.common.toastRepeated(count: _count)}' : _notice.message;
  void _dismiss() {
    if (_closing || !mounted) return;
    _closing = true;
    _remaining.stop();
    _spinner.stop();
    _entrance.duration = _duration(180, 120);
    _entrance.reverse().then((_) {
      if (mounted && _closing) AppToast._remove();
    });
  }

  bool _getInputBlocked() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null) {
      if (focused.findAncestorStateOfType<EditableTextState>() != null) return true;
      if (ModalRoute.of(focused) is PopupRoute) return true;
    }
    return _playerRegion?.widget.canHandleMenu?.call() == false;
  }

  bool _handleMenuKey(KeyEvent event) {
    if (!_tv || event.logicalKey != LogicalKeyboardKey.contextMenu || _getInputBlocked()) return false;
    if (_menuHeld) {
      if (event is KeyUpEvent) _menuHeld = false;
      return true;
    }
    if (!_notice.hasAction || _actionUsed || _closing || event is! KeyDownEvent) return false;
    _menuHeld = true;
    _act();
    return true;
  }

  KeyEventResult _earlyKey(KeyEvent event) {
    if (_handleMenuKey(event)) return KeyEventResult.handled;
    if (_focusNode.hasFocus && _notice.dismissible && event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) _dismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _act() {
    if (_actionUsed || !_notice.hasAction) return;
    setState(() => _actionUsed = true);
    _notice.onAction?.call();
  }

  void _trackPlacement(Duration _) {
    if (!mounted) return;
    final overlayBox = context.findAncestorStateOfType<OverlayState>()?.context.findRenderObject();
    final size = MediaQuery.sizeOf(context);
    var player = false;
    _AppToastPlayerRegionState? region;
    for (final candidate in AppToast._players) {
      if (AppToast._active(candidate.context)) {
        player = true;
        region = candidate;
      }
    }
    double? bottom;
    for (final anchor in AppToast._anchors) {
      if (!AppToast._active(anchor.context)) continue;
      final anchorPlayer = anchor.context.findAncestorStateOfType<_AppToastPlayerRegionState>();
      if (player != (anchorPlayer != null)) continue;
      if (anchorPlayer != null && !anchorPlayer.widget.controlsVisible) continue;
      final render = anchor.context.findRenderObject();
      if (render is! RenderBox || !render.hasSize || !render.attached || overlayBox is! RenderBox) continue;
      final rect = MatrixUtils.transformRect(render.getTransformTo(overlayBox), Offset.zero & render.size);
      if (rect.bottom <= 0 || rect.top >= size.height) continue;
      bottom = math.max(bottom ?? 0, rect.bottom + anchor.widget.bottomInset);
    }
    if (!player && bottom == null) {
      final source = AppToast._source?.target;
      if (source != null && AppToast._active(source)) {
        final scaffold = Scaffold.maybeOf(source)?.widget;
        final appBar = scaffold?.appBar;
        if (appBar != null) {
          bottom = appBar.preferredSize.height + (scaffold!.primary ? MediaQuery.paddingOf(context).top : 0);
        }
      }
    }
    final scale = _tv ? size.width / 1920 : 1.0;
    final top = player
        ? (region?.widget.controlsVisible == true && bottom != null ? bottom + 8 : 14.0)
        : bottom != null
        ? bottom + (_tv ? 16 * scale : 8)
        : _tv
        ? 54 * scale
        : MediaQuery.paddingOf(context).top + 8;
    if (_top != top || _player != player) {
      setState(() {
        _top = top;
        _player = player;
      });
    }
    _playerRegion = region;
    // Observe layout/route/HUD frames without requesting idle frames or a timer.
    WidgetsBinding.instance.addPostFrameCallback(_trackPlacement);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_earlyKey);
    _focusNode.dispose();
    _entrance.dispose();
    _swap.dispose();
    _pulse.dispose();
    _remaining.dispose();
    _spinner.dispose();
    // Navigator-owned test/fallback overlays may disappear independently.
    if (AppToast._key == widget.key) {
      AppToast._entry = null;
      AppToast._key = null;
      AppToast._overlay = null;
      AppToast._owner = null;
      AppToast._source = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final s = _tv ? size.width / 1920 : 1.0;
    final dark = _player || Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xfff3f3ef) : const Color(0xff242424);
    final (icon, accent) = switch (_notice.type) {
      AppToastType.success => (Symbols.check_circle_rounded, dark ? const Color(0xff86d8ae) : const Color(0xff1f7a50)),
      AppToastType.error => (Symbols.error_rounded, dark ? const Color(0xffff8f86) : const Color(0xffc23a31)),
      AppToastType.info => (Symbols.info_rounded, dark ? const Color(0xffb4aaff) : const Color(0xff6256c8)),
      AppToastType.loading => (Symbols.progress_activity, dark ? const Color(0xffc9c9c4) : const Color(0xff686864)),
    };
    final reduced = DevicePerformance.isReduced || MediaQuery.highContrastOf(context) || _animationsDisabled;
    final radius = _tv ? 40 * s : 22.0;
    final inset = _tv
        ? 96 * s
        : _player
        ? math.max(44.0, math.max(MediaQuery.paddingOf(context).left, MediaQuery.paddingOf(context).right))
        : 16.0;
    final maxWidth = math.max(
      0.0,
      math.min(
        size.width - inset * 2,
        _tv
            ? 720 * s
            : _player && size.width > size.height
            ? 460.0
            : size.width,
      ),
    );
    final surface = _player
        ? const Color(0xff1c1c1e).withValues(alpha: .62)
        : dark
        ? const Color(0xff222224).withValues(alpha: .66)
        : const Color(0xfffdfcf9).withValues(alpha: .72);
    final iconSize = _tv ? 34 * s : 18.0;
    Widget statusIcon = AppIcon(icon, size: iconSize, color: accent);
    if (_notice.type == AppToastType.loading) statusIcon = RotationTransition(turns: _spinner, child: statusIcon);
    Widget body = Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(_tv ? 26 * s : 14, _tv ? 20 * s : 11, _tv ? 34 * s : 18, _tv ? 20 * s : 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              statusIcon,
              SizedBox(width: _tv ? 18 * s : 10),
              Flexible(
                child: Text(
                  _notice.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: _tv ? 28 * s : 14,
                    height: _tv ? 38 / 28 : 20 / 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_count > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '×$_count',
                    style: TextStyle(color: foreground, fontSize: _tv ? 22 * s : 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              if (_notice.hasAction) ...[
                SizedBox(width: _tv ? 18 * s : 8),
                if (_tv)
                  Text(
                    '${t.common.toastMenu} ${_notice.actionLabel}',
                    style: TextStyle(color: dark ? const Color(0xffd6d0ff) : const Color(0xff5348b8), fontSize: 24 * s),
                  )
                else
                  TextButton(
                    onPressed: _actionUsed ? null : _act,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: dark ? const Color(0x14ffffff) : const Color(0x125348b8),
                      foregroundColor: dark ? const Color(0xffd6d0ff) : const Color(0xff5348b8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_notice.actionLabel!, maxLines: 1),
                  ),
              ],
            ],
          ),
        ),
        if (_notice.hasAction || _notice.type == AppToastType.error)
          Positioned(
            left: _tv ? 34 * s : 18,
            right: _tv ? 34 * s : 18,
            bottom: _tv ? 6 * s : 3,
            child: AnimatedBuilder(
              animation: _remaining,
              builder: (_, _) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: 1 - _remaining.value,
                  child: Container(height: _tv ? 3 * s : 2, color: accent.withValues(alpha: .55)),
                ),
              ),
            ),
          ),
      ],
    );
    body = Material(
      color: reduced ? surface.withValues(alpha: 1) : surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(width: .5, color: dark ? const Color(0x1fffffff) : const Color(0x1c242424)),
      ),
      child: body,
    );
    if (!reduced) body = BackdropFilter(filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26), child: body);
    body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x66000000) : const Color(0x241a1820),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: body),
    );
    body = Semantics(
      container: true,
      liveRegion: true,
      label: _semanticLabel,
      onDismiss: _notice.dismissible ? _dismiss : null,
      child: ExcludeSemantics(
        excluding: !_notice.hasAction,
        child: Focus(
          focusNode: _focusNode,
          canRequestFocus: !_tv,
          skipTraversal: true,
          descendantsAreFocusable: !_tv,
          descendantsAreTraversable: !_tv,
          onFocusChange: (value) => _pause('focus', value),
          child: MouseRegion(
            onEnter: (_) => _pause('hover', true),
            onExit: (_) => _pause('hover', false),
            child: Listener(
              onPointerDown: (_) => _pause('press', true),
              onPointerUp: (_) => _pause('press', false),
              onPointerCancel: (_) => _pause('press', false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _notice.dismissible ? _dismiss : null,
                onVerticalDragStart: _notice.dismissible ? (_) => _drag = 0 : null,
                onVerticalDragUpdate: _notice.dismissible ? (details) => _drag += details.delta.dy : null,
                onVerticalDragEnd: _notice.dismissible
                    ? (_) {
                        if (_drag <= -18) _dismiss();
                      }
                    : null,
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
    return Positioned(
      top: _top ?? MediaQuery.paddingOf(context).top + 8,
      right: _tv ? inset : null,
      left: _tv ? null : 0,
      width: _tv ? maxWidth : size.width,
      child: Align(
        alignment: _tv ? Alignment.topRight : Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, minHeight: _tv ? 80 * s : 44),
          child: AnimatedBuilder(
            animation: Listenable.merge([_entrance, _swap, _pulse]),
            builder: (_, child) {
              final t = const Cubic(.2, .8, .2, 1).transform(_entrance.value);
              final pulse = math.sin(_pulse.value * math.pi) * .04;
              return Opacity(
                opacity: (t * _swap.value).clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, _reducedMotion || _animationsDisabled ? 0 : (_closing ? -8 : -10) * (1 - t)),
                  child: Transform.scale(
                    scale: _reducedMotion || _animationsDisabled
                        ? 1
                        : (_closing ? .96 : .94) + (_closing ? .04 : .06) * t + pulse,
                    child: child,
                  ),
                ),
              );
            },
            child: body,
          ),
        ),
      ),
    );
  }
}
