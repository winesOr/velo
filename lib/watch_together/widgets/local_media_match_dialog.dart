import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../focus/focusable_button.dart';
import '../../focus/focusable_text_field.dart';
import '../../focus/focusable_wrapper.dart';
import '../../i18n/strings.g.dart';
import '../../media/ids.dart';
import '../../media/media_item.dart';
import '../../media/media_kind.dart';
import '../../media/media_version.dart';
import '../../providers/multi_server_provider.dart';
import '../../utils/dialogs.dart';
import '../../utils/media_server_http_client.dart';
import '../../utils/formatters.dart';
import '../../widgets/dialog_action_button.dart';
import '../../widgets/loading_indicator_box.dart';

class LocalMediaSelection {
  const LocalMediaSelection(this.item, this.version);
  final MediaItem item;
  final MediaVersion? version;
}

/// Explicit selection only: search results never become a match automatically.
class LocalMediaMatchDialog extends StatefulWidget {
  const LocalMediaMatchDialog({super.key, required this.hostTitle});
  final String hostTitle;

  @override
  State<LocalMediaMatchDialog> createState() => _LocalMediaMatchDialogState();
}

class _LocalMediaMatchDialogState extends State<LocalMediaMatchDialog> {
  late final _query = TextEditingController(text: widget.hostTitle);
  final _queryFocus = FocusNode(debugLabel: 'TogetherMatchQuery');
  final _searchFocus = FocusNode(debugLabel: 'TogetherMatchSearch');
  int _generation = 0;
  AbortController? _abort;
  bool _loading = false;
  bool _choosing = false;
  bool _searched = false;
  bool _failed = false;
  List<({MediaItem item, String serverName})> _results = const [];

  @override
  void dispose() {
    _generation++;
    _abort?.abort();
    _query.dispose();
    _queryFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty || _choosing) return;
    final generation = ++_generation;
    _abort?.abort();
    final abort = _abort = AbortController();
    final servers = context.read<MultiServerProvider?>();
    final clients = [
      for (final id in servers?.onlineServerIds ?? <String>[]) ?servers?.getClientForServer(ServerId(id)),
    ];
    setState(() {
      _loading = true;
      _searched = true;
      _failed = false;
      _results = const [];
    });
    var failed = false;
    final groups = await Future.wait(
      clients.map((client) async {
        try {
          final items = await client.searchItems(query, limit: 40, abort: abort);
          return [
            for (final item in items)
              if (item.kind == MediaKind.movie || item.kind == MediaKind.episode)
                (
                  item: item.copyWith(serverId: client.serverId),
                  serverName: client.serverName ?? client.serverId.toString(),
                ),
          ];
        } catch (_) {
          failed = true;
          return <({MediaItem item, String serverName})>[];
        }
      }),
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _results = groups.expand((group) => group).toList(growable: false);
      _failed = failed;
      _loading = false;
    });
  }

  Future<void> _choose(MediaItem candidate) async {
    if (_choosing) return;
    final generation = ++_generation;
    _abort?.abort();
    setState(() {
      _choosing = true;
      _loading = true;
    });
    try {
      final client = context.read<MultiServerProvider?>()?.getClientForServer(ServerId(candidate.serverId!));
      final full = await client?.fetchItem(candidate.id);
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      if (full == null || (full.kind != MediaKind.movie && full.kind != MediaKind.episode)) {
        setState(() => _failed = true);
        return;
      }
      final item = full.copyWith(serverId: candidate.serverId);
      final versions = item.mediaVersions?.where((version) => version.isPlayable).toList() ?? const <MediaVersion>[];
      if (versions.isEmpty && (item.mediaVersions?.isNotEmpty ?? false)) {
        setState(() => _failed = true);
        return;
      }
      MediaVersion? version;
      if (versions.length > 1) {
        version = await showScopedDialog<MediaVersion>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(t.watchTogether.localMatch),
            children: [
              for (final option in versions)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: FocusableButton(
                    onPressed: () => Navigator.pop(context, option),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, option),
                      child: Text(option.displayLabel),
                    ),
                  ),
                ),
            ],
          ),
        );
        if (version == null) return;
      } else if (versions.isNotEmpty) {
        version = versions.single;
      }
      if (!mounted || generation != _generation) return;
      final confirmed = await showConfirmDialog(
        context,
        title: t.watchTogether.confirmMatch,
        message:
            '${t.watchTogether.confirmMatchDescription}\n\n${_describe(item)}'
            '${version == null ? '' : '\n${version.displayLabel}'}',
        confirmText: t.watchTogether.useMatch,
      );
      if (!mounted || generation != _generation || !confirmed) return;
      Navigator.pop(context, LocalMediaSelection(item, version));
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _choosing = false;
          _loading = false;
        });
      }
    }
  }

  static String _describe(MediaItem item) => [
    item.displayTitle,
    if (item.kind == MediaKind.episode) 'S${item.parentIndex ?? "?"} · E${item.index ?? "?"}',
    ?item.displaySubtitle,
    if (item.year case final year?) '$year',
    if (item.durationMs case final duration?) formatDurationTextual(duration),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.watchTogether.changeMatch),
      scrollable: true,
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.watchTogether.matchInstructions),
            const SizedBox(height: 16),
            FocusableTextField(
              controller: _query,
              focusNode: _queryFocus,
              autofocus: true,
              decoration: InputDecoration(labelText: t.common.search),
              enabled: !_choosing,
              onSubmitted: (_) => _search(),
              onNavigateDown: _searchFocus.requestFocus,
              onChanged: (_) {
                // Typing invalidates an in-flight query even before Search is pressed.
                _generation++;
                _abort?.abort();
                if (_loading) setState(() => _loading = false);
              },
            ),
            FocusableButton(
              focusNode: _searchFocus,
              onPressed: _choosing ? null : _search,
              child: TextButton(onPressed: _choosing ? null : _search, child: Text(t.common.search)),
            ),
            if (_loading) const Center(child: LoadingIndicatorBox()),
            if (_failed) Text(t.watchTogether.matchSearchFailed),
            if (_searched && !_loading && _results.isEmpty) Text(t.watchTogether.noMatchingMedia),
            for (final result in _results)
              FocusableWrapper(
                descendantsAreFocusable: false,
                onSelect: _choosing ? null : () => _choose(result.item),
                child: ListTile(
                  title: Text(_describe(result.item)),
                  subtitle: Text(result.serverName),
                  onTap: _choosing ? null : () => _choose(result.item),
                ),
              ),
          ],
        ),
      ),
      actions: [DialogActionButton(onPressed: () => Navigator.pop(context), label: t.common.cancel)],
    );
  }
}
