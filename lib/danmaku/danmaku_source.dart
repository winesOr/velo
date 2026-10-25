/// User-owned compatible service. Addresses can contain private path tokens.
class DanmakuSource {
  final String id;
  final String name;
  final String baseUrl;
  final bool enabled;

  const DanmakuSource({required this.id, required this.name, required this.baseUrl, this.enabled = true});

  DanmakuSource copyWith({String? name, String? baseUrl, bool? enabled}) => DanmakuSource(
    id: id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'baseUrl': baseUrl, 'enabled': enabled};

  factory DanmakuSource.fromJson(Map<String, dynamic> json) {
    final source = DanmakuSource(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: DanmakuEndpoint(json['baseUrl'] as String).baseUrl,
      enabled: json['enabled'] as bool? ?? true,
    );
    if (source.id.isEmpty || source.name.trim().isEmpty) throw const FormatException('invalid_source');
    return source;
  }

  @override
  String toString() => 'DanmakuSource($id)';
}

/// URI composition preserves every encoded path segment, including gateway tokens.
class DanmakuEndpoint {
  final Uri _base;

  DanmakuEndpoint(String value) : _base = _parse(value);

  static Uri _parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('invalid_endpoint');
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  String get baseUrl => _base.toString();
  bool get isOfficial => _base.scheme == 'https' && _base.host == 'api.dandanplay.net' && _base.port == 443;

  Uri route(String route, [Map<String, String> query = const {}]) {
    final prefix = _base.path.endsWith('/api/v2') ? _base.path : '${_base.path}/api/v2';
    return _base.replace(
      path: '$prefix/${route.replaceFirst(RegExp(r'^/+'), '')}',
      queryParameters: query.isEmpty ? null : query,
    );
  }
}

class DanmakuCredentials {
  final String appId;
  final String appSecret;
  const DanmakuCredentials({required this.appId, required this.appSecret});
  bool get isValid => appId.trim().isNotEmpty && appSecret.trim().isNotEmpty;
  Map<String, String> toJson() => {'appId': appId, 'appSecret': appSecret};
  factory DanmakuCredentials.fromJson(Map<String, dynamic> json) =>
      DanmakuCredentials(appId: json['appId'] as String, appSecret: json['appSecret'] as String);
  @override
  String toString() => 'DanmakuCredentials(<redacted>)';
}
