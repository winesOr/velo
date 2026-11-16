import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../focus/focusable_wrapper.dart';
import '../i18n/strings.g.dart';
import '../theme/overlay_tokens.dart';
import 'app_glass_surface.dart';
import 'app_icon.dart';

/// Shared title-row close control, including keyboard/TV focus and a name.
class AppDialogCloseButton extends StatelessWidget {
  const AppDialogCloseButton({super.key, this.onPressed, this.focusNode, this.onNavigateDown, this.onBack});

  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateDown;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    void close() {
      if (onPressed != null) {
        onPressed!();
      } else {
        Navigator.of(context).maybePop();
      }
    }

    return FocusableWrapper(
      focusNode: focusNode,
      onSelect: close,
      onNavigateDown: onNavigateDown,
      onBack: onBack,
      disableScale: true,
      borderRadius: 15,
      descendantsAreFocusable: false,
      child: IconButton(
        onPressed: close,
        tooltip: t.common.close,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        padding: EdgeInsets.zero,
        iconSize: 18,
        style: IconButton.styleFrom(
          minimumSize: const Size(30, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: .07),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          shape: const CircleBorder(),
        ),
        icon: const AppIcon(Symbols.close_rounded, size: 18),
      ),
    );
  }
}

class AppDialogTitle extends StatelessWidget {
  const AppDialogTitle({super.key, required this.title, this.showCloseButton = true});

  final Widget title;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: title),
      if (showCloseButton) ...[const SizedBox(width: 12), const AppDialogCloseButton()],
    ],
  );
}

/// Material's sizing, keyboard avoidance and semantics with the shared glass
/// surface. Route ownership and focus remain the caller's responsibility.
class AppDialog extends Dialog {
  const AppDialog({
    super.key,
    super.backgroundColor,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.insetAnimationDuration,
    super.insetAnimationCurve,
    super.insetPadding,
    super.clipBehavior,
    super.shape,
    super.alignment,
    super.child,
    super.semanticsRole,
    super.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14)));
    final secondaryStyle = TextButton.styleFrom(
      shape: buttonShape,
      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: .07),
      foregroundColor: theme.colorScheme.onSurface,
      side: BorderSide(color: theme.colorScheme.outline),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetAnimationDuration: AppGlassSurface.reduceEffects(context) ? Duration.zero : insetAnimationDuration,
      insetAnimationCurve: insetAnimationCurve,
      insetPadding: insetPadding ?? const EdgeInsets.all(OverlayTokens.viewportInset),
      clipBehavior: Clip.none,
      shape: shape,
      alignment: alignment,
      constraints: constraints ?? const BoxConstraints(minWidth: 280, maxWidth: OverlayTokens.dialogMaxWidth),
      semanticsRole: semanticsRole,
      child: AppGlassSurface(
        backgroundColor: backgroundColor,
        shape: shape,
        child: Theme(
          data: theme.copyWith(
            filledButtonTheme: FilledButtonThemeData(
              style: theme.filledButtonTheme.style?.copyWith(shape: const WidgetStatePropertyAll(buttonShape)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: theme.elevatedButtonTheme.style?.copyWith(shape: const WidgetStatePropertyAll(buttonShape)),
            ),
            textButtonTheme: TextButtonThemeData(
              style: theme.textButtonTheme.style?.merge(secondaryStyle) ?? secondaryStyle,
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: theme.outlinedButtonTheme.style?.merge(secondaryStyle) ?? secondaryStyle,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Keeps Flutter's accessible alert layout and OverflowBar rather than
/// maintaining a second implementation of title/content/action sizing.
class AppAlertDialog extends AlertDialog {
  const AppAlertDialog({
    super.key,
    super.icon,
    super.iconPadding,
    super.iconColor,
    super.title,
    super.titlePadding,
    super.titleTextStyle,
    super.content,
    super.contentPadding,
    super.contentTextStyle,
    super.actions,
    super.actionsPadding,
    super.actionsAlignment,
    super.actionsOverflowAlignment,
    super.actionsOverflowDirection,
    super.actionsOverflowButtonSpacing,
    super.buttonPadding,
    super.backgroundColor,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.semanticLabel,
    super.insetPadding,
    super.clipBehavior,
    super.shape,
    super.alignment,
    super.constraints,
    super.scrollable,
    this.showCloseButton = true,
  });

  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    // AlertDialog builds a Dialog around its content. Reuse that layout and
    // replace only its surface, preserving its route announcement semantics.
    final dialog =
        AlertDialog(
              icon: icon,
              iconPadding: iconPadding,
              iconColor: iconColor,
              title: AppDialogTitle(title: title ?? const SizedBox.shrink(), showCloseButton: showCloseButton),
              titlePadding: titlePadding ?? const EdgeInsets.fromLTRB(20, 20, 20, 0),
              titleTextStyle: titleTextStyle,
              content: content,
              contentPadding: contentPadding ?? const EdgeInsets.fromLTRB(20, 16, 20, 20),
              contentTextStyle: contentTextStyle,
              actions: actions,
              actionsPadding: actionsPadding,
              actionsAlignment: actionsAlignment,
              actionsOverflowAlignment: actionsOverflowAlignment,
              actionsOverflowDirection: actionsOverflowDirection,
              actionsOverflowButtonSpacing: actionsOverflowButtonSpacing,
              buttonPadding: buttonPadding,
              backgroundColor: backgroundColor,
              elevation: elevation,
              shadowColor: shadowColor,
              surfaceTintColor: surfaceTintColor,
              semanticLabel: semanticLabel,
              insetPadding: insetPadding,
              clipBehavior: clipBehavior,
              shape: shape,
              alignment: alignment,
              constraints: constraints,
              scrollable: scrollable,
            ).build(context)
            as Dialog;
    return AppDialog(
      backgroundColor: backgroundColor,
      insetPadding: insetPadding,
      shape: shape,
      alignment: alignment,
      constraints: constraints,
      semanticsRole: dialog.semanticsRole,
      child: dialog.child,
    );
  }
}
