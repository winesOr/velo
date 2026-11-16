/// Named endpoint metadata stored inside the owning connection's config JSON.
/// Authentication always remains on the connection, never on a route.
class ServerRoute {
  final String name;
  final String url;

  const ServerRoute({required this.name, required this.url});

  static bool validName(String value) => value.trim().isNotEmpty && value.trim().runes.length <= 40;

  static bool validPort(String value) =>
      RegExp(r'^[0-9]+$').hasMatch(value) && (int.tryParse(value) ?? 0) >= 1 && (int.tryParse(value) ?? 65536) <= 65535;

  static bool validAddress(String value) {
    if (!RegExp(r'^https?://(\[[0-9a-fA-F:.]+\]|[^/:?#@\s]+)\/?$').hasMatch(value.trim())) return false;
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.path.isEmpty || uri.path == '/') &&
        !RegExp(r'\s').hasMatch(value.trim());
  }

  factory ServerRoute.fromInput({required String name, required String address, required String port}) {
    if (!validName(name) || !validAddress(address) || !validPort(port.trim())) {
      throw const FormatException('Invalid server route');
    }
    final uri = Uri.parse(address.trim());
    return ServerRoute(
      name: name.trim(),
      url: Uri(scheme: uri.scheme, host: uri.host, port: int.parse(port.trim())).toString(),
    );
  }

  Map<String, Object?> toJson() => {'name': name, 'url': url};
}

class ServerRouteSettings {
  final List<ServerRoute> routes;

  /// A manual address; null uses [usePrimary] or the original candidates.
  final String? selectedUrl;
  final bool usePrimary;

  const ServerRouteSettings({this.routes = const [], this.selectedUrl, this.usePrimary = false});

  String? get effectiveUrl => selectedUrl ?? (usePrimary && routes.isNotEmpty ? routes.first.url : null);

  Map<String, Object?> toJson() => {
    'routes': routes.map((route) => route.toJson()).toList(),
    'selectedUrl': selectedUrl,
    'usePrimary': usePrimary,
  };

  static Map<String, ServerRouteSettings> readMap(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, ServerRouteSettings>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final value = entry.value as Map;
      final routes = <ServerRoute>[];
      if (value['routes'] case final List items) {
        for (final item in items) {
          if (item is! Map || item['name'] is! String || item['url'] is! String) continue;
          final url = Uri.tryParse(item['url'] as String);
          if (url == null || !url.hasAuthority || url.userInfo.isNotEmpty || !['http', 'https'].contains(url.scheme)) {
            continue;
          }
          routes.add(ServerRoute(name: item['name'] as String, url: item['url'] as String));
        }
      }
      final selected = value['selectedUrl'];
      result[entry.key as String] = ServerRouteSettings(
        routes: List.unmodifiable(routes),
        usePrimary: value['usePrimary'] == true,
        selectedUrl: selected is String && routes.any((r) => r.url == selected) ? selected : null,
      );
    }
    return Map.unmodifiable(result);
  }
}
