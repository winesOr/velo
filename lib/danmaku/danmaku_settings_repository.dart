import 'dart:convert';

import '../services/credential_vault.dart';
import '../services/settings_service.dart';
import 'danmaku_settings.dart';

/// One encrypted transaction keeps sources, private paths, credentials and memory
/// together. This resource is excluded from ordinary settings export/import.
class DanmakuSettingsRepository {
  static const storageKey = 'danmaku_settings_v1';
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final Future<String> Function(String) _protect;
  final Future<String?> Function(String) _reveal;
  bool recoveredCorruptData = false;

  DanmakuSettingsRepository({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    Future<String> Function(String)? protect,
    Future<String?> Function(String)? reveal,
  }) : _read = read ?? (() async => (await SettingsService.getInstance()).readNullableString(storageKey)),
       _write = write ?? ((value) async => (await SettingsService.getInstance()).writeString(storageKey, value)),
       _protect = protect ?? CredentialVault.protect,
       _reveal = reveal ?? CredentialVault.reveal;

  Future<DanmakuSettings> load() async {
    recoveredCorruptData = false;
    final stored = await _read();
    if (stored == null || stored.isEmpty) return const DanmakuSettings();
    try {
      final clear = await _reveal(stored);
      if (clear == null) throw const FormatException('lost_credentials');
      return DanmakuSettings.fromJson(jsonDecode(clear) as Map<String, dynamic>);
    } on FormatException {
      recoveredCorruptData = true;
    } on TypeError {
      recoveredCorruptData = true;
    }
    // Do not overwrite damaged data until the user explicitly saves new input.
    return const DanmakuSettings();
  }

  Future<void> save(DanmakuSettings settings) async {
    await _write(await _protect(jsonEncode(settings.toJson())));
    recoveredCorruptData = false;
  }
}
