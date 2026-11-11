import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plezy/services/android_app_update_service.dart';
import 'package:plezy/services/update_service.dart';
import 'package:plezy/utils/media_server_http_client.dart';

import '../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('velo.test/app_update');
  const apkName = 'velo-android-universal.apk';
  const downloadBase = 'https://github.com/winesOr/velo/releases/download/v1.0.0+2';
  final apkBytes = utf8.encode('test APK contents');
  final digest = sha256.convert(apkBytes).toString();
  late Directory cache;
  late AndroidAppUpdateService service;
  late Map<String, dynamic> manifest;
  late Map<String, dynamic> release;
  late List<MethodCall> calls;
  late List<Uri> requests;
  late bool canInstall;
  late List<int> downloadBytes;
  late http.Client client;
  Completer<void>? downloadGate;
  PlatformException? installError;

  setUp(() async {
    resetSharedPreferencesForTest();
    UpdateService.debugResetStartupCheck();
    PackageInfo.setMockInitialValues(
      appName: 'Velo',
      packageName: 'com.wines.velo',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    cache = await Directory.systemTemp.createTemp('velo-update-test-');
    calls = [];
    requests = [];
    canInstall = true;
    downloadBytes = apkBytes;
    downloadGate = null;
    installError = null;
    manifest = {
      'schemaVersion': 1,
      'version': '1.0.0',
      'buildNumber': 2,
      'packageName': 'com.wines.velo',
      'assets': [
        {'name': apkName, 'abi': 'universal', 'sha256': digest, 'size': apkBytes.length},
      ],
    };
    release = {
      'tag_name': 'v1.0.0+2',
      'assets': [
        {'name': 'velo-update.json', 'browser_download_url': '$downloadBase/velo-update.json'},
        {
          'name': apkName,
          'browser_download_url': '$downloadBase/$apkName',
          'size': apkBytes.length,
          'digest': 'sha256:$digest',
        },
      ],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getDeviceInfo' => {
          'packageName': 'com.wines.velo',
          'versionCode': 1,
          'supportedAbis': ['arm64-v8a'],
        },
        'canInstallPackages' => canInstall,
        'openInstallPermissionSettings' => true,
        'installApk' => installError == null ? true : throw installError!,
        _ => throw MissingPluginException(),
      };
    });
    client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.host == 'api.github.com') {
        return http.Response(jsonEncode(release), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path.endsWith('velo-update.json')) return http.Response(jsonEncode(manifest), 200);
      if (downloadGate != null) await downloadGate!.future;
      return http.Response.bytes(downloadBytes, 200);
    });
    service = AndroidAppUpdateService(client: client, channel: channel, cacheDirectory: () async => cache);
  });

  tearDown(() async {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await cache.delete(recursive: true);
  });

  Future<Map<String, dynamic>?> check({bool startup = false}) => UpdateService.debugPerformUpdateCheck(
    respectCooldown: startup,
    client: MediaServerHttpClient(client: client),
    isAndroid: true,
    androidService: service,
    throwOnFailure: true,
  );

  test('same semantic version with newer Android build selects verified Velo APK', () async {
    final info = await check();
    expect(requests.first.toString(), 'https://api.github.com/repos/winesOr/velo/releases/latest');
    expect(info?['latestVersion'], '1.0.0+2');
    expect(info?['currentVersion'], '1.0.0+1');
    expect(info?['androidAsset'], isA<AndroidUpdateAsset>());
  });

  test('Android startup interval defaults to checking on a fresh launch', () async {
    await check(startup: true);
    await check(startup: true);
    expect(requests.where((uri) => uri.host == 'api.github.com'), hasLength(2));
  });

  test('startup cache never replays a skipped update when the main screen is recreated', () async {
    Future<Map<String, dynamic>?> startup() => UpdateService.debugCheckForUpdatesOnStartup(
      client: MediaServerHttpClient(client: client),
      androidService: service,
    );
    final info = (await startup())!;
    await UpdateService.skipVersion(info['latestVersion'] as String);
    expect(await startup(), isNull);
    expect(requests.where((uri) => uri.host == 'api.github.com'), hasLength(1));
    expect(await check(), isNull, reason: 'the skipped build is also respected by manual checks');
  });

  test('a disposed startup caller cannot consume the live screen update result', () async {
    Future<Map<String, dynamic>?> startup() => UpdateService.debugCheckForUpdatesOnStartup(
      client: MediaServerHttpClient(client: client),
      androidService: service,
    );
    var firstScreenMounted = true;
    var firstScreenDisplayedUpdate = false;
    final disposedCaller = startup().then((info) {
      if (firstScreenMounted && info != null) firstScreenDisplayedUpdate = true;
    });
    // The first MainScreen is disposed while its request is still pending.
    firstScreenMounted = false;
    final liveCaller = startup();
    await disposedCaller;
    expect(firstScreenDisplayedUpdate, isFalse);
    expect(await liveCaller, isNotNull);
    expect(requests.where((uri) => uri.host == 'api.github.com'), hasLength(1));
    expect(await startup(), isNotNull);
    expect(await check(), isNotNull, reason: 'an explicit manual check remains available');
  });

  test('skipping one build does not suppress a later build of the same version', () async {
    await UpdateService.skipVersion('1.0.0+1');
    expect(await check(), isNotNull);
    await UpdateService.skipVersion('1.0.0+2');
    expect(await check(), isNull);
  });

  test('an existing or older build is not downloaded', () async {
    manifest['buildNumber'] = 1;
    release['tag_name'] = 'v1.0.0';
    for (final asset in release['assets'] as List) {
      asset['browser_download_url'] = 'https://github.com/winesOr/velo/releases/download/v1.0.0/${asset['name']}';
    }
    expect(await check(), isNull);
  });

  test('semantic downgrade is excluded even with a higher versionCode', () async {
    manifest['version'] = '0.9.0';
    release['tag_name'] = 'v0.9.0+2';
    for (final asset in release['assets'] as List) {
      asset['browser_download_url'] = 'https://github.com/winesOr/velo/releases/download/v0.9.0+2/${asset['name']}';
    }
    expect(await check(), isNull);
  });

  test('no public release is treated as no update', () async {
    final noRelease = MediaServerHttpClient(client: MockClient((_) async => http.Response('{}', 404)));
    addTearDown(noRelease.close);
    expect(
      await UpdateService.debugPerformUpdateCheck(
        respectCooldown: false,
        client: noRelease,
        isAndroid: true,
        androidService: service,
        throwOnFailure: true,
      ),
      isNull,
    );
  });

  final invalidManifests = <String, void Function(Map<String, dynamic>)>{
    'schema': (data) => data['schemaVersion'] = 2,
    'package': (data) => data['packageName'] = 'com.other.app',
    'build': (data) => data['buildNumber'] = '2',
    'version': (data) => data['version'] = '2.0.0',
    'checksum': (data) => (data['assets'] as List).single['sha256'] = 'invalid',
    'size': (data) => (data['assets'] as List).single['size'] = 999,
    'ABI': (data) => (data['assets'] as List).single['abi'] = 'x86',
  };
  for (final entry in invalidManifests.entries) {
    test('invalid ${entry.key} metadata fails the check instead of claiming latest', () async {
      entry.value(manifest);
      await expectLater(check(), throwsA(isA<FormatException>()));
    });
  }

  test('missing manifest fails the check instead of claiming latest', () async {
    (release['assets'] as List).removeAt(0);
    await expectLater(check(), throwsA(isA<FormatException>()));
  });

  test('APK asset URL cannot point outside the selected repository release', () async {
    (release['assets'] as List).last['browser_download_url'] =
        'https://github.com/other/other/releases/download/v1.0.0+2/$apkName';
    await expectLater(check(), throwsA(isA<FormatException>()));
  });

  test('download deduplicates concurrent requests and reuses a verified cached APK', () async {
    final info = (await check())!;
    downloadGate = Completer<void>();
    final first = service.downloadUpdate(info);
    final second = service.downloadUpdate(info);
    downloadGate!.complete();
    await Future.wait([first, second]);
    expect(service.status, AndroidUpdateStatus.ready);
    expect(service.progress, 1);
    expect(requests.where((uri) => uri.path.endsWith('.apk')), hasLength(1));
    await service.downloadUpdate(info);
    expect(service.status, AndroidUpdateStatus.ready);
    expect(requests.where((uri) => uri.path.endsWith('.apk')), hasLength(1));
    expect(await service.installUpdate(), isTrue);
    final path = (calls.last.arguments as Map)['path'] as String;
    expect(path, startsWith('${cache.path}/updates/'));
    expect(await File(path).readAsBytes(), apkBytes);
  });

  test('a corrupted cached package is downloaded and verified again', () async {
    final info = (await check())!;
    await service.downloadUpdate(info);
    final apk = (await Directory('${cache.path}/updates').list().toList()).whereType<File>().single;
    await apk.writeAsBytes(List.filled(apkBytes.length, 0));
    await service.downloadUpdate(info);
    expect(service.status, AndroidUpdateStatus.ready);
    expect(requests.where((uri) => uri.path.endsWith('.apk')), hasLength(2));
  });

  test('a new service instance verifies and reuses a previous launch download', () async {
    final info = (await check())!;
    await service.downloadUpdate(info);
    final nextLaunch = AndroidAppUpdateService(client: client, channel: channel, cacheDirectory: () async => cache);
    addTearDown(nextLaunch.dispose);
    await nextLaunch.downloadUpdate(info);
    expect(nextLaunch.status, AndroidUpdateStatus.ready);
    expect(requests.where((uri) => uri.path.endsWith('.apk')), hasLength(1));
  });

  test('cache storage failure becomes a retryable download error', () async {
    final info = (await check())!;
    final noStorage = AndroidAppUpdateService(
      client: client,
      channel: channel,
      cacheDirectory: () async => throw const FileSystemException('No writable cache'),
    );
    addTearDown(noStorage.dispose);
    await noStorage.downloadUpdate(info);
    expect(noStorage.status, AndroidUpdateStatus.error);
    expect(noStorage.error, isA<FileSystemException>());
    expect(calls.where((call) => call.method == 'installApk'), isEmpty);
  });

  for (final truncated in [false, true]) {
    test('${truncated ? 'truncated' : 'checksum mismatched'} download never becomes installable', () async {
      final info = (await check())!;
      downloadBytes = truncated ? apkBytes.sublist(1) : List.filled(apkBytes.length, 0);
      await service.downloadUpdate(info);
      expect(service.status, AndroidUpdateStatus.error);
      expect(await Directory('${cache.path}/updates').list().toList(), isEmpty);
      expect(await service.installUpdate(), isFalse);
      expect(calls.where((call) => call.method == 'installApk'), isEmpty);
    });
  }

  test('permission grant resumes installation once, cancellation permits explicit retry', () async {
    await service.downloadUpdate((await check())!);
    canInstall = false;
    expect(await service.installUpdate(), isFalse);
    expect(service.status, AndroidUpdateStatus.needsPermission);
    expect(service.hasPendingPermission, isTrue);
    canInstall = true;
    await service.resumePendingInstall();
    expect(service.status, AndroidUpdateStatus.installing);
    await service.resumePendingInstall();
    expect(service.status, AndroidUpdateStatus.ready);
    expect(calls.where((call) => call.method == 'installApk'), hasLength(1));
    expect(await service.installUpdate(), isTrue);
    expect(calls.where((call) => call.method == 'installApk'), hasLength(2));
  });

  test('permission rejection does not reopen settings or installer on resume', () async {
    await service.downloadUpdate((await check())!);
    canInstall = false;
    await service.installUpdate();
    await service.resumePendingInstall();
    await service.resumePendingInstall();
    expect(service.status, AndroidUpdateStatus.needsPermission);
    expect(service.hasPendingPermission, isFalse);
    expect(calls.where((call) => call.method == 'openInstallPermissionSettings'), hasLength(1));
    expect(calls.where((call) => call.method == 'installApk'), isEmpty);
  });

  test('native package validation failure remains an error, never installation success', () async {
    await service.downloadUpdate((await check())!);
    installError = PlatformException(code: 'SIGNATURE_MISMATCH');
    expect(await service.installUpdate(), isFalse);
    expect(service.status, AndroidUpdateStatus.error);
    expect(service.error, isA<PlatformException>());
  });

  test('losing the foreground during native APK validation preserves an explicit install retry', () async {
    await service.downloadUpdate((await check())!);
    installError = PlatformException(code: 'ACTIVITY_NOT_RESUMED');
    expect(await service.installUpdate(), isFalse);
    expect(service.status, AndroidUpdateStatus.ready);
    expect(service.error, isNull);
    await service.resumePendingInstall();
    expect(calls.where((call) => call.method == 'installApk'), hasLength(1));
    installError = null;
    expect(await service.installUpdate(), isTrue);
  });
}
