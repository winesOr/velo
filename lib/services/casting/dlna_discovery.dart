import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'dlna_device.dart';
import 'dlna_http.dart';

/// Each subscription owns its sockets, HTTP client and multicast lease.
/// Cancellation and the scan deadline release all of them; nothing stays alive.
class DlnaDiscovery {
  DlnaDiscovery({
    this.acquireMulticast,
    this.releaseMulticast,
    http.Client Function()? clientFactory,
    InternetAddress? searchAddress,
    this.searchPort = 1900,
    this.scanDuration = const Duration(seconds: 8),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _searchAddress = searchAddress ?? InternetAddress('239.255.255.250');

  final Future<void> Function()? acquireMulticast;
  final Future<void> Function()? releaseMulticast;
  final http.Client Function() _clientFactory;
  final InternetAddress _searchAddress;
  final int searchPort;
  final Duration scanDuration;

  Stream<List<DlnaDevice>> scan() async* {
    final client = _clientFactory();
    final updates = StreamController<List<DlnaDevice>>();
    final devices = <String, DlnaDevice>{};
    final pending = <Uri>{};
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    Timer? deadline;
    Timer? repeat;
    var active = true;
    var leased = false;

    Future<void> inspect(Uri location) async {
      if (!pending.add(location)) return;
      try {
        final response = await readDlnaResponse(client, http.Request('GET', location));
        if (!active || response.status != 200) return;
        final device = DlnaDevice.fromDescription(response.body, location);
        if (device == null) return;
        devices[device.id] = device;
        final list = devices.values.toList()..sort((a, b) => a.name.compareTo(b.name));
        if (active && !updates.isClosed) updates.add(List.unmodifiable(list));
      } catch (_) {
        // A malformed, stale or non-renderer announcement must not fail the scan.
      }
    }

    try {
      await acquireMulticast?.call();
      leased = true;
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.multicastHops = 2;
      final searches =
          [
            'urn:schemas-upnp-org:device:MediaRenderer:1',
            'urn:schemas-upnp-org:service:AVTransport:1',
            'upnp:rootdevice',
          ].map((target) {
            return utf8.encode(
              'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\n'
              'MAN: "ssdp:discover"\r\nMX: 2\r\nST: $target\r\n\r\n',
            );
          }).toList();
      void sendSearch() {
        for (final search in searches) {
          try {
            socket?.send(search, _searchAddress, searchPort);
          } catch (_) {
            if (active && !updates.isClosed) {
              updates.addError(const DlnaException(DlnaFailure.unavailable));
              unawaited(updates.close());
            }
            return;
          }
        }
      }

      subscription = socket.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          Datagram? packet;
          while ((packet = socket?.receive()) != null) {
            final location = dlnaDescriptionLocation(utf8.decode(packet!.data, allowMalformed: true));
            if (location != null && pending.length < 64) unawaited(inspect(location));
          }
        },
        onError: (Object error) {
          if (active && !updates.isClosed) updates.addError(const DlnaException(DlnaFailure.unavailable));
        },
      );
      sendSearch();
      repeat = Timer.periodic(const Duration(seconds: 2), (_) => sendSearch());
      deadline = Timer(scanDuration, () => unawaited(updates.close()));
      yield* updates.stream;
    } finally {
      active = false;
      deadline?.cancel();
      repeat?.cancel();
      await subscription?.cancel();
      socket?.close();
      client.close();
      if (!updates.isClosed) unawaited(updates.close());
      if (leased) await releaseMulticast?.call();
    }
  }
}
