import 'package:flutter/material.dart';

import '../focus/focusable_button.dart';
import '../i18n/strings.g.dart';

/// A server's failed home row, keeping its retry action in the row itself.
class HubRowError extends StatelessWidget {
  const HubRowError({
    super.key,
    required this.title,
    required this.onRetry,
    this.retrying = false,
    this.focusNode,
    this.onNavigateUp,
    this.onNavigateDown,
    this.height,
  });

  final String title;
  final VoidCallback onRetry;
  final bool retrying;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowHeight = height ?? ((MediaQuery.sizeOf(context).width < 600 ? 111.0 : 148.0) * 1.5 + 68);
    return SizedBox(
      height: rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            Text(t.errors.connectionFailed, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Semantics(
              label: t.common.retry,
              button: true,
              child: FocusableButton(
                focusNode: focusNode,
                onNavigateUp: onNavigateUp,
                onNavigateDown: onNavigateDown,
                onPressed: retrying ? () {} : onRetry,
                child: FilledButton.tonal(
                  onPressed: retrying ? null : onRetry,
                  child: retrying
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(t.common.retry),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
