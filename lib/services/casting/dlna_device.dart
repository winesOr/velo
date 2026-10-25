import 'package:xml/xml.dart';

/// One AVTransport endpoint. Descriptions may use a URLBase and any service version.
class DlnaDevice {
  const DlnaDevice({required this.id, required this.name, required this.controlUrl, required this.serviceType});

  final String id;
  final String name;
  final Uri controlUrl;
  final String serviceType;

  static DlnaDevice? fromDescription(String source, Uri location) {
    final document = XmlDocument.parse(source);
    final root = document.rootElement;
    final urlBase = _childText(root, 'URLBase');
    final base = urlBase.isEmpty ? location : location.resolve(urlBase);
    for (final device in root.descendants.whereType<XmlElement>().where((e) => e.name.local == 'device')) {
      if (!RegExp(r'^urn:schemas-upnp-org:device:MediaRenderer:\d+$').hasMatch(_childText(device, 'deviceType'))) {
        continue;
      }
      final services = device.childElements.where((e) => e.name.local == 'serviceList');
      for (final service in services.expand((e) => e.childElements)) {
        final type = _childText(service, 'serviceType');
        final path = _childText(service, 'controlURL');
        if (!RegExp(r'^urn:schemas-upnp-org:service:AVTransport:\d+$').hasMatch(type) || path.isEmpty) continue;
        final control = base.resolve(path);
        if (!isDlnaHttpUri(control)) continue;
        final udn = _childText(device, 'UDN');
        final name = _childText(device, 'friendlyName');
        return DlnaDevice(
          id: udn.isEmpty ? location.toString() : udn,
          name: name.isEmpty ? location.host : name,
          controlUrl: control,
          serviceType: type,
        );
      }
    }
    return null;
  }
}

String _childText(XmlElement parent, String name) =>
    parent.childElements.where((e) => e.name.local == name).firstOrNull?.innerText.trim() ?? '';

bool isDlnaHttpUri(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty && uri.userInfo.isEmpty;

/// Header names are case insensitive; never trust the sender's claimed device type.
Uri? dlnaDescriptionLocation(String packet) {
  final lines = packet.split(RegExp(r'\r?\n'));
  if (lines.isEmpty || !RegExp(r'^HTTP/1\.[01] 200(?:\s|$)').hasMatch(lines.first.trim())) return null;
  for (final line in lines.skip(1)) {
    final colon = line.indexOf(':');
    if (colon <= 0 || line.substring(0, colon).trim().toLowerCase() != 'location') continue;
    final uri = Uri.tryParse(line.substring(colon + 1).trim());
    return uri != null && isDlnaHttpUri(uri) ? uri : null;
  }
  return null;
}
