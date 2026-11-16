import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../services/device_performance.dart';
import '../theme/interaction_tokens.dart';

/// Paint-only feedback. The existing control owns gestures and activation.
/// Feed this the control's highlight state so a scroll cancels the press too.
class PressFeedback extends StatelessWidget {
  const PressFeedback({
    super.key,
    required this.pressed,
    required this.child,
    this.enabled = true,
    this.pressedScale = InteractionTokens.selectPressedScale,
    this.pressDuration = InteractionTokens.pressDuration,
    this.releaseDuration = InteractionTokens.releaseDuration,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final bool pressed;
  final bool enabled;
  final Widget child;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final active = enabled && pressed;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : (active ? pressDuration : releaseDuration);
    return AnimatedScale(
      scale: active && !reduceMotion ? pressedScale : 1,
      duration: duration,
      curve: InteractionTokens.pressCurve,
      child: AnimatedContainer(
        duration: DevicePerformance.isReduced ? Duration.zero : duration,
        curve: InteractionTokens.pressCurve,
        foregroundDecoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .08) : Colors.transparent,
          borderRadius: borderRadius,
        ),
        child: _PressFeedbackScope(child: child),
      ),
    );
  }
}

/// Connects existing gesture/highlight and keyboard-confirm callbacks to a
/// local feedback state. It adds no recognizer, haptic or business callback.
class PressFeedbackBuilder extends StatefulWidget {
  const PressFeedbackBuilder({
    super.key,
    required this.builder,
    this.pressedScale = InteractionTokens.selectPressedScale,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final Widget Function(BuildContext context, ValueChanged<bool> setPressed, VoidCallback confirm) builder;
  final double pressedScale;
  final bool enabled;
  final BorderRadius borderRadius;

  @override
  State<PressFeedbackBuilder> createState() => _PressFeedbackBuilderState();
}

class _PressFeedbackBuilderState extends State<PressFeedbackBuilder> {
  bool _pressed = false;
  Timer? _confirmation;

  void _setPressed(bool value) {
    _confirmation?.cancel();
    if (!mounted) return;
    final next = widget.enabled && value;
    if (next != _pressed) setState(() => _pressed = next);
  }

  void _confirm() {
    if (!widget.enabled) return;
    _setPressed(true);
    _confirmation = Timer(InteractionTokens.pressDuration, () => _setPressed(false));
  }

  @override
  void dispose() {
    _confirmation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PressFeedback(
    pressed: _pressed,
    enabled: widget.enabled,
    pressedScale: widget.pressedScale,
    borderRadius: widget.borderRadius,
    child: widget.builder(context, _setPressed, _confirm),
  );
}

/// Marks controls already owning feedback so nested buttons do not shrink twice.
class _PressFeedbackScope extends InheritedWidget {
  const _PressFeedbackScope({required super.child});

  @override
  bool updateShouldNotify(_PressFeedbackScope oldWidget) => false;
}

/// Observes pointer/key state without adding a gesture recognizer or activation.
/// Scrolling cancels feedback after touch slop; the child still owns the gesture.
class PressFeedbackRegion extends StatefulWidget {
  const PressFeedbackRegion({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  static void observeKey(BuildContext context, KeyEvent event) {
    var state = context.findAncestorStateOfType<_PressFeedbackRegionState>();
    while (state != null && !state._ownsFeedback) {
      state = state.context.findAncestorStateOfType<_PressFeedbackRegionState>();
    }
    state?._observeKey(event);
  }

  @override
  State<PressFeedbackRegion> createState() => _PressFeedbackRegionState();
}

class _PressFeedbackRegionState extends State<PressFeedbackRegion> {
  int? _pointer;
  Offset? _origin;
  bool _pressed = false;
  bool _ownsFeedback = false;

  void _setPressed(bool value) {
    final next = widget.enabled && value;
    if (_pressed != next) setState(() => _pressed = next);
  }

  void _release() {
    _pointer = null;
    _origin = null;
    _setPressed(false);
  }

  void _observeKey(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (event is KeyDownEvent) _setPressed(true);
      if (event is KeyUpEvent) _release();
    }
  }

  @override
  void didUpdateWidget(PressFeedbackRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pointer = null;
      _origin = null;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _ownsFeedback = widget.enabled && context.dependOnInheritedWidgetOfExactType<_PressFeedbackScope>() == null;
    if (!_ownsFeedback) return widget.child;
    return PressFeedback(
      pressed: _pressed,
      enabled: widget.enabled,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (focused) {
          if (!focused) _release();
        },
        onKeyEvent: (node, event) {
          _observeKey(event);
          return KeyEventResult.ignored;
        },
        child: Listener(
          onPointerDown: (event) {
            if (!widget.enabled || _pointer != null || event.buttons != kPrimaryButton) return;
            _pointer = event.pointer;
            _origin = event.position;
            _setPressed(true);
          },
          onPointerMove: (event) {
            if (event.pointer == _pointer && (event.position - _origin!).distance > kTouchSlop) _release();
          },
          onPointerUp: (event) {
            if (event.pointer == _pointer) _release();
          },
          onPointerCancel: (event) {
            if (event.pointer == _pointer) _release();
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Material InkWell with the app's shared press feedback.
class PressFeedbackInkWell extends InkWell {
  const PressFeedbackInkWell({
    super.key,
    super.child,
    super.onTap,
    super.onDoubleTap,
    super.onLongPress,
    super.onLongPressUp,
    super.onTapDown,
    super.onTapUp,
    super.onTapCancel,
    super.onSecondaryTap,
    super.onSecondaryTapUp,
    super.onSecondaryTapDown,
    super.onSecondaryTapCancel,
    super.onHighlightChanged,
    super.onHover,
    super.mouseCursor,
    super.focusColor,
    super.hoverColor,
    super.highlightColor,
    super.overlayColor,
    super.splashColor,
    super.splashFactory,
    super.radius,
    super.borderRadius,
    super.customBorder,
    super.enableFeedback,
    super.excludeFromSemantics,
    super.focusNode,
    super.canRequestFocus,
    super.onFocusChange,
    super.autofocus,
    super.statesController,
    super.hoverDuration,
  });

  @override
  Widget build(BuildContext context) => PressFeedbackRegion(
    enabled: onTap != null || onDoubleTap != null || onLongPress != null || onSecondaryTap != null,
    child: InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onLongPressUp: onLongPressUp,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapUp: onSecondaryTapUp,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapCancel: onSecondaryTapCancel,
      onHighlightChanged: onHighlightChanged,
      onHover: onHover,
      mouseCursor: mouseCursor,
      focusColor: focusColor,
      hoverColor: hoverColor,
      highlightColor: highlightColor,
      overlayColor: overlayColor,
      splashColor: splashColor,
      splashFactory: splashFactory,
      radius: radius,
      borderRadius: borderRadius,
      customBorder: customBorder,
      enableFeedback: enableFeedback,
      excludeFromSemantics: excludeFromSemantics,
      focusNode: focusNode,
      canRequestFocus: canRequestFocus,
      onFocusChange: onFocusChange,
      autofocus: autofocus,
      statesController: statesController,
      hoverDuration: hoverDuration,
      child: child,
    ),
  );
}

/// Material ListTile with the app's shared press feedback.
class PressFeedbackListTile extends ListTile {
  const PressFeedbackListTile({
    super.key,
    super.leading,
    super.title,
    super.subtitle,
    super.trailing,
    super.isThreeLine,
    super.dense,
    super.visualDensity,
    super.shape,
    super.style,
    super.selectedColor,
    super.iconColor,
    super.textColor,
    super.titleTextStyle,
    super.subtitleTextStyle,
    super.leadingAndTrailingTextStyle,
    super.contentPadding,
    super.enabled,
    super.onTap,
    super.onLongPress,
    super.onFocusChange,
    super.mouseCursor,
    super.selected,
    super.focusColor,
    super.hoverColor,
    super.splashColor,
    super.focusNode,
    super.autofocus,
    super.tileColor,
    super.selectedTileColor,
    super.enableFeedback,
    super.horizontalTitleGap,
    super.minVerticalPadding,
    super.minLeadingWidth,
    super.minTileHeight,
    super.titleAlignment,
    super.internalAddSemanticForOnTap,
    super.statesController,
  });

  @override
  Widget build(BuildContext context) => PressFeedbackRegion(
    enabled: enabled && (onTap != null || onLongPress != null),
    child: ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      isThreeLine: isThreeLine,
      dense: dense,
      visualDensity: visualDensity,
      shape: shape,
      style: style,
      selectedColor: selectedColor,
      iconColor: iconColor,
      textColor: textColor,
      titleTextStyle: titleTextStyle,
      subtitleTextStyle: subtitleTextStyle,
      leadingAndTrailingTextStyle: leadingAndTrailingTextStyle,
      contentPadding: contentPadding,
      enabled: enabled,
      onTap: onTap,
      onLongPress: onLongPress,
      onFocusChange: onFocusChange,
      mouseCursor: mouseCursor,
      selected: selected,
      focusColor: focusColor,
      hoverColor: hoverColor,
      splashColor: splashColor,
      focusNode: focusNode,
      autofocus: autofocus,
      tileColor: tileColor,
      selectedTileColor: selectedTileColor,
      enableFeedback: enableFeedback,
      horizontalTitleGap: horizontalTitleGap,
      minVerticalPadding: minVerticalPadding,
      minLeadingWidth: minLeadingWidth,
      minTileHeight: minTileHeight,
      titleAlignment: titleAlignment,
      internalAddSemanticForOnTap: internalAddSemanticForOnTap,
      statesController: statesController,
    ),
  );
}

/// Material SwitchListTile with the app's shared press feedback.
class PressFeedbackSwitchListTile extends SwitchListTile {
  const PressFeedbackSwitchListTile({
    super.key,
    required super.value,
    required super.onChanged,
    super.activeThumbColor,
    super.activeTrackColor,
    super.inactiveThumbColor,
    super.inactiveTrackColor,
    super.activeThumbImage,
    super.onActiveThumbImageError,
    super.inactiveThumbImage,
    super.onInactiveThumbImageError,
    super.thumbColor,
    super.trackColor,
    super.trackOutlineColor,
    super.thumbIcon,
    super.materialTapTargetSize,
    super.dragStartBehavior,
    super.mouseCursor,
    super.overlayColor,
    super.splashRadius,
    super.focusNode,
    super.statesController,
    super.onFocusChange,
    super.autofocus,
    super.tileColor,
    super.title,
    super.subtitle,
    super.isThreeLine,
    super.dense,
    super.contentPadding,
    super.secondary,
    super.selected,
    super.controlAffinity,
    super.shape,
    super.selectedTileColor,
    super.visualDensity,
    super.enableFeedback,
    super.horizontalTitleGap,
    super.minVerticalPadding,
    super.minLeadingWidth,
    super.minTileHeight,
    super.hoverColor,
    super.internalAddSemanticForOnTap,
  });

  @override
  Widget build(BuildContext context) => PressFeedbackRegion(
    enabled: onChanged != null,
    child: SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeThumbColor,
      activeTrackColor: activeTrackColor,
      inactiveThumbColor: inactiveThumbColor,
      inactiveTrackColor: inactiveTrackColor,
      activeThumbImage: activeThumbImage,
      onActiveThumbImageError: onActiveThumbImageError,
      inactiveThumbImage: inactiveThumbImage,
      onInactiveThumbImageError: onInactiveThumbImageError,
      thumbColor: thumbColor,
      trackColor: trackColor,
      trackOutlineColor: trackOutlineColor,
      thumbIcon: thumbIcon,
      materialTapTargetSize: materialTapTargetSize,
      dragStartBehavior: dragStartBehavior,
      mouseCursor: mouseCursor,
      overlayColor: overlayColor,
      splashRadius: splashRadius,
      focusNode: focusNode,
      statesController: statesController,
      onFocusChange: onFocusChange,
      autofocus: autofocus,
      tileColor: tileColor,
      title: title,
      subtitle: subtitle,
      isThreeLine: isThreeLine,
      dense: dense,
      contentPadding: contentPadding,
      secondary: secondary,
      selected: selected,
      controlAffinity: controlAffinity,
      shape: shape,
      selectedTileColor: selectedTileColor,
      visualDensity: visualDensity,
      enableFeedback: enableFeedback,
      horizontalTitleGap: horizontalTitleGap,
      minVerticalPadding: minVerticalPadding,
      minLeadingWidth: minLeadingWidth,
      minTileHeight: minTileHeight,
      hoverColor: hoverColor,
      internalAddSemanticForOnTap: internalAddSemanticForOnTap,
    ),
  );
}

/// Material CheckboxListTile with the app's shared press feedback.
class PressFeedbackCheckboxListTile extends CheckboxListTile {
  const PressFeedbackCheckboxListTile({
    super.key,
    required super.value,
    required super.onChanged,
    super.mouseCursor,
    super.activeColor,
    super.fillColor,
    super.checkColor,
    super.hoverColor,
    super.overlayColor,
    super.splashRadius,
    super.materialTapTargetSize,
    super.visualDensity,
    super.focusNode,
    super.statesController,
    super.autofocus,
    super.shape,
    super.side,
    super.isError,
    super.enabled,
    super.tileColor,
    super.title,
    super.subtitle,
    super.isThreeLine,
    super.dense,
    super.secondary,
    super.selected,
    super.controlAffinity,
    super.contentPadding,
    super.tristate,
    super.checkboxShape,
    super.selectedTileColor,
    super.onFocusChange,
    super.enableFeedback,
    super.horizontalTitleGap,
    super.minVerticalPadding,
    super.minLeadingWidth,
    super.minTileHeight,
    super.checkboxSemanticLabel,
    super.checkboxScaleFactor,
    super.titleAlignment,
    super.internalAddSemanticForOnTap,
  });

  @override
  Widget build(BuildContext context) => PressFeedbackRegion(
    enabled: enabled != false && onChanged != null,
    child: CheckboxListTile(
      value: value,
      onChanged: onChanged,
      mouseCursor: mouseCursor,
      activeColor: activeColor,
      fillColor: fillColor,
      checkColor: checkColor,
      hoverColor: hoverColor,
      overlayColor: overlayColor,
      splashRadius: splashRadius,
      materialTapTargetSize: materialTapTargetSize,
      visualDensity: visualDensity,
      focusNode: focusNode,
      statesController: statesController,
      autofocus: autofocus,
      shape: shape,
      side: side,
      isError: isError,
      enabled: enabled,
      tileColor: tileColor,
      title: title,
      subtitle: subtitle,
      isThreeLine: isThreeLine,
      dense: dense,
      secondary: secondary,
      selected: selected,
      controlAffinity: controlAffinity,
      contentPadding: contentPadding,
      tristate: tristate,
      checkboxShape: checkboxShape,
      selectedTileColor: selectedTileColor,
      onFocusChange: onFocusChange,
      enableFeedback: enableFeedback,
      horizontalTitleGap: horizontalTitleGap,
      minVerticalPadding: minVerticalPadding,
      minLeadingWidth: minLeadingWidth,
      minTileHeight: minTileHeight,
      checkboxSemanticLabel: checkboxSemanticLabel,
      checkboxScaleFactor: checkboxScaleFactor,
      titleAlignment: titleAlignment,
      internalAddSemanticForOnTap: internalAddSemanticForOnTap,
    ),
  );
}
