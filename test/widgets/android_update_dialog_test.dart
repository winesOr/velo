import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/services/android_app_update_service.dart';
import 'package:plezy/utils/update_dialog.dart';

final _updateInfo = <String, dynamic>{
  'hasUpdate': true,
  'currentVersion': '1.0.0+1',
  'latestVersion': '1.1.0+2',
  'releaseUrl': 'https://github.com/winesOr/velo/releases/tag/v1.1.0',
};

class _FakeUpdateService extends AndroidAppUpdateService {
  AndroidUpdateStatus _status = AndroidUpdateStatus.idle;
  Map<String, dynamic>? _info;
  Completer<void>? _download;
  bool _pendingPermission = false;
  bool permissionGranted = true;
  int downloads = 0;
  int installs = 0;
  int permissionRequests = 0;
  Completer<void>? installPreflight;
  int installerLaunches = 0;

  @override
  AndroidUpdateStatus get status => _status;

  @override
  Map<String, dynamic>? get updateInfo => _info;

  @override
  double? get progress => _status == AndroidUpdateStatus.downloading ? 0.5 : null;

  @override
  bool get hasPendingPermission => _pendingPermission;

  @override
  Future<void> downloadUpdate(Map<String, dynamic> updateInfo) {
    downloads++;
    _info = updateInfo;
    _status = AndroidUpdateStatus.downloading;
    _download = Completer<void>();
    notifyListeners();
    return _download!.future;
  }

  void completeDownload({bool fail = false}) {
    _status = fail ? AndroidUpdateStatus.error : AndroidUpdateStatus.ready;
    notifyListeners();
    _download!.complete();
  }

  @override
  Future<bool> installUpdate({bool requestPermission = true}) async {
    installs++;
    if (!permissionGranted) {
      _status = AndroidUpdateStatus.needsPermission;
      if (requestPermission) {
        permissionRequests++;
        _pendingPermission = true;
      }
      notifyListeners();
      return false;
    }
    if (installPreflight != null) await installPreflight!.future;
    installerLaunches++;
    _status = AndroidUpdateStatus.installing;
    notifyListeners();
    return true;
  }

  @override
  Future<void> resumePendingInstall() async {
    if (_pendingPermission) {
      _pendingPermission = false;
      if (permissionGranted) await installUpdate(requestPermission: false);
    } else if (_status == AndroidUpdateStatus.installing) {
      _status = AndroidUpdateStatus.ready;
      notifyListeners();
    }
  }
}

Future<void> _openDialog(WidgetTester tester, _FakeUpdateService service, {bool autoDownload = true}) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          hostContext = context;
          return const Scaffold();
        },
      ),
    ),
  );
  unawaited(
    showDialog<void>(
      context: hostContext,
      builder: (_) => AndroidUpdateDialog(
        updateInfo: _updateInfo,
        title: t.update.available,
        dismissLabel: t.common.later,
        autoDownload: autoDownload,
        service: service,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets('disabled automatic download waits for a manual action', (tester) async {
    final service = _FakeUpdateService();
    addTearDown(service.dispose);
    await _openDialog(tester, service, autoDownload: false);

    expect(service.downloads, 0);
    await tester.tap(find.text(t.update.download));
    await tester.pump();
    expect(service.downloads, 1);
    expect(find.text(t.update.downloadProgress(percent: '50')), findsOneWidget);

    service.completeDownload();
    await tester.pump();
    expect(service.installs, 1);
  });

  testWidgets('a download finishing in background installs only after resume', (tester) async {
    final service = _FakeUpdateService();
    addTearDown(service.dispose);
    await _openDialog(tester, service);
    expect(service.downloads, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    service.completeDownload();
    await tester.pump();
    expect(service.installs, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.installs, 1);
  });

  testWidgets('denied install permission does not repeatedly open settings', (tester) async {
    final service = _FakeUpdateService()..permissionGranted = false;
    addTearDown(service.dispose);
    await _openDialog(tester, service);
    service.completeDownload();
    await tester.pump();
    expect(service.permissionRequests, 0);
    expect(find.text(t.update.permissionRequired), findsOneWidget);

    await tester.tap(find.text(t.update.allowInstallation));
    await tester.pump();
    expect(service.permissionRequests, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.permissionRequests, 1);
    expect(service.installs, 2);
    expect(find.text(t.update.allowInstallation), findsOneWidget);
  });

  testWidgets('cancelling the Android installer requires an explicit retry', (tester) async {
    final service = _FakeUpdateService();
    addTearDown(service.dispose);
    await _openDialog(tester, service);
    service.completeDownload();
    await tester.pump();
    expect(service.installs, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.installs, 1);
    expect(find.text(t.update.readyToInstall), findsOneWidget);
    await tester.tap(find.text(t.update.installUpdate));
    await tester.pump();
    expect(service.installs, 2);
  });

  testWidgets('closing the dialog keeps download alive without opening an installer', (tester) async {
    final service = _FakeUpdateService();
    addTearDown(service.dispose);
    await _openDialog(tester, service);
    await tester.tap(find.text(t.common.later));
    await tester.pumpAndSettle();

    service.completeDownload();
    await tester.pump();
    expect(service.status, AndroidUpdateStatus.ready);
    expect(service.installs, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('installer preflight blocks close, barrier, back and escape until it finishes', (tester) async {
    final preflight = Completer<void>();
    final service = _FakeUpdateService()..installPreflight = preflight;
    addTearDown(service.dispose);
    await _openDialog(tester, service);
    service.completeDownload();
    await tester.pump();

    expect(find.text(t.update.preparingInstall), findsOneWidget);
    expect(service.installerLaunches, 0);
    await tester.tap(find.text(t.common.later));
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(AndroidUpdateDialog), findsOneWidget);
    expect(service.installerLaunches, 0);

    preflight.complete();
    await tester.pumpAndSettle();
    expect(service.installerLaunches, 1);
    await tester.tap(find.text(t.common.later));
    await tester.pumpAndSettle();
    expect(find.byType(AndroidUpdateDialog), findsNothing);
  });

  testWidgets('failed downloads offer retry instead of claiming an update was installed', (tester) async {
    final service = _FakeUpdateService();
    addTearDown(service.dispose);
    await _openDialog(tester, service);
    service.completeDownload(fail: true);
    await tester.pump();

    expect(find.text(t.update.updateFailed), findsOneWidget);
    expect(service.installs, 0);
    await tester.tap(find.text(t.common.retry));
    await tester.pump();
    expect(service.downloads, 2);
    service.completeDownload();
    await tester.pump();
    expect(service.installs, 1);
  });
}
