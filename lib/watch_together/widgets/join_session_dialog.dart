import 'package:flutter/material.dart';

import '../../widgets/app_dialog.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../focus/focusable_button.dart';
import '../../focus/focusable_text_field.dart';
import '../../focus/focusable_wrapper.dart';
import '../../i18n/strings.g.dart';
import '../../mixins/controller_disposer_mixin.dart';
import '../../utils/dialogs.dart';
import '../../widgets/app_icon.dart';
import '../services/relay_protocol.g.dart';

class JoinSessionDialog extends StatefulWidget {
  const JoinSessionDialog({super.key, this.onSubmit});

  /// A failed submission stays open; [error] is shown inline when present.
  final Future<({bool success, String? error})> Function(BuildContext context, String code)? onSubmit;

  @override
  State<JoinSessionDialog> createState() => _JoinSessionDialogState();
}

class _JoinSessionDialogState extends State<JoinSessionDialog> with ControllerDisposerMixin {
  final _formKey = GlobalKey<FormState>();
  late final _sessionIdController = createTextEditingController();
  final _closeFocusNode = FocusNode(debugLabel: 'JoinSessionClose');
  final _sessionIdFocusNode = FocusNode(debugLabel: 'JoinSessionCode');
  final _joinFocusNode = FocusNode(debugLabel: 'JoinSessionSubmit');
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _closeFocusNode.dispose();
    _sessionIdFocusNode.dispose();
    _joinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppDialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                Row(
                  children: [
                    AppIcon(Symbols.group_add_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t.watchTogether.joinWatchSession, style: theme.textTheme.titleLarge)),
                    FocusableWrapper(
                      focusNode: _closeFocusNode,
                      useBackgroundFocus: true,
                      disableScale: true,
                      borderRadius: 20,
                      descendantsAreFocusable: false,
                      onSelect: () => Navigator.of(context).pop(),
                      onNavigateDown: _sessionIdFocusNode.requestFocus,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const AppIcon(Symbols.close_rounded),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                FocusableTextFormField(
                  controller: _sessionIdController,
                  focusNode: _sessionIdFocusNode,
                  enabled: !_isSubmitting,
                  onChanged: (_) {
                    if (_submitError != null) setState(() => _submitError = null);
                  },
                  decoration: InputDecoration(
                    labelText: t.watchTogether.sessionCode,
                    hintText: t.watchTogether.enterCodeHint,
                    prefixIcon: const AppIcon(Symbols.tag_rounded),
                    suffixIcon: IconButton(
                      onPressed: _isSubmitting ? null : _pasteFromClipboard,
                      icon: const AppIcon(Symbols.content_paste_rounded),
                      tooltip: t.watchTogether.pasteFromClipboard,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: RelayProtocol.maxSessionIdLength,
                  inputFormatters: [UpperCaseTextFormatter()],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return t.watchTogether.pleaseEnterCode;
                    }
                    if (!RelayProtocol.isValidSessionId(value.trim().toUpperCase())) {
                      return t.watchTogether.sessionCodeInvalid;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _join(),
                  autofocus: true,
                ),

                if (_submitError case final error?)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                    ),
                  ),

                const SizedBox(height: 16),

                Text(
                  t.watchTogether.joinInstructions,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),

                const SizedBox(height: 24),

                FocusableButton(
                  focusNode: _joinFocusNode,
                  onPressed: _isSubmitting ? null : _join,
                  onNavigateUp: _sessionIdFocusNode.requestFocus,
                  useBackgroundFocus: true,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _join,
                    icon: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const AppIcon(Symbols.group_add_rounded),
                    label: Text(_isSubmitting ? t.watchTogether.joining : t.watchTogether.joinSession),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted && !_isSubmitting && data?.text != null) {
      // Preserve protocol characters; don't silently turn a different invitation
      // into a valid room by stripping punctuation or truncating it.
      final cleaned = data!.text!.trim().toUpperCase();
      if (cleaned.isNotEmpty) {
        _sessionIdController.text = cleaned;
        _sessionIdController.selection = TextSelection.collapsed(offset: _sessionIdController.text.length);
        if (_submitError != null) setState(() => _submitError = null);
      }
    }
  }

  Future<void> _join() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    final sessionId = _sessionIdController.text.trim().toUpperCase();
    final submit = widget.onSubmit;
    if (submit == null) {
      Navigator.of(context).pop(sessionId);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final result = await submit(context, sessionId);
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      if (result.success) {
        Navigator.of(context).pop(sessionId);
      } else {
        setState(() => _submitError = result.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

Future<String?> showJoinSessionDialog(
  BuildContext context, {
  Future<({bool success, String? error})> Function(BuildContext context, String code)? onSubmit,
}) {
  return showScopedDialog<String>(
    context: context,
    builder: (context) => JoinSessionDialog(onSubmit: onSubmit),
  );
}
