import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../focus/focusable_button.dart';
import '../../i18n/strings.g.dart';
import '../../widgets/app_icon.dart';
import '../libraries/state_messages.dart';

/// A load error that remains readable at large text sizes. Refresh failures
/// keep their existing content below a naturally sized, scrollable notice.
class LiveTvLoadError extends StatelessWidget {
  const LiveTvLoadError({
    super.key,
    required this.message,
    required this.onRetry,
    this.focusNode,
    this.autofocus = false,
    this.onNavigateUp,
    this.onNavigateDown,
    this.onBack,
    this.content,
  });

  final String? message;
  final VoidCallback onRetry;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final VoidCallback? onBack;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    final content = this.content;
    if (content == null) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0),
            child: ErrorStateWidget(
              message: message!,
              onRetry: onRetry,
              actionFocusNode: focusNode,
              actionAutofocus: autofocus,
              onActionNavigateUp: onNavigateUp,
              onActionBack: onBack,
            ),
          ),
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (message != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight / 2),
              child: SingleChildScrollView(
                child: Material(
                  color: colors.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              message!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onErrorContainer),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FocusableButton(
                          focusNode: focusNode,
                          autofocus: autofocus,
                          onPressed: onRetry,
                          onNavigateUp: onNavigateUp,
                          onNavigateDown: onNavigateDown,
                          onBack: onBack,
                          child: IconButton(
                            tooltip: t.common.retry,
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            onPressed: onRetry,
                            icon: AppIcon(Symbols.refresh_rounded, color: colors.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(key: const ValueKey('live-tv-retained-content'), child: content),
        ],
      ),
    );
  }
}
