import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/platform_detector.dart';

/// Gives a TV drawer's current item focus once, without overriding user input.
class PlayerInitialFocus {
  PlayerInitialFocus() {
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  final currentItem = FocusNode(debugLabel: 'CurrentPlayerDrawerItem');
  final _page = FocusNode(debugLabel: 'PlayerDrawerPage', skipTraversal: true, canRequestFocus: false);
  bool _pending = true;
  bool _scheduled = false;
  bool _disposed = false;

  bool _handleKey(KeyEvent event) {
    if (_page.hasFocus && (event is KeyDownEvent || event is KeyRepeatEvent)) _pending = false;
    return false;
  }

  Widget wrap(Widget child) => Focus(
    focusNode: _page,
    child: Listener(onPointerDown: (_) => _pending = false, onPointerSignal: (_) => _pending = false, child: child),
  );

  void focusWhenVisible() {
    if (_disposed || !_pending || _scheduled || !PlatformDetector.isTV()) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (_disposed || !_pending || !_page.hasFocus) return;
        final target = currentItem.context;
        if (target == null || !currentItem.canRequestFocus || ModalRoute.of(target)?.isCurrent == false) return;
        _pending = false;
        currentItem.requestFocus();
        Scrollable.ensureVisible(target, alignment: .25);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  void dispose() {
    _disposed = true;
    HardwareKeyboard.instance.removeHandler(_handleKey);
    currentItem.dispose();
    _page.dispose();
  }
}
