import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Bounded artwork sampling for our content-derived surfaces.
///
/// Home can sample the artwork's lower edge without desaturating it, while
/// ambient backdrops retain their full-image palette and saturation control.
class AmbientPaletteExtractor {
  AmbientPaletteExtractor._();

  // Keyed by the provider itself: providers compare by value (URL, size), while
  // `toString()` is not unique — every `ResizeImage` prints `ResizeImage()`.
  // Map literals keep insertion order, so the first key is the least recent.
  static final Map<Object, Color> _cache = <Object, Color>{};
  static const int _maxCacheEntries = 128;

  /// Stable neutral fallback when no artwork can be sampled.
  static const Color defaultFallback = Color(0xFF16191D);

  /// A small decode of [image] for palette sampling.
  ///
  /// Artwork providers are usually already a [ResizeImage]; wrapping one in
  /// another trips its "cannot be composed" assertion and the decode fails,
  /// so the inner provider is resized instead.
  static ImageProvider samplingProvider(ImageProvider image, {int size = 32}) {
    final source = image is ResizeImage ? image.imageProvider : image;
    return ResizeImage.resizeIfNeeded(size, size, source);
  }

  /// 内存中根据已提取的 raw RGBA 字节流快速计算主色
  static Color extractFromRgbaBytes(
    Uint8List rgbaBytes,
    int width,
    int height, {
    Color fallback = defaultFallback,
    bool matchLowerEdge = false,
  }) {
    if (rgbaBytes.isEmpty || width <= 0 || height <= 0) return fallback;

    final totalPixels = width * height;
    final sampleStep = math.max(1, totalPixels ~/ 1024);

    final bottomStartPixel = matchLowerEdge ? (height * .85).floor() * width : 0;
    final bottomPixelCount = totalPixels - bottomStartPixel;
    final bottomStep = math.max(1, bottomPixelCount ~/ 1024);
    final bottom = _pickSamples(rgbaBytes, totalPixels, bottomStartPixel, bottomStep, bottomPixelCount);
    // Posters without useful color near the bottom (for example a black fade)
    // still get a stable, image-derived palette from the complete artwork.
    final picked = bottom.count * 3 >= ((bottomPixelCount + bottomStep - 1) ~/ bottomStep)
        ? bottom
        : _pickSamples(rgbaBytes, totalPixels, 0, sampleStep, totalPixels);
    final totalR = picked.r;
    final totalG = picked.g;
    final totalB = picked.b;
    final validPixels = picked.count;

    if (validPixels == 0) return fallback;

    final avgR = (totalR / validPixels).round();
    final avgG = (totalG / validPixels).round();
    final avgB = (totalB / validPixels).round();

    if (matchLowerEdge) return Color.fromARGB(255, avgR, avgG, avgB);

    final maximum = math.max(avgR, math.max(avgG, avgB));
    final minimum = math.min(avgR, math.min(avgG, avgB));
    final compression = maximum > 0 && (maximum - minimum) / maximum > .55 ? .22 : 0.0;
    final luminance = avgR * .2126 + avgG * .7152 + avgB * .0722;
    int channel(int value) => (value * (1 - compression) + luminance * compression).round().clamp(0, 255);
    return Color.fromARGB(255, channel(avgR), channel(avgG), channel(avgB));
  }

  static ({int r, int g, int b, int count}) _pickSamples(
    Uint8List rgbaBytes,
    int totalPixels,
    int startPixel,
    int sampleStep,
    int regionPixels,
  ) {
    final strict = _accumulate(rgbaBytes, totalPixels, startPixel, sampleStep, minBrightness: .12, minSaturation: .12);
    final sampled = (regionPixels + sampleStep - 1) ~/ sampleStep;
    if (strict.count * 33 >= sampled) return strict;
    return _accumulate(rgbaBytes, totalPixels, startPixel, sampleStep, minBrightness: .06, minSaturation: .05);
  }

