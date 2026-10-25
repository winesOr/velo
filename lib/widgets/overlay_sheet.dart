import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../focus/dpad_navigator.dart';
import '../focus/input_mode_tracker.dart';
import '../focus/key_event_utils.dart';
import '../utils/platform_detector.dart';

/// Surface treatment for a hosted sheet.
enum OverlaySheetStyle {
  /// Opaque theme surface, 16 radius. Used everywhere outside the player.
  solid,

  /// Player menus: translucent blurred surface with a hairline edge. Follows
  /// the app brightness; [OverlaySheetController.show] keeps the edge inset.
  glass,
}

/// Colours for [OverlaySheetStyle.glass], derived from the ambient brightness.
@immutable
class GlassSheetColors {
  const GlassSheetColors._(this.surface, this.edge, this.foreground, this.muted, this.selected);

  factory GlassSheetColors.of(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? const GlassSheetColors._(
          Color(0x851A1B20),
          Color(0x24FFFFFF),
          Color(0xFFF2F3F5),
          Color(0x8CF2F3F5),
          Color(0x1FFFFFFF),
        )
      : const GlassSheetColors._(
          Color(0xA6F6F6F8),
          Color(0xB3FFFFFF),
          Color(0xFF1C1C1E),
          Color(0x801C1C1E),
          Color(0x0F000000),
        );

  final Color surface;
  final Color edge;
  final Color foreground;
  final Color muted;
  final Color selected;
}

/// Entry in the sheet page stack.
class _OverlaySheetEntry {
  final WidgetBuilder builder;
  final Completer<dynamic> completer;
  final FocusNode? initialFocusNode;

  _OverlaySheetEntry({required this.builder, required this.completer, this.initialFocusNode});
}

/// Provides [OverlaySheetController] to descendants via [of] / [maybeOf].
class _OverlaySheetScope extends InheritedWidget {
  final OverlaySheetController controller;

  const _OverlaySheetScope({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_OverlaySheetScope oldWidget) => controller != oldWidget.controller;
}

/// Controller for the overlay-based floating panel system.
///
/// Use [of] or [maybeOf] to access from descendants.
class OverlaySheetController {
  final _OverlaySheetHostState _state;

  OverlaySheetController._(this._state);

  static OverlaySheetController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_OverlaySheetScope>();
    assert(scope != null, 'No OverlaySheetHost found in context');
    return scope!.controller;
  }

  static OverlaySheetController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_OverlaySheetScope>()?.controller;
  }

  /// Number of sheets currently open across all hosts (and [showAdaptive]
  /// modal fallbacks). Sheets render inside their host's subtree, so chrome
  /// mounted above the navigator (the music mini-player) can never sit under
  /// them — such chrome listens here and hides itself while this is nonzero.
  static final ValueNotifier<int> openSheetCount = ValueNotifier<int>(0);

  /// Whether a sheet is currently showing (including while animating closed).
  bool get isOpen => _state._isOpen;

  /// Show a sheet with [builder] content. Returns a Future that completes
  /// when the sheet is closed (with an optional result).
  ///
  /// [alignment] controls where the sheet appears. Defaults to
  /// [Alignment.center]. Use [Alignment.centerRight] for player parameters.
  /// [showDragHandle] is retained for source compatibility; floating panels
  /// never display handles or dismiss while scrolling.
  Future<T?> show<T>({
    required WidgetBuilder builder,
    BoxConstraints? constraints,
    Color? backgroundColor,
    bool barrierDismissible = true,
    bool Function()? canDismiss,
    FocusNode? initialFocusNode,
    Alignment alignment = Alignment.center,
    bool showDragHandle = false,
    OverlaySheetStyle style = OverlaySheetStyle.solid,
    double blurSigma = 32,
    Rect? anchor,
  }) {
    return _state._show<T>(
      builder: builder,
      constraints: constraints,
      backgroundColor: backgroundColor,
      barrierDismissible: barrierDismissible,
      canDismiss: canDismiss,
      initialFocusNode: initialFocusNode,
      alignment: alignment,
      showDragHandle: showDragHandle,
      style: style,
      blurSigma: blurSigma,
      anchor: anchor,
    );
  }

