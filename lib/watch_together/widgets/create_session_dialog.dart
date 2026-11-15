import 'package:flutter/material.dart';

import '../../focus/focusable_button.dart';
import '../../focus/focusable_text_field.dart';
import '../../i18n/strings.g.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/dialog_action_button.dart';
import '../models/watch_session.dart';

class CreateSessionDialog extends StatefulWidget {
  const CreateSessionDialog({super.key, required this.onSubmit});

  final Future<({bool success, String? error})> Function(BuildContext context, String? name, ControlMode controlMode)
  onSubmit;

  @override
  State<CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<CreateSessionDialog> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode(debugLabel: 'CreateSessionName');
  final _hostFocus = FocusNode(debugLabel: 'CreateSessionHostOnly');
  final _anyoneFocus = FocusNode(debugLabel: 'CreateSessionAnyone');
  final _cancelFocus = FocusNode(debugLabel: 'CreateSessionCancel');
  final _submitFocus = FocusNode(debugLabel: 'CreateSessionSubmit');
  ControlMode _mode = ControlMode.hostOnly;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _hostFocus.dispose();
    _anyoneFocus.dispose();
    _cancelFocus.dispose();
    _submitFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(context, name.isEmpty ? null : name, _mode);
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      if (result.success) {
        Navigator.of(context).pop();
      } else {
        setState(() => _error = result.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _modeOption(ControlMode value, String label, FocusNode node, FocusNode other) {
    return FocusableButton(
      focusNode: node,
      onPressed: _busy ? null : () => setState(() => _mode = value),
      onNavigateUp: _nameFocus.requestFocus,
      onNavigateDown: _cancelFocus.requestFocus,
      onNavigateLeft: other.requestFocus,
      onNavigateRight: other.requestFocus,
      child: ChoiceChip(
        selected: _mode == value,
        label: Text(label),
        onSelected: _busy ? null : (_) => setState(() => _mode = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      scrollable: true,
      title: Text(t.watchTogether.createSession),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.watchTogether.createRoomHostDescription),
          const SizedBox(height: 16),
          FocusableTextField(
            controller: _name,
            focusNode: _nameFocus,
            enabled: !_busy,
            autofocus: true,
            decoration: InputDecoration(labelText: t.watchTogether.optionalRoomName),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onNavigateDown: _hostFocus.requestFocus,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Text(t.watchTogether.controlModeQuestion),
          Wrap(
            spacing: 8,
            children: [
              _modeOption(ControlMode.hostOnly, t.watchTogether.hostOnly, _hostFocus, _anyoneFocus),
              _modeOption(ControlMode.anyone, t.watchTogether.anyone, _anyoneFocus, _hostFocus),
            ],
          ),
          if (_error case final error?)
            Semantics(
              liveRegion: true,
              child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        DialogActionButton(
          focusNode: _cancelFocus,
          onPressed: () => Navigator.of(context).pop(),
          onNavigateUp: _anyoneFocus.requestFocus,
          onNavigateRight: _submitFocus.requestFocus,
          label: t.common.cancel,
        ),
        DialogActionButton(
          focusNode: _submitFocus,
          onPressed: _busy ? null : _submit,
          onNavigateLeft: _cancelFocus.requestFocus,
          label: _busy ? t.watchTogether.creating : t.watchTogether.createSession,
          isPrimary: true,
        ),
      ],
    );
  }
}
