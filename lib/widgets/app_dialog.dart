import 'package:flutter/material.dart';

import '../theme/overlay_tokens.dart';
import 'app_glass_surface.dart';

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
  Widget build(BuildContext context) => Dialog(
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
    child: AppGlassSurface(backgroundColor: backgroundColor, shape: shape, child: child ?? const SizedBox.shrink()),
  );
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
  });

  @override
  Widget build(BuildContext context) {
    // AlertDialog builds a Dialog around its content. Reuse that layout and
    // replace only its surface, preserving its route announcement semantics.
    final dialog = super.build(context) as Dialog;
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
