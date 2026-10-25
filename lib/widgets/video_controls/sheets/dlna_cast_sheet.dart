import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../focus/focusable_button.dart';
import '../../../i18n/strings.g.dart';
import '../../../services/casting/dlna_device.dart';
import '../../../services/casting/dlna_http.dart';
import '../../../services/casting/dlna_sender.dart';
import '../../app_icon.dart';
import '../../focusable_list_tile.dart';
import '../../overlay_sheet.dart';

/// This panel owns only discovery. The screen owns the finite handoff so that
/// rebuilding UI cannot cancel an accepted receiver command or send Stop.
class DlnaCastSheet extends StatefulWidget {
  const DlnaCastSheet({
    super.key,
    required this.discover,
    required this.onSend,
    required this.onClose,
    this.unavailableReason,
  });

  final Stream<List<DlnaDevice>> Function() discover;
  final Future<DlnaHandoffResult> Function(DlnaDevice device) onSend;
  final VoidCallback onClose;
  final String? unavailableReason;

  @override
  State<DlnaCastSheet> createState() => _DlnaCastSheetState();
}

class _DlnaCastSheetState extends State<DlnaCastSheet> {
  StreamSubscription<List<DlnaDevice>>? _scan;
  List<DlnaDevice> _devices = const [];
  bool _scanning = false;
  bool _busy = false;
  String? _error;
  int _scanGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.unavailableReason == null) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_busy) return;
    final generation = ++_scanGeneration;
    unawaited(_scan?.cancel());
    _scan = null;
    if (!mounted || generation != _scanGeneration) return;
    setState(() {
      _scanning = true;
      _devices = const [];
      _error = null;
    });
    _scan = widget.discover().listen(
      (devices) {
        if (mounted && generation == _scanGeneration) setState(() => _devices = devices);
      },
      onError: (Object error) {
        if (mounted && generation == _scanGeneration) setState(() => _error = t.casting.discoveryFailed);
      },
      onDone: () {
        if (mounted && generation == _scanGeneration) setState(() => _scanning = false);
      },
    );
  }

  Future<void> _send(DlnaDevice device) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      ++_scanGeneration;
      // Cancellation stops delivery immediately. Socket/lease cleanup may
      // finish asynchronously and must not hold the one-shot send open.
      unawaited(_scan?.cancel());
      _scan = null;
      await widget.onSend(device);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            DlnaException(failure: DlnaFailure.unsupportedSource) => t.casting.unsupportedSource,
            DlnaException(mayBePlaying: true) => t.casting.checkTv,
            _ => t.casting.sendFailed,
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _scanning = false;
        });
      }
    }
  }

  @override
  void dispose() {
    ++_scanGeneration;
    unawaited(_scan?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = GlassSheetColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIcon(Symbols.cast_rounded, size: 22, color: colors.foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.videoControls.castUnavailableTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              FocusableButton(
                onPressed: _busy ? null : widget.onClose,
                child: IconButton(
                  onPressed: _busy ? null : widget.onClose,
                  tooltip: t.common.close,
                  icon: const AppIcon(Symbols.close_rounded, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.unavailableReason ?? t.casting.description, style: TextStyle(color: colors.muted, fontSize: 13)),
          if (widget.unavailableReason == null) ...[
            const SizedBox(height: 12),
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(t.casting.sending, style: TextStyle(color: colors.foreground)),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (!_busy && _scanning && _devices.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(t.casting.searching)),
            if (!_busy && !_scanning && _devices.isEmpty && _error == null)
              Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(t.casting.noDevices)),
            if (!_busy)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  itemBuilder: (_, index) {
                    final device = _devices[index];
                    return FocusableListTile(
                      key: ValueKey(device.id),
                      leading: const AppIcon(Symbols.tv_rounded, size: 24),
                      title: Text(device.name),
                      subtitle: Text(t.casting.deviceType),
                      onTap: () => unawaited(_send(device)),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Text(t.casting.limitations, style: TextStyle(color: colors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            FocusableButton(
              onPressed: _busy || _scanning ? null : () => unawaited(_refresh()),
              child: OutlinedButton.icon(
                onPressed: _busy || _scanning ? null : () => unawaited(_refresh()),
                icon: const AppIcon(Symbols.refresh_rounded, size: 18),
                label: Text(t.casting.refresh),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