  /// Push a sub-page within the open sheet. Returns a Future that completes
  /// when the pushed page is popped (with an optional result).
  Future<T?> push<T>({required WidgetBuilder builder, FocusNode? initialFocusNode}) {
    return _state._push<T>(builder: builder, initialFocusNode: initialFocusNode);
  }

  /// Pop the top sub-page, or close the sheet if on the last page.
  void pop([dynamic result]) {
    _state._pop(result);
  }

  /// Force close the sheet, completing all pending completers.
  void close([dynamic result]) {
    _state._close(result);
  }

  /// Re-focus the first focusable descendant within the sheet.
  /// Useful after internal page changes via setState.
  void refocus() {
    _state._autoFocus(clearSelectSuppression: false);
  }

  /// Absolute height ceiling for resizable desktop windows. Without it a 4K
  /// window yields a 1620px sheet, which reads as a wall of list rather than a
  /// sheet.
  static const _windowedMaxHeight = 720.0;

  /// Sizing applied when a caller supplies no explicit constraints: three
  /// quarters of the viewport height everywhere, the capped width on wide
  /// viewports, and the absolute height ceiling on desktop windows only.
  ///
  /// Both caps require `width > 600`. The height ceiling additionally requires
  /// a desktop OS and not TV, because it exists for a window the user can
  /// resize arbitrarily tall: a portrait tablet and a 10-foot UI keep the full
  /// 75%, and so does a desktop window narrower than 601px, which is
  /// phone-shaped and where 75% is the norm.
  static BoxConstraints _defaultSheetConstraints(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWideViewport = size.width > 600;
    final isDesktopWindow = isWideViewport && PlatformDetector.isDesktopOS() && !PlatformDetector.isTV();
    final maxHeight = size.height * 0.75;
    return BoxConstraints(
      maxWidth: PlatformDetector.isTV() ? 440 : (isWideViewport ? 700 : double.infinity),
      maxHeight: isDesktopWindow ? math.min(maxHeight, _windowedMaxHeight) : maxHeight,
    );
  }

  /// Show a sheet using the overlay system if available, otherwise fall back
  /// to a floating modal dialog. Returns the result from the panel.
  static Future<T?> showAdaptive<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    BoxConstraints? constraints,
    Color? backgroundColor,
    bool barrierDismissible = true,
    bool isScrollControlled = false,
    FocusNode? initialFocusNode,
    Alignment alignment = Alignment.center,
    bool showDragHandle = false,
  }) async {
    final controller = maybeOf(context);
    if (controller != null) {
      return controller.show<T>(
        builder: builder,
        constraints: constraints,
        backgroundColor: backgroundColor,
        barrierDismissible: barrierDismissible,
        initialFocusNode: initialFocusNode,
        alignment: alignment,
        showDragHandle: showDragHandle,
      );
    }
    final effectiveConstraints = constraints ?? _defaultSheetConstraints(context);
    openSheetCount.value++;
    BackKeyCoordinator.clear();
    try {
      return await showGeneralDialog<T>(
        context: context,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.black54,
        barrierDismissible: barrierDismissible,
        transitionDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 170),
        pageBuilder: (dialogContext, _, _) => _FallbackFloatingPanel(
          alignment: alignment,
          constraints: effectiveConstraints,
          backgroundColor: backgroundColor,
          initialFocusNode: initialFocusNode,
          builder: builder,
        ),
        transitionBuilder: (context, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(animation), child: child),
        ),
      );
    } finally {
      openSheetCount.value--;
    }
  }

  /// Push a sub-page using the overlay system if available, otherwise fall
  /// back to a floating modal dialog. Returns the result from the page.
  ///
  /// When a hosted sheet is already open, this pushes a nested page and
  /// retains the root sheet's presentation. When a host is available but
  /// idle, this opens [builder] as its root sheet using the supplied hosted
  /// presentation options. Without a host, the modal fallback is used.
  ///
  /// [isScrollControlled] applies only to the modal fallback; hosted sheets
  /// use their explicit or default constraints.
  static Future<T?> pushAdaptive<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    FocusNode? initialFocusNode,
    BoxConstraints? constraints,
    Color? backgroundColor,
    bool barrierDismissible = true,
    bool isScrollControlled = false,
    bool showDragHandle = false,
    Alignment alignment = Alignment.center,
  }) async {
    final controller = maybeOf(context);
    if (controller != null) {
      if (controller.isOpen) {
        return controller.push<T>(builder: builder, initialFocusNode: initialFocusNode);
      }
      return controller.show<T>(
        builder: builder,
        constraints: constraints,
        backgroundColor: backgroundColor,
        barrierDismissible: barrierDismissible,
        initialFocusNode: initialFocusNode,
        showDragHandle: showDragHandle,
        alignment: alignment,
      );
    }
    BackKeyCoordinator.clear();
    return showAdaptive<T>(
      context,
      builder: builder,
      constraints: constraints,
      backgroundColor: backgroundColor,
      barrierDismissible: barrierDismissible,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      alignment: alignment,
    );
  }

  /// Close the sheet entirely. Uses overlay controller if available,
  /// otherwise pops the route.
  static void closeAdaptive(BuildContext context, [dynamic result]) {
    final controller = maybeOf(context);
    if (controller != null) {
      controller.close(result);
    } else {
      Navigator.pop(context, result);
    }
  }

  /// Pop one level (sub-page or close if last page). Uses overlay controller
  /// if available, otherwise pops the route.
  static void popAdaptive(BuildContext context, [dynamic result]) {
    final controller = maybeOf(context);
    if (controller != null) {
      controller.pop(result);
    } else {
      Navigator.pop(context, result);
    }
  }
}

