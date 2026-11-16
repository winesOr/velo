import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../profiles/active_profile_provider.dart';

import '../i18n/strings.g.dart';

import '../widgets/app_toast.dart';
import 'layout_constants.dart';

/// Supplies a scaled root context for global AppToast notifications.
final rootToastContextKey = GlobalKey();

enum SnackBarType { info, success, error }

AppToastHandle? showSnackBar(
  BuildContext context,
  String message, {
  SnackBarType type = SnackBarType.info,
  Duration? duration,
  bool? dismissible,
  String? actionLabel,
  VoidCallback? onAction,
  VoidCallback? onDismiss,
  VoidCallback? onExpire,
}) {
  if (!context.mounted) return null;
  return AppToast.show(
    context,
    message,
    type: switch (type) {
      SnackBarType.info => AppToastType.info,
      SnackBarType.success => AppToastType.success,
      SnackBarType.error => AppToastType.error,
    },
    duration: duration,
    dismissible: dismissible ?? true,
    actionLabel: actionLabel,
    onAction: onAction,
    onDismiss: onDismiss,
    onExpire: onExpire,
  );
}

void showAppSnackBar(BuildContext context, String message, {Duration? duration}) {
  showSnackBar(context, message, type: SnackBarType.info, duration: duration);
}

void showErrorSnackBar(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  showSnackBar(context, message, type: SnackBarType.error, actionLabel: actionLabel, onAction: onAction);
}

void showGlobalErrorSnackBar(String message) {
  final context = rootToastContextKey.currentContext;
  if (context != null) showErrorSnackBar(context, message);
}

void showMainSnackBar(String message, {Duration duration = AppDurations.snackBarDefault}) {
  final context = rootToastContextKey.currentContext;
  if (context != null) showAppSnackBar(context, message, duration: duration);
}

void showSuccessSnackBar(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  showSnackBar(context, message, type: SnackBarType.success, actionLabel: actionLabel, onAction: onAction);
}

/// Gives the user the toast's full (pause-aware) action window before a
/// destructive request starts. Other notices wait for this window; Undo cancels
/// it. Callers recheck their route/session before writing.
Future<bool> confirmUndoableAction(BuildContext context, String message) async {
  if (!context.mounted || Overlay.maybeOf(context, rootOverlay: true) == null) return false;
  final profiles = context.read<ActiveProfileProvider?>();
  final profileId = profiles?.activeId;
  final generation = profiles?.identityMutationGeneration;
  final result = Completer<bool>();
  AppToastHandle? handle;
  handle = showSnackBar(
    context,
    message,
    dismissible: false,
    actionLabel: t.common.undo,
    onAction: () {
      if (!result.isCompleted) result.complete(false);
      handle?.dismiss();
    },
    onExpire: () {
      if (!result.isCompleted) result.complete(true);
    },
    onDismiss: () {
      if (!result.isCompleted) result.complete(false);
    },
  );
  if (handle == null) result.complete(false);
  final confirmed = await result.future;
  return confirmed &&
      context.mounted &&
      profiles?.activeId == profileId &&
      profiles?.identityMutationGeneration == generation;
}
