import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

bool _previewFontsLoaded = false;

/// Loads local, licensed fonts for opt-in Flutter visual fixtures.
///
/// Roboto and Material Icons come from the active Flutter SDK's cached
/// material_fonts artifact, located through package_config rather than a
/// machine-specific path. CJK/Hangul and Material Symbols are the project's
/// existing bundled assets. No font is downloaded or copied into the repo.
/// Invoke from setUpAll or tester.runAsync so first-load asset and codec work
/// belongs to a live real-async zone rather than an individual fake clock.
Future<void> loadPreviewFonts() async {
  // Do not retain a Future created inside a testWidgets FakeAsync zone: the
  // next test must never schedule its continuation back into that old zone.
  if (_previewFontsLoaded) return;
  await _loadPreviewFonts();
  _previewFontsLoaded = true;
}

Future<void> _loadPreviewFonts() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final packages = (jsonDecode(config.readAsStringSync()) as Map<String, dynamic>)['packages'] as List<dynamic>;
  final flutter = packages.cast<Map<String, dynamic>>().singleWhere((entry) => entry['name'] == 'flutter');
  final flutterPackage = Directory.fromUri(config.uri.resolve(flutter['rootUri'] as String));
  final sdkFonts = Directory(
    path.join(flutterPackage.parent.parent.path, 'bin', 'cache', 'artifacts', 'material_fonts'),
  );

  Future<ByteData> sdkFont(String name) {
    final file = File(path.join(sdkFonts.path, name));
    if (!file.existsSync()) {
      throw StateError('Preview font is absent from the local Flutter SDK: ${file.path}');
    }
    return Future.value(ByteData.sublistView(file.readAsBytesSync()));
  }

  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Italic.ttf']) {
    roboto.addFont(sdkFont(name));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(sdkFont('MaterialIcons-Regular.otf'))).load();
  await (FontLoader('Go Noto Current')..addFont(rootBundle.load('assets/go-noto-current-regular.ttf'))).load();
  await (FontLoader('Go Noto Current Hangul')..addFont(rootBundle.load('assets/go-noto-kurrent-hangul.ttf'))).load();
  for (final shape in ['Outlined', 'Rounded', 'Sharp']) {
    final family = 'MaterialSymbols$shape';
    await (FontLoader(
      'packages/material_symbols_icons/$family',
    )..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/$family.ttf'))).load();
  }
}

/// Android/TV preview font model on the host renderer. Only family/fallbacks
/// change from Flutter test's Ahem default; product font sizes, weights,
/// spacing, line heights, colors, and component themes remain intact.
ThemeData previewFontTheme(ThemeData theme) {
  const fallback = ['Go Noto Current', 'Go Noto Current Hangul'];
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: fallback),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: fallback),
  );
}