/// Host widget for the overlay-based floating panel system.
///
/// Sheets are rendered as overlays within this widget's Stack instead of as
/// modal routes, eliminating the route-based back-button race condition on
/// Android TV and providing centralized focus management for keyboard/dpad
/// navigation on all platforms.
///
/// ## Back handling
///
/// The host already owns the dpad/key back path (its sheet [FocusScope] closes
/// the sheet on BACK when focus is inside it). For the system/route back path
/// (Android gesture, iOS swipe, predictive back), opt in via [canPop]: the host
/// then renders its own [PopScope] that closes an open sheet instead of popping
/// the screen, so callers don't have to hand-roll it. When [canPop] is null
/// (the default) the host adds no [PopScope] and behaves exactly as before.
class OverlaySheetHost extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool>? onOpenChanged;

  /// Whether the enclosing route may pop when no sheet is open (the screen's own
  /// business rule, mirroring [PopScope.canPop]).
  ///
  /// When non-null the host installs a [PopScope]:
  /// - a system back with a sheet open closes the sheet (never pops the screen);
  /// - otherwise, if `canPop` is true the route pops natively (preserving the
  ///   iOS interactive swipe-back), and if false [onSystemBack] runs instead.
  ///
  /// When null (default) the host installs no [PopScope] — today's behavior.
  final bool? canPop;

  /// Called for a system/route back when no sheet is open and [canPop] is false.
  /// Not called when a sheet is open (the sheet is closed instead) or when
  /// [canPop] allows a native pop. Implementations that also have a dpad key
  /// handler should start with `if (BackKeyCoordinator.consumeIfHandled()) return;`
  /// so the system path dedups against the key path.
  final VoidCallback? onSystemBack;

  const OverlaySheetHost({super.key, required this.child, this.onOpenChanged, this.canPop, this.onSystemBack});

  @override
  State<OverlaySheetHost> createState() => _OverlaySheetHostState();
}

