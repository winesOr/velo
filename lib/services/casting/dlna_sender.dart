import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'dlna_device.dart';
import 'dlna_http.dart';

class DlnaMedia {
  const DlnaMedia({required this.url, required this.title, required this.position, this.duration});

  final Uri url;
  final String title;
  final Duration position;
  final Duration? duration;

  String get mimeType => switch (url.path.split('.').last.toLowerCase()) {
    'mkv' => 'video/x-matroska',
    'avi' => 'video/x-msvideo',
    'ts' || 'm2ts' => 'video/mp2t',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    _ => 'video/mp4',
  };
}

class DlnaHandoffResult {
  const DlnaHandoffResult({required this.resumeAccepted});

  final bool resumeAccepted;
}

/// A finite control exchange. Closing it NEVER stops or invalidates the media.
class DlnaSender {
  DlnaSender({
    http.Client? client,
    this.pollInterval = const Duration(milliseconds: 400),
    this.confirmAttempts = 15,
    this.handoffTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration pollInterval;
  final int confirmAttempts;
  final Duration handoffTimeout;
  bool _closed = false;

  Future<XmlDocument> _action(DlnaDevice device, String action, [Map<String, String> values = const {}]) async {
    if (_closed) throw const DlnaException(DlnaFailure.unavailable, mayBePlaying: true);
    final builder = XmlBuilder();
    builder.element(
      's:Envelope',
      namespaceUris: {'s': 'http://schemas.xmlsoap.org/soap/envelope/'},
      nest: () {
        builder.attribute('s:encodingStyle', 'http://schemas.xmlsoap.org/soap/encoding/');
        builder.element(
          's:Body',
          nest: () {
            builder.element(
              'u:$action',
              namespaceUris: {'u': device.serviceType},
              nest: () {
                builder.element('InstanceID', nest: '0');
                for (final entry in values.entries) {
                  builder.element(entry.key, nest: entry.value);
                }
              },
            );
          },
        );
      },
    );
    final request = http.Request('POST', device.controlUrl)
      ..headers.addAll({'Content-Type': 'text/xml; charset="utf-8"', 'SOAPAction': '"${device.serviceType}#$action"'})
      ..body = builder.buildDocument().toXmlString();
    final response = await readDlnaResponse(_client, request);
    final document = XmlDocument.parse(response.body);
    if (response.status != 200 || document.descendants.whereType<XmlElement>().any((e) => e.name.local == 'Fault')) {
      throw const DlnaException(DlnaFailure.rejected);
    }
    return document;
  }

  static String _field(XmlDocument document, String name) =>
      document.descendants.whereType<XmlElement>().where((e) => e.name.local == name).firstOrNull?.innerText.trim() ??
      '';

  Future<void> _confirm(DlnaDevice device, Uri url) async {
    var knownStopped = false;
    for (var attempt = 0; attempt < confirmAttempts; attempt++) {
      final state = _field(await _action(device, 'GetTransportInfo'), 'CurrentTransportState');
      final media = _field(await _action(device, 'GetMediaInfo'), 'CurrentURI');
      if (Uri.tryParse(media) == url) {
        if (state == 'PLAYING') return;
        knownStopped = state == 'STOPPED' || state == 'NO_MEDIA_PRESENT';
      } else {
        knownStopped = false;
      }
      if (attempt + 1 < confirmAttempts) await Future<void>.delayed(pollInterval);
    }
    throw DlnaException(DlnaFailure.unconfirmed, mayBePlaying: !knownStopped);
  }

  Future<DlnaHandoffResult> send(DlnaDevice device, DlnaMedia media) => _send(device, media).timeout(
    handoffTimeout,
    onTimeout: () {
      close();
      throw const DlnaException(DlnaFailure.unconfirmed, mayBePlaying: true);
    },
  );

  Future<DlnaHandoffResult> _send(DlnaDevice device, DlnaMedia media) async {
    var playRequested = false;
    try {
      await _action(device, 'SetAVTransportURI', {
        'CurrentURI': media.url.toString(),
        'CurrentURIMetaData': _metadata(media),
      });
      playRequested = true;
      await _action(device, 'Play', {'Speed': '1'});
      await _confirm(device, media.url);
      var resumeAccepted = media.position <= Duration.zero;
      if (!resumeAccepted) {
        try {
          await _action(device, 'Seek', {'Unit': 'REL_TIME', 'Target': dlnaTime(media.position)});
          resumeAccepted = true;
        } on DlnaException catch (error) {
          if (error.failure != DlnaFailure.rejected) rethrow;
        }
        await _confirm(device, media.url);
      }
      return DlnaHandoffResult(resumeAccepted: resumeAccepted);
    } on DlnaException catch (error) {
      if (playRequested && error.failure != DlnaFailure.unconfirmed) {
        throw DlnaException(error.failure, mayBePlaying: true);
      }
      rethrow;
    } catch (_) {
      throw DlnaException(DlnaFailure.unavailable, mayBePlaying: playRequested);
    }
  }

  void close() {
    _closed = true;
    _client.close();
  }

  static String _metadata(DlnaMedia media) {
    final builder = XmlBuilder();
    builder.element(
      'DIDL-Lite',
      namespaceUris: {
        '': 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/',
        'dc': 'http://purl.org/dc/elements/1.1/',
        'upnp': 'urn:schemas-upnp-org:metadata-1-0/upnp/',
      },
      nest: () {
        builder.element(
          'item',
          attributes: {'id': '0', 'parentID': '-1', 'restricted': '1'},
          nest: () {
            builder.element('dc:title', nest: media.title);
            builder.element('upnp:class', nest: 'object.item.videoItem');
            builder.element(
              'res',
              nest: () {
                builder.attribute('protocolInfo', 'http-get:*:${media.mimeType}:*');
                if (media.duration != null) builder.attribute('duration', dlnaTime(media.duration!));
                builder.text(media.url.toString());
              },
            );
          },
        );
      },
    );
    return builder.buildDocument().toXmlString();
  }
}

String dlnaTime(Duration position) {
  final seconds = position.inSeconds.clamp(0, 359999);
  return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
      '${((seconds ~/ 60) % 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}
