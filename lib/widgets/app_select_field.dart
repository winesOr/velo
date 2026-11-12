import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../focus/focusable_wrapper.dart';
import '../theme/velo_brand.dart';
import '../theme/interaction_tokens.dart';
import '../utils/selection_feedback.dart';
import 'app_icon.dart';
import 'app_menu.dart';
import 'press_feedback.dart';

class AppSelectOption<T> {
  const AppSelectOption({required this.value, required this.label, this.subtitle, this.enabled = true});

  final T value;
  final String label;
  final String? subtitle;
  final bool enabled;

  String get semanticLabel => subtitle == null ? label : '$label, $subtitle';
}

/// A focusable, two-line selection field backed by the shared anchored menu.
class AppSelectField<T> extends StatefulWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.placeholder,
    this.enabled = true,
    this.busy = false,
    this.compact = false,
    this.focusNode,
  });

  final String label;
  final T? value;
  final String? placeholder;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final bool enabled;
  final bool busy;
  final bool compact;
  final FocusNode? focusNode;

  @override
  State<AppSelectField<T>> createState() => _AppSelectFieldState<T>();
}

class _AppSelectFieldState<T> extends State<AppSelectField<T>> {
  late final FocusNode _ownedFocusNode = FocusNode(debugLabel: 'AppSelectField');
  bool _menuOpen = false;
  bool _pressed = false;

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode;
  bool get _enabled => widget.enabled && widget.onChanged != null && widget.options.any((option) => option.enabled);
  bool get _canOpen => _enabled && !widget.busy && !_menuOpen;

  @override
  void dispose() {
    _ownedFocusNode.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  Future<void> _open() async {
    if (!_canOpen) return;
    setState(() {
      _menuOpen = true;
      _pressed = false;
    });
    T? result;
    try {
      result = await showAdaptiveAppMenu<T>(
        context,
        title: widget.label,
        focusFirstItem: true,
        selectionDelay: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : InteractionTokens.menuSelectionDuration,
        entries: [
          for (final option in widget.options)
            AppMenuItem<T>(
              value: option.value,
              label: option.label,
              subtitle: option.subtitle,
              enabled: option.enabled,
              selected: option.value == widget.value,
              autofocus: option.value == widget.value,
              wrapLines: true,
              minHeight: 48,
              semanticLabel: option.semanticLabel,
            ),
        ],
      );
    } finally {
      if (mounted) {
        setState(() => _menuOpen = false);
        if (_enabled) _focusNode.requestFocus();
      }
    }
    if (!mounted || result == null || !_canOpen) return;
    // The track list may have changed while the menu was open.
    if (!widget.options.any((option) => option.enabled && option.value == result)) return;
    if (result != widget.value) selectionFeedback();
    widget.onChanged?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = VeloBrand.foreground(theme.brightness);
    AppSelectOption<T>? selected;
    for (final option in widget.options) {
      if (option.value == widget.value) {
        selected = option;
        break;
      }
    }
    final title = selected?.label ?? widget.placeholder ?? widget.label;
    final subtitle = selected?.subtitle;
    const radius = BorderRadius.all(Radius.circular(14));
    return FocusableWrapper(
      focusNode: _focusNode,
      canRequestFocus: _enabled,
      disableScale: true,
      borderRadius: 14,
      focusColor: accent,
      descendantsAreFocusable: false,
      semanticLabel: widget.label,
      semanticValue: selected?.semanticLabel ?? title,
      onSelect: _canOpen ? _open : null,
      onFocusChange: (focused) {
        if (!focused && _pressed) _setPressed(false);
      },
      onKeyEvent: (node, event) {
        final selectKeys = {
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.select,
          LogicalKeyboardKey.gameButtonA,
        };
        if (selectKeys.contains(event.logicalKey)) {
          _setPressed(_canOpen && event is KeyDownEvent);
        }
        return KeyEventResult.ignored;
      },
      child: PressFeedback(
        pressed: _pressed,
        enabled: _enabled && !widget.busy,
        child: Material(
          color: _menuOpen ? VeloBrand.selection(theme.brightness) : colors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: _menuOpen ? accent : colors.onSurface.withValues(alpha: .08),
              width: _menuOpen ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            canRequestFocus: false,
            enableFeedback: false,
            onTap: _canOpen ? _open : null,
            onHighlightChanged: _setPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.compact ? 52 : 58),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurface.withValues(alpha: _enabled ? 1 : .38),
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: colors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.busy)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      AppIcon(_menuOpen ? Symbols.expand_less_rounded : Symbols.expand_more_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