class _OverlaySheetHostState extends State<OverlaySheetHost> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final CurvedAnimation _slideCurve;
  late final Animation<double> _barrierAnimation;
  late final OverlaySheetController _controller;

  final List<_OverlaySheetEntry> _pageStack = [];
  final _sheetFocusScopeNode = FocusScopeNode(debugLabel: 'OverlaySheetScope');

  bool _isOpen = false;
  bool _isClosing = false;
  bool _barrierDismissible = true;
  bool Function()? _canDismiss;
  BoxConstraints? _constraints;
  Color? _explicitBackgroundColor;
  Alignment _alignment = Alignment.center;
  OverlaySheetStyle _style = OverlaySheetStyle.solid;
  double _blurSigma = 32;

  /// Global rect of the control that opened an anchored popover. The sheet
  /// sits above it, horizontally centred on it and clamped to the host.
  Rect? _anchor;
  FocusNode? _returnFocus;

  /// Bumped on every [_show]. Keys the resize animation so a freshly opened
  /// sheet adopts its own height immediately instead of animating down from
  /// the previous sheet's; nested pushes within one sheet still animate.
  ///
  /// Changing the key also remounts the sheet subtree, so a `show` that
  /// replaces a live sheet of the same widget type starts with fresh [State]
  /// rather than reconciling into the outgoing sheet's.
  int _sheetSession = 0;

  @override
  void initState() {
    super.initState();
    _controller = OverlaySheetController._(this);

    _animationController = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);

    _slideCurve = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _barrierAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    for (final entry in _pageStack) {
      if (!entry.completer.isCompleted) {
        entry.completer.complete(null);
      }
    }
    // A host torn down mid-sheet (or mid-close animation) never reaches the
    // close completion below — release its slot in the global count here.
    if (_isOpen) OverlaySheetController.openSheetCount.value--;
    _sheetFocusScopeNode.dispose();
    _slideCurve.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<T?> _show<T>({
    required WidgetBuilder builder,
    BoxConstraints? constraints,
    Color? backgroundColor,
    bool barrierDismissible = true,
    bool Function()? canDismiss,
    FocusNode? initialFocusNode,
    Alignment alignment = Alignment.center,
    bool showDragHandle = false,
    OverlaySheetStyle style = OverlaySheetStyle.solid,
    double blurSigma = 32,
    Rect? anchor,
  }) {
    BackKeyCoordinator.clear();
    // If already open, close first (instant)
    final wasOpen = _isOpen;
    if (_isOpen) {
      for (final entry in _pageStack) {
        if (!entry.completer.isCompleted) {
          entry.completer.complete(null);
        }
      }
      _pageStack.clear();
      _isClosing = false;
    }

    final completer = Completer<T?>();
    final entry = _OverlaySheetEntry(builder: builder, completer: completer, initialFocusNode: initialFocusNode);
    if (!wasOpen) _returnFocus = FocusManager.instance.primaryFocus;

    setState(() {
      _pageStack.add(entry);
      _sheetSession++;
      _isOpen = true;
      _isClosing = false;
      _barrierDismissible = barrierDismissible;
      _canDismiss = canDismiss;
      _constraints = constraints;
      _explicitBackgroundColor = backgroundColor;
      _alignment = alignment;
      _style = style;
      _blurSigma = blurSigma;
      _anchor = anchor;
    });
    if (!wasOpen) {
      widget.onOpenChanged?.call(true);
      OverlaySheetController.openSheetCount.value++;
    }

    BackKeyUpSuppressor.clearSuppression();
    _animationController.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 170);
    _animationController.forward(from: 0);
    _autoFocus();

    return completer.future;
  }

  Future<T?> _push<T>({required WidgetBuilder builder, FocusNode? initialFocusNode}) {
    if (!_isOpen || _isClosing) {
      return Future.value(null);
    }

    final completer = Completer<T?>();
    final entry = _OverlaySheetEntry(builder: builder, completer: completer, initialFocusNode: initialFocusNode);

    setState(() {
      _pageStack.add(entry);
    });

    _autoFocus();
    return completer.future;
  }

  void _pop([dynamic result]) {
    if (!_isOpen || _isClosing || _pageStack.isEmpty) return;

    if (_pageStack.length == 1) {
      _close(result);
      return;
    }

    final removed = _pageStack.removeLast();
    if (!removed.completer.isCompleted) {
      removed.completer.complete(result);
    }

    setState(() {});
    _autoFocus();
  }

  void _close([dynamic result]) {
    if (!_isOpen || _isClosing) return;
    _isClosing = true;

    _animationController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        for (final entry in _pageStack) {
          if (!entry.completer.isCompleted) {
            entry.completer.complete(result);
          }
        }
        _pageStack.clear();
        _isOpen = false;
        _isClosing = false;
      });
      widget.onOpenChanged?.call(false);
      OverlaySheetController.openSheetCount.value--;
      final returnFocus = _returnFocus;
      _returnFocus = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A selection can immediately open a confirmation route. Let that
        // route claim focus instead of restoring into the covered page.
        if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
        if (returnFocus?.context != null && returnFocus!.canRequestFocus) returnFocus.requestFocus();
      });
    });
  }

  void _autoFocus({bool clearSelectSuppression = true}) {
    final focusDescendant = InputModeTracker.isKeyboardMode(context, listen: false);

    // First post-frame: the FocusScope is now built and the node is attached.
    // Always grab scope focus so key events (especially back) are trapped, even
    // when a pointer opened the sheet. In keyboard mode, a second post-frame
    // callback focuses the first descendant for dpad navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen) return;
      _sheetFocusScopeNode.requestFocus();
      if (!focusDescendant && _pageStack.last.initialFocusNode == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isOpen) return;
        // If the current top entry has an initialFocusNode that is attached,
        // focus that instead of the first descendant.
        final topEntry = _pageStack.isNotEmpty ? _pageStack.last : null;
        final initialNode = topEntry?.initialFocusNode;
        if (initialNode != null && initialNode.context != null) {
          initialNode.requestFocus();
        } else {
          _focusFirstDescendant();
        }

        // Clear stale select suppression from the press that opened this sheet,
        // but only if no select key is currently held down. This handles:
        // - Short press: key already released → clear flag (prevents first
        //   select inside the sheet from being eaten).
        // - Long press: key still held → keep flag so KeyRepeat/KeyUp events
        //   from the long press are correctly suppressed.
        if (clearSelectSuppression && !HardwareKeyboard.instance.logicalKeysPressed.any((k) => k.isSelectKey)) {
          SelectKeyUpSuppressor.clearSuppression();
        }
      });
    });
  }

  void _focusFirstDescendant() {
    final descendants = _sheetFocusScopeNode.traversalDescendants.toList();
    if (descendants.isNotEmpty) {
      descendants.first.requestFocus();
    } else {
      _sheetFocusScopeNode.requestFocus();
    }
  }

  void _handleBack() {
    if (!(_canDismiss?.call() ?? true)) return;
    if (_pageStack.length > 1) {
      _pop();
    } else {
      _close();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    // Suppress stale select key-ups
    if (SelectKeyUpSuppressor.consumeIfSuppressed(event)) {
      return KeyEventResult.handled;
    }

    // Suppress stale back key-ups
    if (BackKeyUpSuppressor.consumeIfSuppressed(event)) {
      return KeyEventResult.handled;
    }

    // Back key: pop sub-page or close sheet
    if (event.logicalKey.isBackKey) {
      if (PlatformDetector.isTV() && event is KeyDownEvent) {
        BackKeyCoordinator.markHandled();
      }
      return handleBackKeyAction(event, _handleBack);
    }

    // Let all other keys pass through. Directional keys need to reach
    // Flutter's DirectionalFocusAction for dpad/arrow navigation, and
    // select/enter keys need to reach ActivateAction for item taps.
    // The FocusScope traps traversal within the sheet; the screen-level
    // Focus catches any leaked nav keys.
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      children: [
        widget.child,
        // Barrier + sheet only when open
        if (_isOpen) ...[
          Positioned.fill(
            // The barrier swallows every pointer event behind it, so the
            // screen underneath must leave the semantics tree too. Without
            // this, assistive tech (and UI automation) still reads rows that
            // cannot be activated — including through the ~250ms close, where
            // a tap on a "visible" row lands on the barrier instead. Flutter's
            // own ModalBarrier blocks semantics for the same reason.
            child: BlockSemantics(
              child: AnimatedBuilder(
                animation: _barrierAnimation,
                builder: (context, child) {
                  return GestureDetector(
                    onTap: _barrierDismissible
                        ? () {
                            if (_canDismiss?.call() ?? true) _close();
                          }
                        : null,
                    child: ColoredBox(color: Colors.black.withValues(alpha: _barrierAnimation.value)),
                  );
                },
              ),
            ),
          ),
          _buildSheet(context),
        ],
      ],
    );

    // When a screen opts in via [canPop], the host owns the system/route back
    // path so callers don't hand-roll it: a back with a sheet open closes the
    // sheet (sub-page aware, matching the dpad path) instead of popping the
    // screen; otherwise the route pops natively (canPop true) or [onSystemBack]
    // runs (canPop false). `!_isClosing` lets a press during the ~250ms close
    // animation fall through instead of being swallowed.
    final canPop = widget.canPop;
    if (canPop != null) {
      content = PopScope(
        canPop: canPop && !_isOpen,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_isOpen && !_isClosing) {
            // Only TV routes one Back through both the focused key path and
            // the platform pop, so only TV needs to dedup them. Touch
            // platforms never deliver Back to [_handleKeyEvent], so consulting
            // the global marker here could only ever consume some unrelated
            // widget's mark and swallow the one signal that closes the sheet.
            // The marker is global and one-shot, so anything left set by
            // another handler would strand the sheet open with no way out.
            if (PlatformDetector.isTV() && BackKeyCoordinator.consumeIfHandled()) return;
            _handleBack();
            return;
          }
          widget.onSystemBack?.call();
        },
        child: content,
      );
    }

    return _OverlaySheetScope(controller: _controller, child: content);
  }

  /// Builds every page in the stack, showing only the top one.
  ///
  /// A pushed page covers the pages below it without replacing them: they stay
  /// mounted (offstage, with tickers and focus off) so their [State] survives,
  /// and a caller awaiting [OverlaySheetController.push] can still act on its
  /// own context when the nested page returns. An offstage page lays out at the
  /// smallest size, so the sheet keeps sizing to the top page alone.
  Widget _buildPageStack() {
    final top = _pageStack.last;
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        for (final entry in _pageStack)
          KeyedSubtree(
            key: ObjectKey(entry),
            child: Offstage(
              offstage: !identical(entry, top),
              child: TickerMode(
                enabled: identical(entry, top),
                child: ExcludeFocus(
                  excluding: !identical(entry, top),
                  child: Builder(builder: entry.builder),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSurface(BuildContext context, ColorScheme colorScheme, BoxConstraints constraints) {
    final body = AnimatedSize(
      key: ValueKey(_sheetSession),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: _alignment,
      child: ConstrainedBox(
        constraints: constraints,
        child: PrimaryScrollController.none(child: _pageStack.isNotEmpty ? _buildPageStack() : const SizedBox.shrink()),
      ),
    );
    if (_style == OverlaySheetStyle.solid) {
      return Material(
        color: _explicitBackgroundColor ?? colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: body,
      );
    }
    final glass = GlassSheetColors.of(context);
    final radius = BorderRadius.circular(_anchor == null ? 22 : 18);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [BoxShadow(color: Color(0x47000000), blurRadius: 36, offset: Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: Material(
            color: _explicitBackgroundColor ?? glass.surface,
            textStyle: TextStyle(color: glass.foreground),
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: glass.edge),
            ),
            clipBehavior: Clip.antiAlias,
            child: IconTheme.merge(
              data: IconThemeData(color: glass.foreground),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrapPlacement(BuildContext context, Widget sheet) {
    if (_anchor == null) return Align(alignment: _alignment, child: sheet);
    return Builder(builder: (context) => _positionAnchored(context, sheet));
  }

  /// Places an anchored popover above its trigger inside [host].
  ///
  /// The sheet layer sits inside a SafeArea plus a 12px inset, so the layout
  /// origin is the host's (already laid out) box shifted by both. Reading the
  /// popover's own box would be stale or null on its first frame.
  Widget _positionAnchored(BuildContext context, Widget sheet) {
    final anchor = _anchor!;
    final hostBox = this.context.findRenderObject() as RenderBox?;
    final hostOrigin = hostBox == null || !hostBox.hasSize ? Offset.zero : hostBox.localToGlobal(Offset.zero);
    final insets = MediaQuery.paddingOf(this.context);
    final origin = hostOrigin + Offset(insets.left + 12, insets.top + 12);
    return CustomSingleChildLayout(delegate: _AnchorAboveLayout(anchor.shift(-origin)), child: sheet);
  }

  Widget _buildSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveConstraints = _constraints ?? OverlaySheetController._defaultSheetConstraints(context);
    return Positioned.fill(
      child: SafeArea(
        child: AnimatedPadding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.viewInsetsOf(context).bottom),
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          child: FocusScope(
            node: _sheetFocusScopeNode,
            onKeyEvent: _handleKeyEvent,
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _handleKeyEvent,
              child: _wrapPlacement(
                context,
                AnimatedBuilder(
                  animation: _slideCurve,
                  builder: (context, child) => Opacity(
                    opacity: _slideCurve.value,
                    child: Transform.translate(
                      offset: Offset(_alignment.x * 20 * (1 - _slideCurve.value), 0),
                      child: Transform.scale(scale: 0.97 + 0.03 * _slideCurve.value, child: child),
                    ),
                  ),
                  child: _buildSurface(context, colorScheme, effectiveConstraints),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The same inset geometry when no host is mounted. The modal route supplies
/// focus restoration and system-back semantics; keyboard Back closes it too.
class _FallbackFloatingPanel extends StatefulWidget {
  const _FallbackFloatingPanel({
    required this.alignment,
    required this.constraints,
    required this.backgroundColor,
    required this.initialFocusNode,
    required this.builder,
  });

  final Alignment alignment;
  final BoxConstraints constraints;
  final Color? backgroundColor;
  final FocusNode? initialFocusNode;
  final WidgetBuilder builder;

  @override
  State<_FallbackFloatingPanel> createState() => _FallbackFloatingPanelState();
}

class _FallbackFloatingPanelState extends State<_FallbackFloatingPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = widget.initialFocusNode;
      if (node?.context != null && node!.canRequestFocus) node.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 170),
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.viewInsetsOf(context).bottom),
        child: Align(
          alignment: widget.alignment,
          child: FocusScope(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (SelectKeyUpSuppressor.consumeIfSuppressed(event)) return KeyEventResult.handled;
              if (BackKeyUpSuppressor.consumeIfSuppressed(event)) return KeyEventResult.handled;
              if (event.logicalKey.isBackKey) return handleBackKeyAction(event, () => Navigator.pop(context));
              return KeyEventResult.ignored;
            },
            child: Material(
              color: widget.backgroundColor ?? colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.45)),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: widget.constraints,
                child: PrimaryScrollController.none(child: Builder(builder: widget.builder)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays a popover out above [anchor] (in the host's coordinates), centred on
/// it horizontally and kept inside the host; it may use the full height above
/// the anchor.
class _AnchorAboveLayout extends SingleChildLayoutDelegate {
  _AnchorAboveLayout(this.anchor);

  final Rect anchor;
  static const _gap = 8.0;

  /// Leaves the player's top bar (back, title, top-right actions) uncovered.
  static const _topReserve = 64.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth, maxHeight: math.max(0.0, anchor.top - _gap - _topReserve));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double left = (anchor.center.dx - childSize.width / 2).clamp(
      0.0,
      math.max(0.0, size.width - childSize.width),
    );
    final top = math.max(_topReserve, anchor.top - _gap - childSize.height);
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_AnchorAboveLayout oldDelegate) => oldDelegate.anchor != anchor;
}
