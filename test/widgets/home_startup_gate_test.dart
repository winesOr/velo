import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/providers/discover_provider.dart';
import 'package:plezy/profiles/active_profile_provider.dart';
import 'package:plezy/widgets/home_startup_gate.dart';
import 'package:plezy/widgets/startup_loading_view.dart';
import 'package:provider/provider.dart';

class _HomeData extends ChangeNotifier implements DiscoverProvider {
  final pending = Completer<void>();
  int fetches = 0;
  @override
  Future<void> ensureLoaded() {
    fetches++;
    return pending.future;
  }

  @override
  bool isLoading = true;
  @override
  bool areHubsLoading = true;
  @override
  String? errorMessage;
  @override
  bool hasDisplayableContent = false;
  @override
  bool restoredHomeSnapshot = false;

  void update({required bool onDeck, required bool hubs, String? error, bool content = false}) {
    isLoading = onDeck;
    areHubsLoading = hubs;
    errorMessage = error;
    hasDisplayableContent = content;
    if (!onDeck && !hubs && !pending.isCompleted) pending.complete();
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileData extends ChangeNotifier implements ActiveProfileProvider {
  @override
  bool isBinding = true;
  @override
  bool isStartupIdentityReady = false;
  @override
  Duration startupContentWaitElapsed = Duration.zero;
  void authorize() {
    isStartupIdentityReady = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeProbe extends StatefulWidget {
  const _HomeProbe({required this.onMount});
  final VoidCallback onMount;
  @override
  State<_HomeProbe> createState() => _HomeProbeState();
}

class _HomeProbeState extends State<_HomeProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Home content'));
}

void main() {
  testWidgets('home mounts on first usable leg and does not repeat preparation', (tester) async {
    final data = _HomeData();
    addTearDown(data.dispose);
    var mounts = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<DiscoverProvider>.value(
        value: data,
        child: MaterialApp(
          builder: (_, child) => MediaQuery(data: const MediaQueryData(disableAnimations: true), child: child!),
          home: HomeStartupGate(enabled: true, child: _HomeProbe(onMount: () => mounts++)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(mounts, 0);
    expect(data.fetches, 1);
    expect(find.byType(StartupLoadingView), findsOneWidget);
    expect(find.text('Home content').hitTestable(), findsNothing);
    data.update(onDeck: false, hubs: true, content: true);
    await tester.pump();
    expect(find.text('Home content').hitTestable(), findsOneWidget);
    data.update(onDeck: false, hubs: false);
    await tester.pumpAndSettle();
    expect(find.text('Home content').hitTestable(), findsOneWidget);
    expect(find.byType(StartupLoadingView), findsNothing);
    expect(mounts, 1, reason: 'uncovering must not restart MainScreen initialization');
    data.update(onDeck: true, hubs: true);
    await tester.pump();
    expect(find.byType(StartupLoadingView), findsNothing, reason: 'later refreshes remain in-page');
    expect(mounts, 1);
  });

  testWidgets('content budget never bypasses an identity/PIN gate', (tester) async {
    final data = _HomeData();
    final profile = _ProfileData();
    addTearDown(data.dispose);
    addTearDown(profile.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DiscoverProvider>.value(value: data),
          ChangeNotifierProvider<ActiveProfileProvider>.value(value: profile),
        ],
        child: const MaterialApp(
          home: HomeStartupGate(
            enabled: true,
            initialContentBudget: Duration(milliseconds: 200),
            child: Text('Authorized shell'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Authorized shell'), findsNothing);
    expect(data.fetches, 0);
    profile.authorize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 199));
    expect(find.text('Authorized shell'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Authorized shell'), findsOneWidget);
    expect(data.fetches, 1);
    data.pending.complete();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('content budget is shared with the connection wait rather than restarted', (tester) async {
    final data = _HomeData();
    final profile = _ProfileData()
      ..isStartupIdentityReady = true
      ..startupContentWaitElapsed = const Duration(seconds: 2);
    addTearDown(data.dispose);
    addTearDown(profile.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DiscoverProvider>.value(value: data),
          ChangeNotifierProvider<ActiveProfileProvider>.value(value: profile),
        ],
        child: const MaterialApp(home: HomeStartupGate(enabled: true, child: Text('Usable shell'))),
      ),
    );
    await tester.pump();
    expect(find.text('Usable shell'), findsOneWidget);
    data.pending.complete();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed or empty initial results release startup to the usable home', (tester) async {
    final data = _HomeData()..update(onDeck: false, hubs: false, error: 'unavailable');
    addTearDown(data.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<DiscoverProvider>.value(
        value: data,
        child: const MaterialApp(
          home: HomeStartupGate(enabled: true, child: Scaffold(body: Text('Retry from home'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry from home').hitTestable(), findsOneWidget);
    expect(find.byType(StartupLoadingView), findsNothing);
  });

  testWidgets('offline or another startup destination bypasses home preparation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeStartupGate(enabled: false, child: Scaffold(body: Text('Downloads'))),
      ),
    );
    expect(find.text('Downloads').hitTestable(), findsOneWidget);
    expect(find.byType(StartupLoadingView), findsNothing);
  });
}
