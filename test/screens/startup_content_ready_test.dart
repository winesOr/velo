import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/main.dart';
import 'package:plezy/profiles/active_profile_provider.dart';
import 'package:plezy/providers/multi_server_provider.dart';

class _Identity extends ChangeNotifier implements ActiveProfileProvider {
  final ready = Completer<bool>();
  @override
  String? activeId = 'profile-a';
  @override
  int committedIdentityGeneration = 1;
  @override
  bool isBinding = true;
  @override
  bool isStartupIdentityReady = false;
  @override
  bool lastBindingSucceeded = true;
  @override
  bool get isDisposed => false;
  @override
  Duration startupContentWaitElapsed = Duration.zero;
  @override
  Future<bool> awaitStartupIdentityReady() => ready.future;
  void authorize() {
    isStartupIdentityReady = true;
    ready.complete(true);
    notifyListeners();
  }

  void switchProfile() {
    activeId = 'profile-b';
    committedIdentityGeneration++;
    isStartupIdentityReady = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Servers extends ChangeNotifier implements MultiServerProvider {
  @override
  List<String> onlineServerIds = [];
  void connect() {
    onlineServerIds = ['server'];
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the content budget starts after authorization and releases a still-loading shell', () {
    fakeAsync((clock) {
      final profile = _Identity();
      final servers = _Servers();
      bool? result;
      unawaited(
        awaitStartupContentReady(
          profile: profile,
          servers: servers,
          hasNetwork: true,
          connectionBudget: const Duration(milliseconds: 200),
        ).then((value) => result = value),
      );
      clock.elapse(const Duration(seconds: 5));
      expect(result, isNull, reason: 'elapsed content budget cannot authorize a PIN');
      profile.authorize();
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 199));
      expect(result, isNull);
      clock.elapse(const Duration(milliseconds: 1));
      expect(result, isTrue);
      expect(profile.isBinding, isTrue);
      profile.dispose();
      servers.dispose();
    });
  });

  test('first authorized server releases startup without waiting for bind settle', () {
    fakeAsync((clock) {
      final profile = _Identity()..authorize();
      final servers = _Servers();
      bool? result;
      unawaited(
        awaitStartupContentReady(profile: profile, servers: servers, hasNetwork: true).then((value) => result = value),
      );
      clock.flushMicrotasks();
      servers.connect();
      clock.flushMicrotasks();
      expect(result, isTrue);
      expect(profile.isBinding, isTrue);
      expect(clock.nonPeriodicTimerCount, 0);
      profile.dispose();
      servers.dispose();
    });
  });

  test('switching identity during connection wait rejects the old startup handoff', () {
    fakeAsync((clock) {
      final profile = _Identity()..authorize();
      final servers = _Servers();
      bool? result;
      unawaited(
        awaitStartupContentReady(profile: profile, servers: servers, hasNetwork: true).then((value) => result = value),
      );
      clock.flushMicrotasks();
      profile.switchProfile();
      servers.connect();
      clock.flushMicrotasks();
      expect(result, isFalse);
      expect(clock.nonPeriodicTimerCount, 0);
      profile.dispose();
      servers.dispose();
    });
  });
}
