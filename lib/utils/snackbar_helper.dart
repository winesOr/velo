import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/overlay_tokens.dart';
import '../widgets/app_glass_surface.dart';
import '../widgets/app_icon.dart';

import '../navigation/profile_navigation_scope.dart';
import 'layout_constants.dart';
import 'platform_detector.dart';

/// Global key for the root ScaffoldMessenger, allowing snackbars to survive navigation.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Types of snackbars available in the app
enum SnackBarType { info, success, error }

const double _kDesktopSnackBarMaxWidth = OverlayTokens.notificationMaxWidth;
const double _kDesktopSnackBarHorizontalInset = 16.0;

/// Utility functions for showing snackbars throughout the application

SnackBar _buildSnackBar(
  BuildContext context,
  ScaffoldMessengerState messenger, {
  required Widget content,
  required SnackBarType type,
  required Duration duration,
  bool? dismissible,
}) {
  final isDesktop = PlatformDetector.isDesktopOS();
  final tapToDismiss = dismissible ?? isDesktop;
  final colors = Theme.of(context).colorScheme;
  final dark = colors.brightness == Brightness.dark;
  final (icon, accent) = switch (type) {
    SnackBarType.info => (Symbols.info_rounded, colors.primary),
    SnackBarType.success => (Symbols.check_circle_rounded, dark ? const Color(0xFF88D8B0) : const Color(0xFF216B4B)),
    SnackBarType.error => (Symbols.error_rounded, colors.error),
  };
  void dismiss() => messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
  final body = AppGlassSurface(
    radius: OverlayTokens.compactRadius,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppIcon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: (MediaQuery.maybeSizeOf(context)?.height ?? 640) * 0.3),
              child: SingleChildScrollView(
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: colors.onSurface, height: 1.4),
                  child: content,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return SnackBar(
    content: Semantics(
      onDismiss: tapToDismiss ? dismiss : null,
      child: tapToDismiss
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: dismiss, child: body),
            )
          : body,
    ),
    backgroundColor: Colors.transparent,
    elevation: 0,
    duration: duration,
    behavior: SnackBarBehavior.floating,
    width: isDesktop ? _desktopSnackBarWidth(context) : null,
    padding: EdgeInsets.zero,
    clipBehavior: Clip.none,
  );
}

double _desktopSnackBarWidth(BuildContext context) {
  final windowWidth = MediaQuery.maybeSizeOf(context)?.width;
  if (windowWidth == null) return _kDesktopSnackBarMaxWidth;

  final insetPadding = SnackBarTheme.of(context).insetPadding;
  final horizontalInset = insetPadding == null
      ? _kDesktopSnackBarHorizontalInset * 2
      : insetPadding.left + insetPadding.right;
  final availableWidth = windowWidth - horizontalInset;
  final width = availableWidth > 0 ? availableWidth : windowWidth;
  return width < _kDesktopSnackBarMaxWidth ? width : _kDesktopSnackBarMaxWidth;
}

Duration _snackBarDuration(SnackBarType type) => switch (type) {
  SnackBarType.info || SnackBarType.success => AppDurations.snackBarDefault,
  SnackBarType.error => AppDurations.snackBarLong,
};

void showSnackBar(
  BuildContext context,
  String message, {
  SnackBarType type = SnackBarType.info,
  Duration? duration,
  bool? dismissible,
}) {
  if (!context.mounted) return;

  final defaultDuration = _snackBarDuration(type);
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    _buildSnackBar(
      context,
      messenger,
      content: Text(message),
      type: type,
      duration: duration ?? defaultDuration,
      dismissible: dismissible,
    ),
  );
}

void showAppSnackBar(BuildContext context, String message, {Duration? duration}) {
  showSnackBar(context, message, type: SnackBarType.info, duration: duration);
}

void showErrorSnackBar(BuildContext context, String message) {
  showSnackBar(context, message, type: SnackBarType.error);
}

/// Shows an error snackbar using the root ScaffoldMessenger (survives navigation).
void showGlobalErrorSnackBar(String message) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.showSnackBar(
    _buildSnackBar(
      messenger.context,
      messenger,
      content: Text(message),
      type: SnackBarType.error,
      duration: AppDurations.snackBarLong,
    ),
  );
}

/// Shows an info snackbar through the main-screen messenger when available
/// (so it floats above the mobile NavigationBar), falling back to the root
/// messenger when the main screen is not mounted.
void showMainSnackBar(String message, {Duration duration = AppDurations.snackBarDefault}) {
  final messenger = profileNavigationRegistry.mainScaffoldMessenger ?? rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      _buildSnackBar(messenger.context, messenger, content: Text(message), type: SnackBarType.info, duration: duration),
    );
}

void showSuccessSnackBar(BuildContext context, String message) {
  showSnackBar(context, message, type: SnackBarType.success);
}
