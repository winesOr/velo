import 'dart:convert';

import 'package:xml/xml.dart';

import 'danmaku_comment.dart';

/// Normalises Bilibili XML and dandanplay-compatible JSON into [DanmakuComment].
class DanmakuParser {
  static List<DanmakuComment> parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.startsWith('<')) return _parseXml(trimmed);
    return _parseJson(trimmed);
  }

  static List<DanmakuComment> _parseXml(String raw) {
    final document = XmlDocument.parse(raw);
    final comments = <DanmakuComment>[];
    for (final node in document.findAllElements('d')) {
      final text = node.innerText.trim();
      final parts = node.getAttribute('p')?.split(',') ?? const [];
      if (text.isEmpty || parts.isEmpty) continue;
      comments.add(
        DanmakuComment(
          timeMs: ((_double(parts, 0)) * 1000).round(),
          mode: _int(parts, 1, fallback: 1),
          color: _int(parts, 3),
          text: text,
        ),
      );
    }
    comments.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return comments;
  }

  static List<DanmakuComment> _parseJson(String raw) {
    final decoded = jsonDecode(raw);
    final rows = _rows(decoded);
    final comments = <DanmakuComment>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final text = (row['m'] ?? row['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      final p = row['p']?.toString();
      if (p != null && p.contains(',')) {
        final parts = p.split(',');
        comments.add(
          DanmakuComment(
            timeMs: ((_double(parts, 0)) * 1000).round(),
            mode: _int(parts, 1, fallback: 1),
            color: _int(parts, 2),
            text: text,
          ),
        );
        continue;
      }
      final time = row['time'] ?? row['progress'];
      final seconds = time is num ? time.toDouble() : double.tryParse('$time') ?? 0;
      comments.add(
        DanmakuComment(
          timeMs: (seconds > 100000 ? seconds : seconds * 1000).round(),
          mode: row['mode'] is num ? (row['mode'] as num).toInt() : 1,
          color: row['color'] is num ? (row['color'] as num).toInt() : 0xFFFFFF,
          text: text,
        ),
      );
    }
    comments.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return comments;
  }

  static List<dynamic> _rows(Object? decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in ['comments', 'data', 'danmaku']) {
        final value = decoded[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  static double _double(List<String> parts, int index) {
    if (index >= parts.length) return 0;
    return double.tryParse(parts[index]) ?? 0;
  }

  static int _int(List<String> parts, int index, {int fallback = 0}) {
    if (index >= parts.length) return fallback;
    return int.tryParse(parts[index]) ?? fallback;
  }
}
