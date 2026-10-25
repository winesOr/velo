import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xml/xml.dart';
import 'package:plezy/services/casting/dlna_device.dart';
import 'package:plezy/services/casting/dlna_discovery.dart';
import 'package:plezy/services/casting/dlna_http.dart';
import 'package:plezy/services/casting/dlna_sender.dart';

String description({String type = 'MediaRenderer', String name = 'Living room'}) =>
    '''
<root xmlns="urn:schemas-upnp-org:device-1-0"><URLBase>http://tv.test:1400/base/</URLBase><device>
<deviceType>urn:schemas-upnp-org:device:$type:1</deviceType><friendlyName>$name</friendlyName><UDN>uuid:tv</UDN>
<serviceList><service><serviceType>urn:schemas-upnp-org:service:AVTransport:2</serviceType>
<controlURL>control</controlURL></service></serviceList></device></root>''';

String field(XmlDocument xml, String name) =>
    xml.descendants.whereType<XmlElement>().firstWhere((e) => e.name.local == name).innerText;

void main() {
  final device = DlnaDevice.fromDescription(description(), Uri.parse('http://tv.test/desc.xml'))!;
  final media = DlnaMedia(
    url: Uri.parse('https://media.test/Videos/id/stream.mkv?api_key=secret&a=1'),
    title: 'Film <One> & Two',
    position: const Duration(minutes: 12, seconds: 34),
    duration: const Duration(hours: 1),
  );

  test('description resolves URLBase, preserves service version and rejects servers', () {
    expect(device.controlUrl.toString(), 'http://tv.test:1400/base/control');
    expect(device.serviceType, endsWith(':2'));
    expect(DlnaDevice.fromDescription(description(type: 'MediaServer'), device.controlUrl), isNull);
    final relative = description().replaceAll('<URLBase>http://tv.test:1400/base/</URLBase>', '');
    expect(
      DlnaDevice.fromDescription(relative, Uri.parse('http://tv.test/folder/desc.xml'))!.controlUrl.toString(),
      'http://tv.test/folder/control',
    );
  });

  test('SSDP handles header case and rejects unsupported locations', () {
    expect(dlnaDescriptionLocation('HTTP/1.1 200 OK\r\nlOcAtIoN: http://tv.test/desc.xml\r\n')?.host, 'tv.test');
    expect(dlnaDescriptionLocation('NOTIFY * HTTP/1.1\r\nLOCATION: http://tv.test/desc.xml'), isNull);
    expect(dlnaDescriptionLocation('HTTP/1.1 200 OK\r\nLOCATION: file:///tmp/desc'), isNull);
  });

  Future<({DlnaHandoffResult result, List<String> actions})> handoff({bool rejectSeek = false}) async {
    final actions = <String>[];
    final sender = DlnaSender(
      client: MockClient((request) async {
        final action = request.headers['SOAPAction']!.split('#').last.replaceAll('"', '');
        actions.add(action);
        final xml = XmlDocument.parse(request.body);
        if (action == 'SetAVTransportURI') {
          expect(field(xml, 'CurrentURI'), media.url.toString());
          final didl = XmlDocument.parse(field(xml, 'CurrentURIMetaData'));
          expect(field(didl, 'title'), media.title);
          expect(field(didl, 'res'), media.url.toString());
          expect(request.body, contains('&amp;'));
        }
        if (action == 'Seek') {
          expect(field(xml, 'Target'), '00:12:34');
          if (rejectSeek) return http.Response('<Fault><errorCode>710</errorCode></Fault>', 500);
        }
        final body = switch (action) {
          'GetMediaInfo' => '<CurrentURI>${media.url.toString().replaceAll('&', '&amp;')}</CurrentURI>',
          'GetTransportInfo' => '<CurrentTransportState>PLAYING</CurrentTransportState>',
          _ => '',
        };
        return http.Response('<Response>$body</Response>', 200);
      }),
      pollInterval: Duration.zero,
    );
    final result = await sender.send(device, media);
    sender.close();
    expect(actions, isNot(contains('Stop')));
    return (result: result, actions: actions);
  }

  test('handoff escapes URL and DIDL, confirms media, resumes and detaches without Stop', () async {
    final outcome = await handoff();
    expect(outcome.result.resumeAccepted, isTrue);
    expect(outcome.actions.take(2), ['SetAVTransportURI', 'Play']);
    expect(outcome.actions, contains('Seek'));
  });

  test('rejected Seek still hands off confirmed playback with an explicit warning result', () async {
    expect((await handoff(rejectSeek: true)).result.resumeAccepted, isFalse);
  });

  test('playing another URI cannot confirm the handoff or trigger a local auto-resume', () async {
    final sender = DlnaSender(
      confirmAttempts: 1,
      client: MockClient((request) async {
        final state = request.headers['SOAPAction']!.contains('GetTransportInfo');
        return http.Response(
          state
              ? '<R><CurrentTransportState>PLAYING</CurrentTransportState></R>'
              : '<R><CurrentURI>http://other.test/movie.mp4</CurrentURI></R>',
          200,
        );
      }),
    );
    addTearDown(sender.close);
    await expectLater(
      sender.send(device, media),
      throwsA(isA<DlnaException>().having((e) => e.mayBePlaying, 'uncertain remote', isTrue)),
    );
  });

  test('handoff timeout is uncertain and closes the client without Stop', () async {
    final sender = DlnaSender(
      client: MockClient.streaming((_, _) => Completer<http.StreamedResponse>().future),
      handoffTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      sender.send(device, media),
      throwsA(isA<DlnaException>().having((e) => e.mayBePlaying, 'uncertain remote', isTrue)),
    );
    await expectLater(
      sender.send(device, media),
      throwsA(isA<DlnaException>().having((e) => e.failure, 'closed client', DlnaFailure.unavailable)),
    );
  });

  test('HTTP errors and malformed responses never expose a server token', () async {
    final sender = DlnaSender(client: MockClient((_) async => http.Response('secret api_key=secret', 500)));
    addTearDown(sender.close);
    try {
      await sender.send(device, media);
      fail('Expected a handoff failure');
    } catch (error) {
      expect(error.toString(), isNot(contains('secret')));
      expect(error, isA<DlnaException>());
    }
  });

  test('discovery de-duplicates device identities and releases its multicast lease', () async {
    final server = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    var acquired = 0;
    var released = 0;
    var requests = 0;
    final searches = <String>[];
    final sub = server.listen((event) {
      if (event != RawSocketEvent.read) return;
      final packet = server.receive()!;
      final target = RegExp(r'^ST: (.+)$', multiLine: true).firstMatch(utf8.decode(packet.data))?.group(1);
      if (target != null) searches.add(target);
      for (final path in ['one', 'two']) {
        server.send(
          utf8.encode('HTTP/1.1 200 OK\r\nLOCATION: http://tv.test/$path.xml\r\n\r\n'),
          packet.address,
          packet.port,
        );
      }
    });
    addTearDown(sub.cancel);
    final discovery = DlnaDiscovery(
      searchAddress: InternetAddress.loopbackIPv4,
      searchPort: server.port,
      scanDuration: const Duration(milliseconds: 100),
      acquireMulticast: () async {
        acquired++;
      },
      releaseMulticast: () async {
        released++;
      },
      clientFactory: () => MockClient((_) async {
        requests++;
        return http.Response(description(), 200);
      }),
    );
    final updates = await discovery.scan().toList();
    expect(requests, 2);
    expect(searches.toSet(), {
      'urn:schemas-upnp-org:device:MediaRenderer:1',
      'urn:schemas-upnp-org:service:AVTransport:1',
      'upnp:rootdevice',
    });
    expect(updates, isNotEmpty);
    expect(updates.every((list) => list.length == 1), isTrue);
    expect(acquired, 1);
    expect(released, 1);
  });

  test('cancelling discovery releases resources before its normal deadline', () async {
    var released = false;
    final leased = Completer<void>();
    final scan = DlnaDiscovery(
      acquireMulticast: () async {
        leased.complete();
      },
      releaseMulticast: () async {
        released = true;
      },
    ).scan().listen((_) {});
    await leased.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await scan.cancel();
    expect(released, isTrue);
  });
}
