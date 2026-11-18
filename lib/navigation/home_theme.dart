import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/ambient_palette_extractor.dart';
import '../theme/mono_presentation.dart';
import '../theme/mono_tokens.dart';

typedef HomePaletteResolver = Future<Color> Function(ImageProvider image);

/// One selected media identity drives the home background and navigation.
/// The generation also isolates a late result after leaving/re-entering an item.
class HomeThemeController extends ChangeNotifier {
  HomeThemeController({HomePaletteResolver? resolve})
    : _resolve = resolve ?? ((image) => AmbientPaletteExtractor.extractFromImageProvider(image, matchLowerEdge: true));

  final HomePaletteResolver _resolve;
  final _palettes = <ImageProvider, Color>{};
  final _pendingPalettes = <ImageProvider, Future<Color>>{};
  String? _mediaKey;
  ImageProvider? _image;
  Color _color = AmbientPaletteExtractor.defaultFallback;
  int _generation = 0;
  bool _disposed = false;

  String? get mediaKey => _mediaKey;
  Color get color => _color;

  /// Resolve neighboring artwork while its page is idle. Selecting it later
  /// can start the page-color animation without another decode or sample.
  Future<void> precachePalette(ImageProvider image) async {
    await _paletteFor(image);
  }

  Future<Color> _paletteFor(ImageProvider image) {
    final cached = _palettes[image];
    if (cached != null) return Future.value(cached);
    return _pendingPalettes.putIfAbsent(image, () async {
      Color color;
      try {
        color = await _resolve(image);
      } catch (_) {
        color = AmbientPaletteExtractor.defaultFallback;
      }
      if (!_disposed) {
        // Bound the small palette cache to the same scale as the extractor.
        if (_palettes.length >= 128) _palettes.remove(_palettes.keys.first);
        _palettes[image] = color;
      }
      unawaited(_pendingPalettes.remove(image));
      return color;
    });
  }

  /// Retires the old picture's pending extraction before the new one decodes.
  void prepare(String mediaKey) {
    if (_mediaKey == mediaKey) return;
    _mediaKey = mediaKey;
    _image = null;
    _generation++;
  }

  Future<void> select(String? mediaKey, ImageProvider? image) async {
    if (_mediaKey == mediaKey && _image == image) return;
    _mediaKey = mediaKey;
    _image = image;
    final generation = ++_generation;
    // A pending picture must not briefly repaint the settled picture's page
    // with the fallback. Keep the last color until a new result is available.
    if (image == null) _color = AmbientPaletteExtractor.defaultFallback;
    notifyListeners();
    if (image == null) return;
    final color = _palettes[image] ?? await _paletteFor(image);
    if (_disposed || generation != _generation) return;
    _color = color;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _palettes.clear();
    _pendingPalettes.clear();
    super.dispose();
  }
}

class HomeThemeScope extends StatelessWidget {
  const HomeThemeScope({
    super.key,
    required this.controller,
    required this.child,
    this.active = true,
    this.fallbackColor,
  });

  final HomeThemeController controller;
  final Widget child;
  final bool active;
  final Color? fallbackColor;

  static HomeThemeController? read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<_HomeThemeData>()?.widget as _HomeThemeData?)?.controller;

  static Color colorOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HomeThemeData>()?.color ?? Theme.of(context).scaffoldBackgroundColor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    child: child,
    builder: (context, child) {
      final hasArtworkPalette = controller.color != AmbientPaletteExtractor.defaultFallback;
      final target = active && hasArtworkPalette
          ? MonoPresentation.artworkSurface(controller.color, Theme.of(context).brightness)
          : fallbackColor ?? Theme.of(context).scaffoldBackgroundColor;
      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(begin: target, end: target),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Theme.of(context).extension<MonoTokens>()?.slow ?? kThemeAnimationDuration,
        curve: Curves.easeOutCubic,
        child: child,
        builder: (context, color, child) =>
            _HomeThemeData(controller: controller, color: color ?? target, child: child!),
      );
    },
  );
}

class _HomeThemeData extends InheritedWidget {
  const _HomeThemeData({required this.controller, required this.color, required super.child});
  final HomeThemeController controller;
  final Color color;

  @override
  bool updateShouldNotify(_HomeThemeData oldWidget) => color != oldWidget.color || controller != oldWidget.controller;
}
