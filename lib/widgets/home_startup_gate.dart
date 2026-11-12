import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../profiles/active_profile_provider.dart';
import '../providers/discover_provider.dart';
import '../services/home_startup_timing.dart';
import '../utils/app_logger.dart';
import 'startup_loading_view.dart';

/// Prepare the session-owned home data before mounting the home. The same
/// provider survives the handoff, so mounting cannot restart the first fetch.
class HomeStartupGate extends StatefulWidget {
  const HomeStartupGate({
    super.key,
    required this.enabled,
    required this.child,
    this.initialContentBudget = const Duration(seconds: 2),
  });

  final bool enabled;
  final Widget child;
  // TODO(VELO-P4-01): Tune the injectable content budget on real devices.
  // This budget never applies to identity/PIN verification.
  final Duration initialContentBudget;

  @override
  State<HomeStartupGate> createState() => _HomeStartupGateState();
}

class _HomeStartupGateState extends State<HomeStartupGate> {
  bool _entered = false;
  bool _requested = false;
  bool _failed = false;
  bool _budgetExpired = false;
  Timer? _budget;
  bool _contentReported = false;

  @override
  void dispose() {
    _budget?.cancel();
    super.dispose();
  }

  Future<void> _prepare(DiscoverProvider discover) async {
    try {
      await discover.ensureLoaded();
    } catch (error, stackTrace) {
      appLogger.w('Initial home preparation failed', error: error, stackTrace: stackTrace);
      if (mounted) _failed = true;
    }
    if (mounted) setState(() => _requested = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final discover = context.watch<DiscoverProvider>();
    final profile = context.watch<ActiveProfileProvider?>();
    final binding = profile != null && profile.isBinding && !profile.isStartupIdentityReady;
    if (binding) {
      _budget?.cancel();
      _budget = null;
      _budgetExpired = false;
    } else if (!_entered && _budget == null) {
      final remaining = widget.initialContentBudget - (profile?.startupContentWaitElapsed ?? Duration.zero);
      if (remaining <= Duration.zero) {
        // The connection wait and content budget share one stopwatch. Once
        // identity is ready and that budget is already spent, enter during
        // this build instead of scheduling Timer.zero and waiting for a
        // second event-loop turn.
        _budgetExpired = true;
      } else {
        _budget = Timer(remaining, () {
          if (mounted) setState(() => _budgetExpired = true);
        });
      }
    }
    _entered =
        _entered ||
        (!binding &&
            (_failed ||
                _budgetExpired ||
                discover.hasDisplayableContent ||
                (!discover.isLoading && !discover.areHubsLoading)));
    if (_entered) {
      _budget?.cancel();
      if (!_contentReported && discover.hasDisplayableContent) {
        _contentReported = true;
        final fromSnapshot = discover.restoredHomeSnapshot;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) HomeStartupTiming.markContentVisible(fromSnapshot: fromSnapshot);
        });
      }
      return widget.child;
    }
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
