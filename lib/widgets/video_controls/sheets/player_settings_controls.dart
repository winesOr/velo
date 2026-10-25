import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../focus/focusable_button.dart';
import '../../../focus/focusable_slider.dart';
import '../../../focus/focusable_wrapper.dart';
import '../../../i18n/strings.g.dart';
import '../../../theme/glass_slider_thumb_shape.dart';
import '../../../theme/velo_brand.dart';
import '../../../theme/mono_presentation.dart';
import '../../../utils/selection_feedback.dart';
import '../../app_icon.dart';
import '../../overlay_sheet.dart';

/// Sizes and colors measured from player.html's drawer, options and range rows.
class PlayerDrawerStyle extends StatelessWidget {
  const PlayerDrawerStyle({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tablet = MonoPresentation.isTablet(context);
    final theme = Theme.of(context);
    final glass = GlassSheetColors.of(context);
    final accent = VeloBrand.foreground(theme.brightness);
    return Theme(
      data: theme.copyWith(
        splashFactory: InkRipple.splashFactory,
        splashColor: accent.withValues(alpha: .18),
        highlightColor: accent.withValues(alpha: .09),
        textTheme: theme.textTheme.apply(bodyColor: glass.foreground, displayColor: glass.foreground),
        iconTheme: IconThemeData(color: glass.foreground, size: 18),
        listTileTheme: ListTileThemeData(
          minTileHeight: tablet ? 48 : 40,
          minLeadingWidth: 18,
          horizontalTitleGap: 8,
          minVerticalPadding: 6,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          titleTextStyle: theme.textTheme.bodyMedium?.copyWith(fontSize: tablet ? 15 : 13, color: glass.foreground),
          subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(fontSize: tablet ? 12 : 11, color: glass.muted),
          textColor: glass.foreground,
          iconColor: glass.foreground,
          selectedColor: accent,
          selectedTileColor: VeloBrand.selection(theme.brightness),
        ),
        sliderTheme: theme.sliderTheme.copyWith(
          activeTrackColor: accent,
          inactiveTrackColor: glass.foreground.withValues(alpha: .16),
          trackHeight: 4,
          trackGap: 0,
          trackShape: const RoundedRectSliderTrackShape(),
          thumbShape: GlassSliderThumbShape(radius: 8, color: accent),
          thumbColor: accent,
          overlayShape: SliderComponentShape.noOverlay,
          tickMarkShape: SliderTickMarkShape.noTickMark,
        ),
      ),
      child: child,
    );
  }
}

class PlayerDrawerHeading extends StatelessWidget {
  const PlayerDrawerHeading(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 7),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: GlassSheetColors.of(context).muted,
      ),
    ),
  );
}

class PlayerDrawerChoice extends StatelessWidget {
  const PlayerDrawerChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.focusNode,
    this.tab = false,
    this.feedbackOnChange = true,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool tab;
  final bool feedbackOnChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = GlassSheetColors.of(context);
    final accent = VeloBrand.foreground(theme.brightness);
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(tab ? 9 : 10);
    void activate() {
      if (feedbackOnChange && !tab && !selected) selectionFeedback();
      onTap?.call();
    }

    return Semantics(
      button: true,
      selected: selected,
      child: FocusableButton(
        focusNode: focusNode,
        onPressed: onTap == null ? null : activate,
        dimWhenUnfocused: false,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
          constraints: BoxConstraints(minHeight: tab ? 28 : 30),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(VeloBrand.selection(theme.brightness), accent, .12)!,
                      VeloBrand.selection(theme.brightness),
                    ],
                  )
                : null,
            color: selected
                ? VeloBrand.selection(theme.brightness)
                : tab
                ? Colors.transparent
                : glass.foreground.withValues(alpha: dark ? .07 : .05),
            borderRadius: radius,
            border: Border.all(color: selected ? accent.withValues(alpha: .32) : Colors.transparent),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? .14 : .06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : const [],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              canRequestFocus: false,
              onTap: onTap == null ? null : activate,
              onLongPress: onLongPress,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tab ? 0 : 12, vertical: 5),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? accent
                        : tab
                        ? glass.muted
                        : glass.foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerDrawerToggle extends StatelessWidget {
  const PlayerDrawerToggle({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180);
    void toggle() {
      selectionFeedback();
      onChanged(!value);
    }

    return Semantics(
      label: label,
      toggled: value,
      child: FocusableWrapper(
        disableScale: true,
        onSelect: toggle,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(9),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            canRequestFocus: false,
            onTap: toggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 42),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13))),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: duration,
                    width: 43,
                    height: 26,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: value
                            ? const [Color(0xff8173eb), Color(0xff6254c8)]
                            : dark
                            ? const [Color(0xff555462), Color(0xff3d3d49)]
                            : const [Color(0xffdedbe9), Color(0xffc6c2d5)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: value ? const Color(0x66cec5ff) : const Color(0x246f6983)),
                    ),
                    child: AnimatedAlign(
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Color(0xffe9e6f1)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .24),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const SizedBox.square(dimension: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerDrawerRange extends StatelessWidget {
  const PlayerDrawerRange({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.onChangeEnd,
  });
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final glass = GlassSheetColors.of(context);
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13);
    final range = FocusableSlider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: divisions,
      padding: EdgeInsets.zero,
      semanticFormatterCallback: (_) => valueText,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$label  $valueText', style: labelStyle),
                range,
              ],
            )
          : Row(
              children: [
                SizedBox(width: 64, child: Text(label, style: labelStyle, maxLines: 2)),
                const SizedBox(width: 10),
                Expanded(child: range),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    valueText,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, color: glass.muted),
                  ),
                ),
              ],
            ),
    );
  }
}

class PlayerDrawerStepper extends StatelessWidget {
  const PlayerDrawerStepper({
    super.key,
    required this.label,
    required this.valueText,
    required this.onDecrement,
    required this.onIncrement,
    this.onReset,
  });
  final String label;
  final String valueText;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final glass = GlassSheetColors.of(context);
    Widget button(IconData icon, String tooltip, VoidCallback action) => SizedBox.square(
      dimension: 26,
      child: IconButton(
        tooltip: tooltip,
        onPressed: action,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
        style: IconButton.styleFrom(backgroundColor: glass.foreground.withValues(alpha: .07)),
        icon: AppIcon(icon, size: 16, color: glass.foreground),
      ),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Symbols.remove_rounded, t.accessibility.decrease, onDecrement),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56),
          child: Text(
            valueText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        button(Symbols.add_rounded, t.accessibility.increase, onIncrement),
        if (onReset != null) ...[
          const SizedBox(width: 8),
          button(Symbols.restart_alt_rounded, t.common.reset, onReset!),
        ],
      ],
    );
    return FocusableWrapper(
      disableScale: true,
      onNavigateLeft: onDecrement,
      onNavigateRight: onIncrement,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 38),
        child: MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
                  controls,
                ],
              )
            : Row(
                children: [
                  Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13))),
                  controls,
                ],
              ),
      ),
    );
  }
}
