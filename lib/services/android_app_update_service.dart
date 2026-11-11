import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';
import '../utils/media_server_http_client.dart';

enum AndroidUpdateStatus { idle, downloading, ready, needsPermission, installing, error }

/// An APK selected from a release, with integrity data from its update manifest.
@immutable
class AndroidUpdateAsset {
  const AndroidUpdateAsset({
    required this.name,
    required this.url,
    required this.sha256Digest,
    required this.size,
    required this.version,
    required this.buildNumber,
  });

  final String name;
  final Uri url;
  final String sha256Digest;
  final int size;
  final String version;
  final int buildNumber;

  String get cacheKey => '$buildNumber-$sha256Digest';
}

/// Owns Android update downloads independently of any screen or dialog.
/// Installation always goes through Android's package installer, which performs
/// its own package, version and signature validation in the native channel.
class AndroidAppUpdateService extends ChangeNotifier {
  AndroidAppUpdateService({http.Client? client, MethodChannel? channel, Future<Directory> Function()? cacheDirectory})
    : _client = client ?? http.Client(),
      _channel = channel ?? const MethodChannel('com.wines.velo/app_update'),
      _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory;

  static final instance = AndroidAppUpdateService();

  // TODO(VELO-UPDATE-001): Tune network budgets after field testing on mobile networks.
  static const _requestTimeout = Duration(
    seconds: int.fromEnvironment('ANDROID_UPDATE_REQUEST_TIMEOUT_SECONDS', defaultValue: 30),
  );
  static const _downloadIdleTimeout = Duration(
    seconds: int.fromEnvironment('ANDROID_UPDATE_DOWNLOAD_IDLE_TIMEOUT_SECONDS', defaultValue: 60),
  );

  final http.Client _client;
  final MethodChannel _channel;
  final Future<Directory> Function() _cacheDirectory;
  AndroidUpdateStatus _status = AndroidUpdateStatus.idle;
  double? _progress;
  Object? _error;
  Map<String, dynamic>? _updateInfo;
  AndroidUpdateAsset? _asset;
  File? _apkFile;
  Future<void>? _downloadFuture;
  Future<bool>? _installFuture;
  bool _pendingPermission = false;
  bool _disposed = false;

  AndroidUpdateStatus get status => _status;
  double? get progress => _progress;
  Object? get error => _error;
  Map<String, dynamic>? get updateInfo => _updateInfo;
  bool get hasPendingPermission => _pendingPermission;

  /// Resolves metadata only from assets on the selected GitHub release.
  /// Version codes are authoritative for Android; semantic downgrades are also
  /// excluded. A missing or invalid manifest is a failed check, not "up to date".
  Future<Map<String, dynamic>?> resolveReleaseUpdate({
    required Map<String, dynamic> release,
    required PackageInfo packageInfo,
    required MediaServerHttpClient metadataClient,
    required String repository,
  }) async {
    if (release['draft'] == true || release['prerelease'] == true) return null;
    final device = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
    final installedBuild = device?['versionCode'];
    final installedPackage = device?['packageName'];
    if (installedBuild is! int || installedBuild <= 0 || installedPackage != packageInfo.packageName) {
      throw const FormatException('Invalid installed Android package metadata');
    }
    final releaseAssets = release['assets'];
    if (releaseAssets is! List) throw const FormatException('Release has no Android update assets');
    final tag = release['tag_name'];
    if (tag is! String) throw const FormatException('Android release has no tag');
    final manifestAsset = _findReleaseAsset(releaseAssets, 'velo-update.json');
    final manifestUrl = _assetUrl(manifestAsset, repository, 'velo-update.json', tag);
    final response = await metadataClient.get(manifestUrl.toString(), timeout: _requestTimeout);
    if (response.statusCode != 200) {
      throw StateError('Android update manifest returned HTTP ${response.statusCode}');
    }
    final manifest = response.data is String ? jsonDecode(response.data as String) : response.data;
    if (manifest is! Map<String, dynamic> || manifest['schemaVersion'] != 1) {
      throw const FormatException('Unsupported Android update manifest');
    }
    final version = manifest['version'];
    final build = manifest['buildNumber'];
    if (version is! String || !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) || build is! int || build <= 0) {
      throw const FormatException('Invalid Android release version');
    }
    if (manifest['packageName'] != installedPackage) {
      throw const FormatException('Android release package does not match this app');
    }
    if (tag != 'v$version' && tag != version && tag != 'v$version+$build' && tag != '$version+$build') {
      throw const FormatException('Android manifest version does not match release tag');
    }
    if (build <= installedBuild || _compareVersions(version, packageInfo.version) < 0) return null;

