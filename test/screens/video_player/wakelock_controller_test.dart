import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/screens/video_player/wakelock_controller.dart';

void main() {
  group('WakelockController', () {
    testWidgets('reasserts during playback and stops after pause', (tester) async {
      final calls = <bool>[];
      final controller = WakelockController(
        refreshInterval: const Duration(seconds: 1),
        platformToggle: (enabled) async => calls.add(enabled),
      );

      await controller.setEnabled(true);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, [true, true]);
      await controller.setEnabled(false);
      await tester.pump(const Duration(seconds: 2));
      expect(calls, [true, true, false]);
    });

    testWidgets('an outgoing owner cannot disable its replacement', (tester) async {
      final calls = <bool>[];
      final controller = WakelockController(
        refreshInterval: const Duration(seconds: 1),
        platformToggle: (enabled) async => calls.add(enabled),
      );
      final outgoing = Object();
      final replacement = Object();

      await controller.setEnabledForOwner(outgoing, true);
      await controller.setEnabledForOwner(replacement, true);
      await controller.setEnabledForOwner(outgoing, false);
      expect(calls, [true, true]);

      await tester.pump(const Duration(seconds: 1));
      expect(calls, [true, true, true], reason: 'the replacement keeps the refresh timer alive');

      await controller.setEnabledForOwner(replacement, false);
      expect(calls, [true, true, true, false]);
      await tester.pump(const Duration(seconds: 2));
      expect(calls, [true, true, true, false]);
    });

    testWidgets('a failed initial enable recovers and resumes normal refreshes', (tester) async {
      final calls = <bool>[];
      var attempts = 0;
      final controller = WakelockController(
        platformToggle: (enabled) async {
          calls.add(enabled);
          if (enabled && attempts++ == 0) throw StateError('enable failed');
        },
      );

      await controller.setEnabled(true);
      await tester.pump(const Duration(milliseconds: 999));
      expect(calls, [true]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, [true, true]);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, [true, true, true]);

      await controller.setEnabled(false);
      await tester.pump(const Duration(seconds: 10));
      expect(calls, [true, true, true, false]);
    });

    testWidgets('persistent acquisition failure backs off and caps the delay', (tester) async {
      final calls = <bool>[];
      final controller = WakelockController(
        platformToggle: (enabled) async {
          calls.add(enabled);
          if (enabled) throw StateError('enable failed');
        },
      );

      await controller.setEnabled(true);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, [true, true]);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(calls.length, 2);
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls.length, 3);
      await tester.pump(const Duration(milliseconds: 4999));
      expect(calls.length, 3);
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls.length, 4);
      await tester.pump(const Duration(seconds: 5));
      expect(calls.length, 5, reason: 'the retry delay stays capped at five seconds');

      await controller.setEnabled(false);
      await tester.pump(const Duration(seconds: 10));
      expect(calls, [true, true, true, true, true, false]);
    });

    testWidgets('a failed periodic reassertion recovers without a playback event', (tester) async {
      final calls = <bool>[];
      final controller = WakelockController(
        platformToggle: (enabled) async {
          calls.add(enabled);
          if (calls.length == 2) throw StateError('refresh failed');
        },
      );

      await controller.setEnabled(true);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, [true, true]);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, [true, true, true]);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, [true, true, true, true]);
      await controller.setEnabled(false);
    });

    testWidgets('releasing one owner preserves the remaining owner scheduled recovery', (tester) async {
      final platform = _ControlledPlatformToggle();
      final controller = WakelockController(platformToggle: platform.call, refreshInterval: const Duration(seconds: 1));
      final first = Object();
      final second = Object();

      final firstEnable = controller.setEnabledForOwner(first, true);
      await tester.pump();
      platform.succeedNext();
      await tester.pump();
      await firstEnable;

      final secondEnable = controller.setEnabledForOwner(second, true);
      await tester.pump();
      expect(platform.calls, [true, true]);

      final releaseFirst = controller.setEnabledForOwner(first, false);
      await tester.pump();
      expect(platform.calls, [true, true], reason: 'releasing a redundant owner adds no platform work');

      platform.failNext(StateError('second enable failed'));
      await tester.pump();
      await Future.wait([secondEnable, releaseFirst]);
      await tester.pump(const Duration(milliseconds: 999));
      expect(platform.calls, [true, true], reason: 'the release must not retry or restart refresh');
      await tester.pump(const Duration(milliseconds: 1));
      expect(platform.calls, [true, true, true], reason: 'the remaining owner still needs automatic recovery');
      platform.succeedNext();
      await tester.pump();

      final releaseSecond = controller.setEnabledForOwner(second, false);
      await tester.pump();
      expect(platform.calls, [true, true, true, false]);
      platform.succeedNext();
      await tester.pump();
      await releaseSecond;
    });

    testWidgets('releasing the last owner cancels a pending acquisition retry', (tester) async {
      final calls = <bool>[];
      final owner = Object();
      final controller = WakelockController(
        platformToggle: (enabled) async {
          calls.add(enabled);
          if (enabled) throw StateError('enable failed');
        },
      );

      await controller.setEnabledForOwner(owner, true);
      await tester.pump(const Duration(milliseconds: 500));
      await controller.setEnabledForOwner(owner, false);
      await tester.pump(const Duration(seconds: 10));
      expect(calls, [true, false]);
    });

    testWidgets('a slow retry cannot overlap or reacquire after the owner leaves', (tester) async {
      final platform = _ControlledPlatformToggle();
      final controller = WakelockController(
        platformToggle: platform.call,
        retryDelays: const [Duration(milliseconds: 100)],
      );
      final owner = Object();
      final enable = controller.setEnabledForOwner(owner, true);
      await tester.pump();
      platform.failNext(StateError('enable failed'));
      await tester.pump();
      await enable;

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 10));
      expect(platform.calls, [true, true]);
      expect(platform.maxConcurrent, 1);

      final release = controller.setEnabledForOwner(owner, false);
      platform.succeedNext();
      await tester.pump();
      expect(platform.calls, [true, true, false]);
      platform.succeedNext();
      await tester.pump();
      await release;
      await tester.pump(const Duration(seconds: 10));
      expect(platform.calls, [true, true, false]);
      expect(platform.maxConcurrent, 1);
    });

    testWidgets('repeated enable immediately reasserts after resume', (tester) async {
      final calls = <bool>[];
      final controller = WakelockController(
        refreshInterval: const Duration(seconds: 5),
        platformToggle: (enabled) async => calls.add(enabled),
      );
      await controller.setEnabled(true);
      await controller.setEnabled(true);
      expect(calls, [true, true]);
      await controller.setEnabled(false);
    });

    testWidgets('slow platform work does not queue periodic refreshes', (tester) async {
      final platform = _ControlledPlatformToggle();
      final controller = WakelockController(platformToggle: platform.call, refreshInterval: const Duration(seconds: 1));
      final enable = controller.setEnabled(true);
      await tester.pump();
      expect(platform.calls, [true]);
      platform.succeedNext();
      await enable;

      await tester.pump(const Duration(seconds: 1));
      expect(platform.calls, [true, true]);
      await tester.pump(const Duration(seconds: 5));
      expect(platform.calls, [true, true], reason: 'a pending refresh suppresses later ticks');

      platform.succeedNext();
      await tester.pump();
      final disable = controller.setEnabled(false);
      await tester.pump();
      platform.succeedNext();
      expect(platform.calls, [true, true, false]);
      await disable;
    });

    testWidgets('queued refresh cannot reacquire after teardown', (tester) async {
      final platform = _ControlledPlatformToggle();
      final controller = WakelockController(platformToggle: platform.call, refreshInterval: const Duration(seconds: 1));
      final enable = controller.setEnabled(true);
      await tester.pump();
      platform.succeedNext();
      await enable;

      await tester.pump(const Duration(seconds: 1));
      final disable = controller.setEnabled(false);
      platform.succeedNext();
      await tester.pump();
      expect(platform.calls, [true, true, false]);
      platform.succeedNext();
      await tester.pump();
      await disable;
      await tester.pump(const Duration(seconds: 2));
      expect(platform.calls, [true, true, false]);
    });

    test('drains enable then disable without overlapping platform work', () async {
      final platform = _ControlledPlatformToggle();
      final controller = WakelockController(platformToggle: platform.call);

      final enable = controller.setEnabled(true);
      await _flushTasks();
      expect(platform.calls, [true]);

      final disable = controller.setEnabled(false);
      await _flushTasks();
      expect(platform.calls, [true]);
      expect(platform.maxConcurrent, 1);

      platform.succeedNext();
      await _flushTasks();
      expect(platform.calls, [true, false]);

      platform.succeedNext();
      await Future.wait([enable, disable]);

      expect(platform.completed, [true, false]);
      expect(platform.active, 0);
      expect(platform.maxConcurrent, 1);
    });

    testWidgets('drains disable then enable to the latest desired state', (tester) async {
      final platform = _ControlledPlatformToggle();
      final controller = WakelockController(platformToggle: platform.call);

      final initialEnable = controller.setEnabled(true);
      await tester.pump();
      platform.succeedNext();
      await tester.pump();
      await initialEnable;

      final disable = controller.setEnabled(false);
      await tester.pump();
      expect(platform.calls, [true, false]);

      final enable = controller.setEnabled(true);
      await tester.pump();
      expect(platform.calls, [true, false]);

      platform.succeedNext();
      await tester.pump();
      expect(platform.calls.take(3), [true, false, true]);
      while (platform.hasPending) {
        platform.succeedNext();
        await tester.pump();
      }
      await Future.wait([disable, enable]);

      expect(platform.completed.last, isTrue);
      expect(platform.maxConcurrent, 1);
      final cleanup = controller.setEnabled(false);
      await tester.pump();
      while (platform.hasPending) {
        platform.succeedNext();
        await tester.pump();
      }
      await cleanup;
    });

    testWidgets('an explicit request can recover before the retry deadline', (tester) async {
      final calls = <bool>[];
      final controller = WakelockController(
        platformToggle: (enabled) async {
          calls.add(enabled);
          if (calls.length == 1) throw StateError('enable failed');
        },
      );

      await expectLater(controller.setEnabled(true), completes);
      await tester.pump();
      expect(calls, [true], reason: 'a failure must not start a busy retry loop');

      await expectLater(controller.setEnabled(true), completes);
      expect(calls, [true, true], reason: 'the failed state must remain explicitly retryable');
      await tester.pump(const Duration(seconds: 1));
      expect(calls, [true, true], reason: 'success cancels the previously scheduled retry');

      await controller.setEnabled(true);
      expect(calls, [true, true, true], reason: 'a repeated enable reasserts the platform flag');
      await controller.setEnabled(false);
    });

    testWidgets('a failed late enable still releases after a cached disabled state', (tester) async {
      final platform = _ControlledPlatformToggle();
      final controller = WakelockController(platformToggle: platform.call);
      final initialDisable = controller.setEnabled(false);
      await tester.pump();
      platform.succeedNext();
      await tester.pump();
      await initialDisable;

      final enable = controller.setEnabled(true);
      await tester.pump();
      final disable = controller.setEnabled(false);
      platform.failNext(StateError('enable applied before channel failed'));
      await tester.pump();
      expect(platform.calls, [false, true, false]);
      platform.succeedNext();
      await tester.pump();
      await Future.wait([enable, disable]);
      await tester.pump(const Duration(seconds: 10));
      expect(platform.calls, [false, true, false]);
    });

    test('applies a newer opposing request after acquisition fails', () async {
      final platform = _ControlledPlatformToggle();
      final controller = WakelockController(platformToggle: platform.call);

      final enable = controller.setEnabled(true);
      await _flushTasks();
      final disable = controller.setEnabled(false);

      platform.failNext(StateError('enable failed'));
      await _flushTasks();
      expect(platform.calls, [true, false]);
      expect(platform.maxConcurrent, 1);

      platform.succeedNext();
      await expectLater(Future.wait([enable, disable]), completes);

      expect(platform.completed, [false]);
      expect(platform.active, 0);
    });

    test('keeps effective state after release failure and retries disable', () async {
      var disableAttempts = 0;
      final calls = <bool>[];
      final controller = WakelockController(
        platformToggle: (enabled) async {
          calls.add(enabled);
          if (!enabled && disableAttempts++ == 0) {
            throw StateError('disable failed');
          }
        },
      );

      await controller.setEnabled(true);
      await expectLater(controller.setEnabled(false), completes);
      expect(calls, [true, false]);

      await expectLater(controller.setEnabled(false), completes);
      expect(calls, [true, false, false]);

      await controller.setEnabled(false);
      expect(calls, [true, false, false]);
    });

    test('detached teardown disable drains after an in-flight enable', () async {
      final platform = _ControlledPlatformToggle();
      final controller = WakelockController(platformToggle: platform.call);

      final enable = controller.setEnabled(true);
      await _flushTasks();
      unawaited(controller.setEnabled(false));

      platform.succeedNext();
      await _flushTasks();
      expect(platform.calls, [true, false]);

      platform.succeedNext();
      await enable;
      await _flushTasks();

      expect(platform.completed, [true, false]);
      expect(platform.active, 0);
      expect(platform.maxConcurrent, 1);
    });
  });
}

Future<void> _flushTasks() => Future<void>.delayed(Duration.zero);

class _ControlledPlatformToggle {
  final calls = <bool>[];
  final completed = <bool>[];
  final _pending = <({bool enabled, Completer<void> completer})>[];

  int active = 0;
  int maxConcurrent = 0;
  bool get hasPending => _pending.isNotEmpty;

  Future<void> call(bool enabled) async {
    calls.add(enabled);
    active++;
    if (active > maxConcurrent) maxConcurrent = active;

    final completer = Completer<void>();
    _pending.add((enabled: enabled, completer: completer));
    try {
      await completer.future;
      completed.add(enabled);
    } finally {
      active--;
    }
  }

  void succeedNext() => _pending.removeAt(0).completer.complete();

  void failNext(Object error) => _pending.removeAt(0).completer.completeError(error);
}