  static ({int r, int g, int b, int count}) _accumulate(
    Uint8List rgbaBytes,
    int totalPixels,
    int startPixel,
    int sampleStep, {
    required double minBrightness,
    required double minSaturation,
  }) {
    var totalR = 0;
    var totalG = 0;
    var totalB = 0;
    var count = 0;
    final byteLength = rgbaBytes.length;
    for (int p = startPixel; p < totalPixels; p += sampleStep) {
      final idx = p * 4;
      if (idx + 3 >= byteLength) break;
      if (rgbaBytes[idx + 3] < 128) continue; // 忽略高透明像素

      final r = rgbaBytes[idx];
      final g = rgbaBytes[idx + 1];
      final b = rgbaBytes[idx + 2];
      final maxVal = math.max(r, math.max(g, b));
      final minVal = math.min(r, math.min(g, b));
      final saturation = maxVal == 0 ? 0.0 : (maxVal - minVal) / maxVal;
      final brightness = maxVal / 255.0;

      // 剔除过暗、灰阶，以及低饱和的泛白高光
      if (brightness < minBrightness || saturation < minSaturation) continue;
      if (saturation < .18 && brightness > .85) continue;
      totalR += r;
      totalG += g;
      totalB += b;
      count++;
    }
    return (r: totalR, g: totalG, b: totalB, count: count);
  }

  /// 从 [ui.Image] 异步解析主色
  static Future<Color> extractFromImage(
    ui.Image image, {
    Object? cacheKey,
    Color fallback = defaultFallback,
    bool matchLowerEdge = false,
  }) async {
    final effectiveKey = matchLowerEdge && cacheKey != null ? (cacheKey, matchLowerEdge) : cacheKey;
    final cached = effectiveKey == null ? null : _cacheHit(effectiveKey);
    if (cached != null) return cached;

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return fallback;

      final color = extractFromRgbaBytes(
        byteData.buffer.asUint8List(),
        image.width,
        image.height,
        fallback: fallback,
        matchLowerEdge: matchLowerEdge,
      );

      if (effectiveKey != null) {
        _setCache(effectiveKey, color);
      }
      return color;
    } catch (_) {
      return fallback;
    }
  }

  /// 从 [ImageProvider] 异步拉取并解析主色
  static Future<Color> extractFromImageProvider(
    ImageProvider provider, {
    Object? cacheKey,
    Color fallback = defaultFallback,
    bool matchLowerEdge = false,
    Locale? locale,
    Size? size,
  }) async {
    final key = cacheKey ?? provider;
    final cached = _cacheHit(matchLowerEdge ? (key, matchLowerEdge) : key);
    if (cached != null) return cached;

    final completer = Completer<Color>();
    final ImageStream stream = provider.resolve(ImageConfiguration(locale: locale, size: size));

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) async {
        stream.removeListener(listener);
        if (completer.isCompleted) {
          info.dispose();
          return;
        }
        final color = await extractFromImage(
          info.image,
          cacheKey: key,
          fallback: fallback,
          matchLowerEdge: matchLowerEdge,
        );
        info.dispose();
        if (!completer.isCompleted) completer.complete(color);
      },
      onError: (exception, stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(fallback);
      },
    );

    stream.addListener(listener);

    // 安全超时。调用方都在图片已显示后才取色，正常走缓存；1.5s 在真机冷启动
    // 时常被解码排队吃掉，导致整页退回默认灰。
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        stream.removeListener(listener);
        return fallback;
      },
    );
  }

  /// Returns a cached color and marks it most recently used.
  static Color? _cacheHit(Object key) {
    final color = _cache.remove(key);
    if (color != null) _cache[key] = color;
    return color;
  }

  static void _setCache(Object key, Color color) {
    _cache.remove(key);
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = color;
  }

  /// 清除缓存
  static void clearCache() => _cache.clear();
}