    final entries = manifest['assets'];
    if (entries is! List) throw const FormatException('Android update manifest has no APKs');
    final abis = device?['supportedAbis'];
    final supportedAbis = abis is List ? abis.whereType<String>().toList() : <String>[];
    Map<String, dynamic>? selected;
    for (final abi in ['universal', ...supportedAbis]) {
      final matches = entries.whereType<Map<String, dynamic>>().where((entry) => entry['abi'] == abi).toList();
      if (matches.length > 1) throw const FormatException('Ambiguous Android update asset');
      if (matches.isNotEmpty) {
        selected = matches.single;
        break;
      }
    }
    if (selected == null) throw const FormatException('No compatible Android update APK');
    final name = selected['name'];
    final digest = selected['sha256'];
    final size = selected['size'];
    if (name is! String ||
        !RegExp(r'^[A-Za-z0-9._-]+\.apk$').hasMatch(name) ||
        digest is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size is! int ||
        size <= 0) {
      throw const FormatException('Invalid Android APK integrity metadata');
    }
    final apkReleaseAsset = _findReleaseAsset(releaseAssets, name);
    if (apkReleaseAsset['size'] != size) throw const FormatException('Android APK size disagrees with release');
    final githubDigest = apkReleaseAsset['digest'];
    if (githubDigest != null && githubDigest != 'sha256:${digest.toLowerCase()}') {
      throw const FormatException('Android APK checksum disagrees with release');
    }
    final apk = AndroidUpdateAsset(
      name: name,
      url: _assetUrl(apkReleaseAsset, repository, name, tag),
      sha256Digest: digest.toLowerCase(),
      size: size,
      version: version,
      buildNumber: build,
    );
    return {
      'hasUpdate': true,
      'currentVersion': '${packageInfo.version}+$installedBuild',
      'latestVersion': '$version+$build',
      'currentBuildNumber': installedBuild,
      'latestBuildNumber': build,
      'releaseUrl': 'https://github.com/$repository/releases/tag/${Uri.encodeComponent(tag)}',
      'releaseName': release['name'] as String? ?? 'Version $version',
      'releaseNotes': release['body'] as String? ?? '',
      'publishedAt': release['published_at'] as String? ?? '',
      'androidAsset': apk,
    };
  }

  static Map<String, dynamic> _findReleaseAsset(List<dynamic> assets, String name) {
    final matches = assets.whereType<Map<String, dynamic>>().where((asset) => asset['name'] == name).toList();
    if (matches.length != 1) throw FormatException('Missing or ambiguous release asset: $name');
    return matches.single;
  }

  static Uri _assetUrl(Map<String, dynamic> asset, String repository, String name, String tag) {
    final value = asset['browser_download_url'];
    final url = value is String ? Uri.tryParse(value) : null;
    final repoParts = repository.split('/');
    if (repoParts.length != 2 ||
        url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        url.userInfo.isNotEmpty ||
        url.hasPort ||
        url.hasQuery ||
        url.hasFragment) {
      throw const FormatException('Invalid GitHub release asset URL');
    }
    final parts = url.pathSegments;
    if (parts.length != 6 ||
        parts[0] != repoParts[0] ||
        parts[1] != repoParts[1] ||
        parts[2] != 'releases' ||
        parts[3] != 'download' ||
        parts[4] != tag ||
        parts[5] != name) {
      throw const FormatException('APK must be an asset of this GitHub repository');
    }
    return url;
  }

  static int _compareVersions(String left, String right) {
    List<int> parts(String version) => version.split('+').first.split('-').first.split('.').map(int.parse).toList();
    final a = parts(left);
    final b = parts(right);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final comparison = (i < a.length ? a[i] : 0).compareTo(i < b.length ? b[i] : 0);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  Future<void> downloadUpdate(Map<String, dynamic> updateInfo) async {
    final asset = updateInfo['androidAsset'];
    if (asset is! AndroidUpdateAsset) {
      _fail(const FormatException('No verified Android update asset'));
      return;
    }
    final pending = _downloadFuture;
    if (pending != null) {
      await pending;
      if (_asset?.cacheKey != asset.cacheKey) await downloadUpdate(updateInfo);
      return;
    }
    // Assign the operation before notifying listeners, including reentrant UI
    // listeners that try to reopen the same update while downloading starts.
    final future = Future<void>.microtask(() => _download(updateInfo, asset));
    _downloadFuture = future;
    try {
      await future;
    } finally {
      _downloadFuture = null;
    }
  }

  Future<void> _download(Map<String, dynamic> info, AndroidUpdateAsset asset) async {
    _asset = asset;
    _updateInfo = Map.unmodifiable(info);
    _apkFile = null;
    _error = null;
    _progress = null;
    _pendingPermission = false;
    _status = AndroidUpdateStatus.downloading;
    _notify();
    File? partial;
    IOSink? sink;
    final aborted = Completer<void>();
    try {
      final root = await _cacheDirectory();
      final updates = await Directory('${root.path}/updates').create(recursive: true);
      final apk = File('${updates.path}/${asset.cacheKey}.apk');
      if (await _verify(apk, asset)) {
        _apkFile = apk;
        _progress = 1;
        _status = AndroidUpdateStatus.ready;
        _notify();
        return;
      }
      if (await apk.exists()) await apk.delete();
      partial = File('${apk.path}.part');
      if (await partial.exists()) await partial.delete();
      final request = http.AbortableRequest('GET', asset.url, abortTrigger: aborted.future);
      final response = await _client.send(request).timeout(_requestTimeout);
      if (response.statusCode != 200) throw HttpException('APK download returned HTTP ${response.statusCode}');
      if (response.contentLength != null && response.contentLength != asset.size) {
        throw const FormatException('APK response has an unexpected size');
      }
      sink = partial.openWrite();
      var received = 0;
      await sink.addStream(
        response.stream.timeout(_downloadIdleTimeout).map((bytes) {
          received += bytes.length;
          if (received > asset.size) throw const FormatException('APK exceeds its declared size');
          _progress = received / asset.size;
          _notify();
          return bytes;
        }),
      );
      await sink.flush();
      await sink.close();
      sink = null;
      if (received != asset.size || !await _verify(partial, asset)) {
        throw const FormatException('APK download failed its integrity check');
      }
      _apkFile = await partial.rename(apk.path);
      partial = null;
      _progress = 1;
      _status = AndroidUpdateStatus.ready;
      _notify();
    } catch (error, stackTrace) {
      if (!aborted.isCompleted) aborted.complete();
      try {
        await sink?.close();
      } catch (_) {
        // Preserve the original download error when storage also fails to close.
      }
      try {
        if (partial != null && await partial.exists()) await partial.delete();
      } catch (_) {
        // A leftover .part file is never considered installable and is retried.
      }
      appLogger.e('Android update download failed', error: error, stackTrace: stackTrace);
      _fail(error);
    }
  }

  Future<bool> _verify(File file, AndroidUpdateAsset asset) async {
    if (!await file.exists() || await file.length() != asset.size) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == asset.sha256Digest;
  }

  Future<bool> installUpdate({bool requestPermission = true}) async {
    final pending = _installFuture;
    if (pending != null) return pending;
    final future = _install(requestPermission: requestPermission);
    _installFuture = future;
    try {
      return await future;
    } finally {
      _installFuture = null;
    }
  }

  Future<bool> _install({required bool requestPermission}) async {
    try {
      final file = _apkFile;
      final asset = _asset;
      if (file == null || asset == null || !await _verify(file, asset)) {
        throw const FormatException('Downloaded APK is missing or failed verification');
      }
      _error = null;
      if (await _channel.invokeMethod<bool>('canInstallPackages') != true) {
        _status = AndroidUpdateStatus.needsPermission;
        _notify();
        if (requestPermission && !_pendingPermission) {
          _pendingPermission = true;
          if (await _channel.invokeMethod<bool>('openInstallPermissionSettings') != true) {
            _pendingPermission = false;
            throw StateError('Could not open Android install permission settings');
          }
        }
        return false;
      }
      _pendingPermission = false;
      if (await _channel.invokeMethod<bool>('installApk', {'path': file.path}) != true) {
        throw StateError('Could not open Android package installer');
      }
      _status = AndroidUpdateStatus.installing;
      _notify();
      return true;
    } catch (error, stackTrace) {
      _pendingPermission = false;
      if (error is PlatformException && error.code == 'ACTIVITY_NOT_RESUMED') {
        // Android rechecks visibility after APK parsing. Keep the verified APK
        // available when the user backgrounds or locks the device meanwhile.
        _error = null;
        _status = AndroidUpdateStatus.ready;
        _notify();
        return false;
      }
      appLogger.e('Android update installation could not start', error: error, stackTrace: stackTrace);
      _fail(error);
      return false;
    }
  }

  /// Resume only a permission request we initiated. Returning from the installer
  /// leaves the verified package ready for an explicit retry after cancellation.
  Future<void> resumePendingInstall() async {
    if (_pendingPermission) {
      _pendingPermission = false;
      await installUpdate(requestPermission: false);
    } else if (_status == AndroidUpdateStatus.installing) {
      _status = AndroidUpdateStatus.ready;
      _notify();
    }
  }

  void _fail(Object error) {
    _error = error;
    _status = AndroidUpdateStatus.error;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
