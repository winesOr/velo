import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../profiles/active_profile_provider.dart';
import '../providers/discover_provider.dart';
import '../utils/app_logger.dart';
import 'startup_loading_view.dart';

/// Prepare the session-owned home data before mounting the home. The same
/// provider survives the handoff, so mounting cannot restart the first fetch.
class HomeStartupGate extends StatefulWidget {
  const HomeStartupGate({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<HomeStartupGate> createState() => _HomeStartupGateState();
}

class _HomeStartupGateState extends State<HomeStartupGate> {
  bool _entered = false;
  bool _requested = false;
  bool _failed = false;

  Future<void> _prepare(DiscoverProvider discover) async {
    try {
      await discover.ensureLoaded();
    } catch (error, stackTrace) {
      appLogger.w('Initial home preparation failed', error: error, stackTrace: stackTrace);
      _failed = true;
    }
    if (mounted) setState(() => _requested = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final discover = context.watch<DiscoverProvider>();
    final binding = context.watch<ActiveProfileProvider?>()?.isBinding ?? false;
    _entered = _entered || _failed || (!discover.isLoading && !discover.areHubsLoading);
    if (_entered) return widget.child;
    if (!_requested && !binding) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prepare(discover);
      });
    }
    return StartupLoadingView(
      status: Builder(
        builder: (context) =>
            Text(t.common.loading, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
