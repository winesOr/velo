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
  const AppSelectOption({required this.value, required this.label, this.subtitle, this.leading, this.enabled = true});

  final T value;
  final String label;
  final String? subtitle;
  final bool enabled;
  final Widget? leading;

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
    this.leading,
    this.selectedLabel,
    this.selectedSubtitle,
    this.showChevron = true,
    this.inlineContent,
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
  final Widget? leading;

  /// Optional closed-field presentation; menu options retain their own labels.
  /// When supplied, [selectedSubtitle] replaces the option subtitle, even null.
  final String? selectedLabel;
  final String? selectedSubtitle;
  final bool showChevron;

  /// Optional single-row capsule content; the default field layout is unchanged.
  final Widget? inlineContent;

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
              leading: option.leading,
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
    const accent = VeloBrand.accent;
    AppSelectOption<T>? selected;
    for (final option in widget.options) {
      if (option.value == widget.value) {
        selected = option;
        break;
      }
    }
    final title = widget.selectedLabel ?? selected?.label ?? widget.placeholder ?? widget.label;
    final subtitle = widget.selectedLabel != null ? widget.selectedSubtitle : selected?.subtitle;
    final semanticValue = widget.selectedLabel != null
        ? subtitle == null
              ? title
              : '$title, $subtitle'
        : selected?.semanticLabel ?? title;
    final cornerRadius = widget.inlineContent == null ? 14.0 : 12.0;
    final radius = BorderRadius.all(Radius.circular(cornerRadius));
    return FocusableWrapper(
      focusNode: _focusNode,
      canRequestFocus: _enabled,
      disableScale: true,
      borderRadius: cornerRadius,
      focusColor: VeloBrand.foreground(theme.brightness),
      descendantsAreFocusable: false,
      semanticLabel: widget.label,
      semanticValue: semanticValue,
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
          color: colors.onSurface.withValues(alpha: .04),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: _menuOpen ? accent : colors.onSurface.withValues(alpha: .08),
              width: _menuOpen ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: PressFeedbackInkWell(
            canRequestFocus: false,
            enableFeedback: false,
            onTap: _canOpen ? _open : null,
            onHighlightChanged: _setPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.inlineContent != null
                    ? 38
                    : widget.compact
                    ? 52
                    : 58,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.inlineContent != null ? 6 : 8),
                child: Row(
                  children: [
                    if (widget.leading != null)
                      Padding(
                        padding: EdgeInsets.only(right: widget.inlineContent != null ? 7 : 12),
                        child: ExcludeSemantics(child: widget.leading!),
                      ),
                    Expanded(
                      child:
                          widget.inlineContent ??
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                softWrap: true,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurface.withValues(alpha: _enabled ? 1 : .38),
                                ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle,
                                  softWrap: true,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                    ),
                    if (widget.busy || widget.showChevron) const SizedBox(width: 8),
                    if (widget.busy)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    else if (widget.showChevron)
                      AppIcon(
                        widget.inlineContent != null
                            ? Symbols.chevron_right_rounded
                            : _menuOpen
                            ? Symbols.expand_less_rounded
                            : Symbols.expand_more_rounded,
                        size: widget.inlineContent != null ? 17 : 20,
                      ),
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
