import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/models/external_player_models.dart';

void main() {
  setUp(KnownPlayers.resetForTesting);
  tearDown(KnownPlayers.resetForTesting);

  // Which detectors run is driven by the probe, so every platform's wiring is
  // exercised on whatever host runs the suite.

  group('Linux', () {
    test('lists only players whose command resolves on PATH', () async {
      expect(await _resolveWith(_FakeProbe(commands: {'mpv'})), ['system_default', 'mpv']);
      expect(await _resolveWith(_FakeProbe(commands: {'vlc', 'celluloid'})), ['system_default', 'vlc', 'celluloid']);
      expect(await _resolveWith(_FakeProbe()), ['system_default']);
    });
  }, skip: !Platform.isLinux);

  group('Windows', () {
    test('accepts VLC from a concrete install path', () async {
      final probe = _FakeProbe(
        paths: {r'C:\Program Files\VideoLAN\VLC\vlc.exe'},
        environment: {'ProgramFiles': r'C:\Program Files'},
      );

      expect(await _resolveWith(probe), ['system_default', 'vlc']);
    });

    test('falls back to where.exe when no install path matches', () async {
      final probe = _FakeProbe(commands: {'vlc', 'mpv'});

      expect(await _resolveWith(probe), ['system_default', 'vlc', 'mpv']);
      expect(probe.runs, contains(equals(['where.exe', 'vlc'])));
    });

    test('accepts PotPlayer from its registered URL handler', () async {
      final probe = _FakeProbe(schemes: {'potplayer://'});

      expect(await _resolveWith(probe), ['system_default', 'potplayer']);
    });

    test('accepts PotPlayer from PATH when no handler is registered', () async {
      expect(await _resolveWith(_FakeProbe(commands: {'PotPlayerMini64'})), ['system_default', 'potplayer']);
    });
  }, skip: !Platform.isWindows);
}

Future<List<String>> _resolveWith(PlayerInstallProbe probe) async {
  KnownPlayers.resetForTesting();
  KnownPlayers.probe = probe;
  final players = await KnownPlayers.getForCurrentPlatform();
  return players.map((player) => player.id).toList();
}

/// Answers the host lookups from fixed sets, and records the subprocesses and
/// bundle lookups it is asked for so tests can assert what production issues.
class _FakeProbe extends PlayerInstallProbe {
  _FakeProbe({
    this.commands = const {},
    this.paths = const {},
    this.schemes = const {},
    this.environment = const {},
    String? operatingSystem,
  }) : operatingSystem = operatingSystem ?? Platform.operatingSystem;

  final Set<String> commands;
  final Set<String> paths;
  final Set<String> schemes;
  final List<List<String>> runs = [];
  final List<String> bundleLookups = [];
  final List<String> schemeLookups = [];

  @override
  final Map<String, String> environment;

  @override
  final String operatingSystem;

  @override
  Future<ProcessResult> run(String executable, List<String> arguments) async {
    runs.add([executable, ...arguments]);

    switch (executable) {
      case 'sh':
        return ProcessResult(0, commands.contains(arguments.last) ? 0 : 1, '', '');
      case 'where.exe':
        return ProcessResult(0, commands.contains(arguments.single) ? 0 : 1, '', '');
      default:
        fail('unexpected probe subprocess: $executable $arguments');
    }
  }

  @override
  Future<bool> applicationInstalled(String bundleId) async {
    bundleLookups.add(bundleId);
    return false;
  }

  @override
  Future<bool> fileExists(String path) async => paths.contains(path);

  @override
  Future<bool> schemeHasHandler(String scheme) async {
    schemeLookups.add(scheme);
    return schemes.contains(scheme);
  }
}
