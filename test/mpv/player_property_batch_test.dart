import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/mpv/player/platform/player_android.dart';
import 'package:plezy/mpv/player/player_native.dart';
import 'package:plezy/mpv/player/player_property_batch.dart';
import 'package:plezy/services/settings_service.dart';

import '../test_helpers/mock_player_channels.dart';
import '../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
  });

  test('portable batch attempts later writes after a preference is refused', () async {
    final names = <String>[];
    await withMockPlayerChannels(
      methodChannelName: 'com.plezy/mpv_player',
      eventChannelName: 'com.plezy/mpv_player/events',
      methodHandler: (call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'setProperty') {
          final name = (call.arguments as Map)['name'] as String;
          names.add(name);
          if (name == 'unsupported') throw PlatformException(code: 'SET_PROPERTY_FAILED');
        }
        return null;
      },
      testBody: () async {
        final player = PlayerNative();
        try {
          await expectLater(
            player.setProperties({'first': '1', 'unsupported': '2', 'last': '3'}),
            throwsA(isA<PlayerPropertyBatchException>().having((e) => e.failures.keys, 'failures', ['unsupported'])),
          );
          expect(names, ['first', 'unsupported', 'last']);
        } finally {
          await player.dispose();
        }
      },
    );
  });

  test('ExoPlayer sends preferences in one request and waits for its reply', () async {
    final pending = Completer<List<Object?>>();
    final calls = <MethodCall>[];
    await withMockPlayerChannels(
      methodChannelName: 'com.plezy/exo_player',
      eventChannelName: 'com.plezy/exo_player/events',
      methodHandler: (call) async {
        calls.add(call);
        if (call.method == 'setMpvProperties') return pending.future;
        return null;
      },
      testBody: () async {
        final player = PlayerAndroid();
        var done = false;
        try {
          final batch = player.setProperties({'sub-color': '#FFFFFF', 'sub-pos': '100'}).then((_) => done = true);
          await Future<void>.delayed(Duration.zero);
          expect(done, isFalse);
          expect(calls.map((c) => c.method), ['setMpvProperties']);
          expect((calls.single.arguments as Map)['properties'], [
            {'name': 'sub-color', 'value': '#FFFFFF'},
            {'name': 'sub-pos', 'value': '100'},
          ]);
          pending.complete([]);
          await batch;
          expect(done, isTrue);
        } finally {
          if (!pending.isCompleted) pending.complete([]);
          await player.dispose();
        }
      },
    );
  });

  test('native batch exposes each rejected name', () async {
    await withMockPlayerChannels(
      methodChannelName: 'com.plezy/exo_player',
      eventChannelName: 'com.plezy/exo_player/events',
      methodHandler: (call) async => call.method == 'setMpvProperties'
          ? [
              {'name': 'sub-pos', 'code': 'SET_PROPERTY_FAILED'},
            ]
          : null,
      testBody: () async {
        final player = PlayerAndroid();
        try {
          await expectLater(player.setProperties({'sub-pos': '100'}), throwsA(isA<PlayerPropertyBatchException>()));
        } finally {
          await player.dispose();
        }
      },
    );
  });
}
