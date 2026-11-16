import 'package:flutter/material.dart';

import '../widgets/app_toast.dart';
import 'layout_constants.dart';

/// Supplies a scaled root context for global AppToast notifications.
final rootToastContextKey = GlobalKey();

enum SnackBarType { info, success, error }

void showSnackBar(
  BuildContext context,
  String message, {
  SnackBarType type = SnackBarType.info,
  Duration? duration,
  bool? dismissible,
}) {
  if (!context.mounted) return;
  AppToast.show(
    context,
    message,
    type: switch (type) {
      SnackBarType.info => AppToastType.info,
      SnackBarType.success => AppToastType.success,
      SnackBarType.error => AppToastType.error,
    },
    duration: duration,
    dismissible: dismissible ?? true,
  );
}

void showAppSnackBar(BuildContext context, String message, {Duration? duration}) {
  showSnackBar(context, message, type: SnackBarType.info, duration: duration);
}

void showErrorSnackBar(BuildContext context, String message) {
  showSnackBar(context, message, type: SnackBarType.error);
}

void showGlobalErrorSnackBar(String message) {
  final context = rootToastContextKey.currentContext;
  if (context != null) showErrorSnackBar(context, message);
}

void showMainSnackBar(String message, {Duration duration = AppDurations.snackBarDefault}) {
  final context = rootToastContextKey.currentContext;
  if (context != null) showAppSnackBar(context, message, duration: duration);
}

void showSuccessSnackBar(BuildContext context, String message) {
  showSnackBar(context, message, type: SnackBarType.success);
}
