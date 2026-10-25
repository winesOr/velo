import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../danmaku/danmaku_session.dart';
import '../../../danmaku/danmaku_source.dart';
import '../../../focus/focusable_button.dart';
import '../../../focus/focusable_text_field.dart';
import '../../../i18n/strings.g.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/focusable_list_tile.dart';
import 'base_video_control_sheet.dart';

/// Source management is also used by the first-use flow. Returning from an
/// empty editor never changes playback or removes locally imported comments.
class DanmakuSourcesSheet extends StatefulWidget {
  final DanmakuSession session;
  final VoidCallback onBack;
  final bool addOnOpen;

  const DanmakuSourcesSheet({super.key, required this.session, required this.onBack, this.addOnOpen = false});

  @override
  State<DanmakuSourcesSheet> createState() => _DanmakuSourcesSheetState();
}

class _DanmakuSourcesSheetState extends State<DanmakuSourcesSheet> {
  DanmakuSource? _editing;
  bool _editorOpen = false;
  bool _busy = false;
  String? _error;
  final Map<String, String> _testMessages = {};
  final Set<String> _testing = {};
  final Map<String, Object> _testRequests = {};

  @override
  void initState() {
    super.initState();
    _editorOpen = widget.addOnOpen;
    widget.session.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.session.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) setState(() => _error = t.danmaku.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _move(DanmakuSource source, int delta) async {
    final ids = widget.session.sources.map((source) => source.id).toList();
    final oldIndex = ids.indexOf(source.id);
    final nextIndex = oldIndex + delta;
    if (oldIndex < 0 || nextIndex < 0 || nextIndex >= ids.length) return;
    ids.removeAt(oldIndex);
    ids.insert(nextIndex, source.id);
    await _mutate(() => widget.session.reorderSources(ids));
  }

  Future<void> _test(DanmakuSource source) async {
    final request = Object();
    setState(() {
      _testing.add(source.id);
      _testRequests[source.id] = request;
      _testMessages.remove(source.id);
    });
    try {
      final result = await widget.session.testSource(source);
      if (!mounted || !identical(_testRequests[source.id], request)) return;
      setState(() {
        final elapsed = result.elapsed.inMilliseconds;
        _testMessages[source.id] = result.isSuccess
            ? t.danmaku.connectionSuccess(milliseconds: elapsed)
            : '${t.danmaku.connectionFailure(milliseconds: elapsed)} · ${danmakuFailureMessage(result.error)}';
      });
    } catch (_) {
      if (mounted && identical(_testRequests[source.id], request)) {
        setState(() => _testMessages[source.id] = t.danmaku.connectionFailure(milliseconds: 0));
      }
    } finally {
      if (mounted && identical(_testRequests[source.id], request)) {
        setState(() {
          _testing.remove(source.id);
          _testRequests.remove(source.id);
        });
      }
    }
  }

  Future<void> _delete(DanmakuSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.danmaku.deleteSourceTitle),
        content: Text(t.danmaku.deleteSourceDescription(name: source.name)),
        actions: [
          DanmakuActionButton(label: t.common.cancel, onPressed: () => Navigator.pop(context, false)),
          DanmakuActionButton(label: t.common.delete, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _mutate(() => widget.session.deleteSource(source.id));
  }

  void _closeEditor() {
    if (widget.addOnOpen && widget.session.sources.isEmpty) {
      widget.onBack();
    } else {
      setState(() => _editorOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editorOpen) {
      return DanmakuSourceEditor(
        key: ValueKey(_editing?.id ?? 'new-source'),
        session: widget.session,
        source: _editing,
        firstUse: widget.addOnOpen && widget.session.sources.isEmpty,
        onCancel: _closeEditor,
        onSaved: () {
          _testMessages.remove(_editing?.id);
          _testing.remove(_editing?.id);
          _testRequests.remove(_editing?.id);
          if (widget.addOnOpen) {
            widget.onBack();
          } else {
            setState(() => _editorOpen = false);
          }
        },
      );
    }
    final sources = widget.session.sources;
    return BaseVideoControlSheet(
      title: t.danmaku.sources,
      icon: Symbols.dns_rounded,
      onBack: widget.onBack,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(t.danmaku.sourceOrderDescription),
          const SizedBox(height: 8),
          DanmakuActionButton(
            label: t.danmaku.addSource,
            icon: Symbols.add_rounded,
            onPressed: _busy
                ? null
                : () => setState(() {
                    _editing = null;
                    _editorOpen = true;
                  }),
          ),
          if (_error != null) DanmakuErrorText(_error!),
          for (var index = 0; index < sources.length; index++) ...[
            const Divider(),
            FocusableSwitchListTile(
              key: ValueKey('enable-source-${sources[index].id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(sources[index].name),
              subtitle: Text(sources[index].enabled ? t.danmaku.sourceEnabled : t.danmaku.sourceDisabled),
              value: sources[index].enabled,
              onChanged: _busy
                  ? null
                  : (enabled) => _mutate(() => widget.session.saveSource(sources[index].copyWith(enabled: enabled))),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                DanmakuActionButton(
                  label: t.common.edit,
                  icon: Symbols.edit_rounded,
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _editing = sources[index];
                          _editorOpen = true;
                        }),
                ),
                DanmakuActionButton(
                  label: t.danmaku.moveUp,
                  icon: Symbols.arrow_upward_rounded,
                  onPressed: _busy || index == 0 ? null : () => _move(sources[index], -1),
                ),
                DanmakuActionButton(
                  label: t.danmaku.moveDown,
                  icon: Symbols.arrow_downward_rounded,
                  onPressed: _busy || index == sources.length - 1 ? null : () => _move(sources[index], 1),
                ),
                DanmakuActionButton(
                  label: _testing.contains(sources[index].id) ? t.danmaku.testing : t.danmaku.testConnection,
                  icon: Symbols.network_check_rounded,
                  onPressed: _busy || _testing.contains(sources[index].id) ? null : () => _test(sources[index]),
                ),
                DanmakuActionButton(
                  label: t.common.delete,
                  icon: Symbols.delete_rounded,
                  onPressed: _busy ? null : () => _delete(sources[index]),
                ),
              ],
            ),
            if (_testMessages[sources[index].id] case final message?)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(message)),
          ],
          const SizedBox(height: 12),
          Text(t.danmaku.connectionScope, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class DanmakuSourceEditor extends StatefulWidget {
  final DanmakuSession session;
  final DanmakuSource? source;
  final bool firstUse;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const DanmakuSourceEditor({
    super.key,
    required this.session,
    this.source,
    this.firstUse = false,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<DanmakuSourceEditor> createState() => _DanmakuSourceEditorState();
}

class _DanmakuSourceEditorState extends State<DanmakuSourceEditor> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  final _appId = TextEditingController();
  final _appSecret = TextEditingController();
  late bool _enabled;
  bool _saving = false;
  bool _hasCredentials = false;
  String? _error;

  bool get _official {
    try {
      return DanmakuEndpoint(_url.text).isOfficial;
    } on FormatException {
      return false;
    }
  }

  bool get _canKeepCredentials {
    if (!_hasCredentials || widget.source == null) return false;
    try {
      return DanmakuEndpoint(_url.text).baseUrl == DanmakuEndpoint(widget.source!.baseUrl).baseUrl;
    } on FormatException {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.source?.name ?? '');
    _url = TextEditingController(text: widget.source?.baseUrl ?? '');
    _enabled = widget.source?.enabled ?? true;
    _loadCredentialStatus();
  }

  Future<void> _loadCredentialStatus() async {
    final id = widget.source?.id;
    if (id == null) return;
    try {
      final exists = await widget.session.hasSourceCredentials(id);
      if (mounted) setState(() => _hasCredentials = exists);
    } catch (_) {
      // Saving still validates credentials without exposing vault errors.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _appId.dispose();
    _appSecret.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uri = Uri.tryParse(_url.text.trim());
    String? validation;
    if (_name.text.trim().isEmpty) {
      validation = t.danmaku.sourceNameRequired;
    } else if (uri == null ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      validation = t.danmaku.sourceUrlInvalid;
    } else if (_official &&
        ((!_canKeepCredentials && (_appId.text.trim().isEmpty || _appSecret.text.isEmpty)) ||
            (_appId.text.trim().isEmpty != _appSecret.text.isEmpty))) {
      validation = t.danmaku.credentialsRequired;
    }
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final source = DanmakuSource(
        id: widget.source?.id ?? 'source-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        baseUrl: _url.text.trim(),
        enabled: _enabled,
      );
      await widget.session.saveSource(
        source,
        appId: _official && _appId.text.trim().isNotEmpty ? _appId.text.trim() : null,
        appSecret: _official && _appSecret.text.isNotEmpty ? _appSecret.text : null,
      );
      if (mounted) widget.onSaved();
    } catch (_) {
      if (mounted) setState(() => _error = t.danmaku.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseVideoControlSheet(
      title: widget.firstUse
          ? t.danmaku.noSourcesTitle
          : (widget.source == null ? t.danmaku.addSource : t.danmaku.editSource),
      icon: Symbols.dns_rounded,
      onBack: _saving ? () {} : widget.onCancel,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (widget.firstUse) ...[Text(t.danmaku.noSourcesDescription), const SizedBox(height: 16)],
          FocusableTextField(
            key: const ValueKey('danmaku-source-name'),
            controller: _name,
            enabled: !_saving,
            decoration: InputDecoration(labelText: t.danmaku.sourceName, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FocusableTextField(
            key: const ValueKey('danmaku-source-url'),
            controller: _url,
            enabled: !_saving,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t.danmaku.sourceUrl,
              helperText: t.danmaku.sourceUrlHelp,
              helperMaxLines: 4,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_official) ...[
            const SizedBox(height: 16),
            Text(t.danmaku.officialCredentials, style: Theme.of(context).textTheme.titleMedium),
            Text(t.danmaku.officialCredentialsDescription),
            if (_canKeepCredentials) Text(t.danmaku.credentialsSaved),
            const SizedBox(height: 12),
            FocusableTextField(
              key: const ValueKey('danmaku-app-id'),
              controller: _appId,
              enabled: !_saving,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: t.danmaku.appId, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FocusableTextField(
              key: const ValueKey('danmaku-app-secret'),
              controller: _appSecret,
              enabled: !_saving,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: t.danmaku.appSecret, border: const OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 8),
          FocusableSwitchListTile(
            title: Text(t.danmaku.sourceEnabled),
            value: _enabled,
            onChanged: _saving ? null : (value) => setState(() => _enabled = value),
            contentPadding: EdgeInsets.zero,
          ),
          if (_error != null) DanmakuErrorText(_error!),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DanmakuActionButton(label: t.common.cancel, onPressed: _saving ? null : widget.onCancel),
              DanmakuActionButton(
                label: _saving ? t.common.loading : t.common.save,
                icon: Symbols.check_rounded,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DanmakuActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const DanmakuActionButton({super.key, required this.label, this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FocusableButton(
      onPressed: onPressed,
      child: icon == null
          ? TextButton(onPressed: onPressed, child: Text(label))
          : TextButton.icon(onPressed: onPressed, icon: AppIcon(icon), label: Text(label)),
    );
  }
}

class DanmakuErrorText extends StatelessWidget {
  final String message;

  const DanmakuErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  );
}

String danmakuFailureMessage(String? code) {
  final httpStatus = RegExp(r'http_error \((\d{3})\)').firstMatch(code ?? '');
  if (httpStatus != null) return t.danmaku.failureHttp(status: httpStatus.group(1)!);
  return switch (code) {
    'timeout' => t.danmaku.failureTimeout,
    'network_error' => t.danmaku.failureNetwork,
    'invalid_response' => t.danmaku.failureResponse,
    'credentials_required' => t.danmaku.failureCredentials,
    'invalid_redirect' => t.danmaku.failureRedirect,
    'no_candidates' => t.danmaku.failureEmpty,
    _ => t.danmaku.failureService,
  };
}
