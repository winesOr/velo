import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_detector.dart';

/// Short system-key feedback for a committed setting or destination change.
void selectionFeedback() {
  if (!PlatformDetector.isTV() &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    unawaited(HapticFeedback.lightImpact());
  }
}
