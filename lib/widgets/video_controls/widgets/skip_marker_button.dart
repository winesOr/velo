import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_symbols_icons/symbols.dart';

import '../../../focus/card_focus_scope.dart';
import '../../../focus/focusable_wrapper.dart';
import '../../../i18n/strings.g.dart';
import '../../../media/media_source_info.dart';
import '../../../utils/platform_detector.dart';
import '../../app_icon.dart';
import '../../press_feedback.dart';

/// Frosted capsule geometry, phone and TV.
class _SkipMetrics {
  const _SkipMetrics({
    required this.height,
    required this.padStart,
    required this.padEnd,
    required this.fontSize,
    required this.badge,
    required this.icon,
    required this.countdownFont,
  });

  final double height;
  final double padStart;
  final double padEnd;
  final double fontSize;
  final double badge;
  final double icon;
  final double countdownFont;

  double get radius => height / 2;

  static const phone = _SkipMetrics(
    height: 40,
    padStart: 16,
    padEnd: 12,
    fontSize: 14,
    badge: 22,
    icon: 13,
    countdownFont: 11,
  );
  static const tv = _SkipMetrics(
    height: 80,
    padStart: 34,
    padEnd: 24,
    fontSize: 30,
    badge: 44,
    icon: 24,
    countdownFont: 22,
  );
}

const _glass = Color(0x8F18181A);
const _glassUndo = Color(0x6118181A);
const _focusRing = Color(0xFFB4AAFF);
const _focusInk = Color(0xFF111111);

class SkipMarkerButton extends StatelessWidget {
  final MediaMarker marker;
  final Duration playerDuration;
  final bool hasNextEpisode;
  final bool isAutoSkipActive;
  final bool shouldShowAutoSkip;
  final int autoSkipDelay;
  final double autoSkipProgress;
  final FocusNode focusNode;
  final VoidCallback onActivate;
  final VoidCallback onFocusDown;
  final VoidCallback? onFocusUp;
  final String? labelOverride;

  const SkipMarkerButton({
    super.key,
    required this.marker,
    required this.playerDuration,
    required this.hasNextEpisode,
    required this.isAutoSkipActive,
    required this.shouldShowAutoSkip,
    required this.autoSkipDelay,
    required this.autoSkipProgress,
    required this.focusNode,
    required this.onActivate,
    required this.onFocusDown,
    this.onFocusUp,
    this.labelOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isCredits = marker.isCredits;
    final creditsAtEnd =
        isCredits && playerDuration > Duration.zero && (playerDuration - marker.endTime).inMilliseconds <= 1000;
    final showNextEpisode = creditsAtEnd && hasNextEpisode;
    String baseButtonText;
    if (showNextEpisode) {
      baseButtonText = t.videoControls.nextEpisode;
    } else if (isCredits) {
      baseButtonText = t.videoControls.skipCredits;
    } else {
      baseButtonText = t.videoControls.skipIntro;
    }

    final remainingSeconds = isAutoSkipActive && shouldShowAutoSkip
        ? (autoSkipDelay - (autoSkipProgress * autoSkipDelay)).ceil().clamp(0, autoSkipDelay)
        : 0;

    final showAutoSkipCountdown = isAutoSkipActive && shouldShowAutoSkip;
    // The countdown lives in the ring on the right, not in the label.
    final buttonText = labelOverride ?? baseButtonText;
    final buttonIcon = showNextEpisode ? Symbols.skip_next_rounded : Symbols.fast_forward_rounded;

    final isUndo = labelOverride != null;
    final metrics = PlatformDetector.isTV() ? _SkipMetrics.tv : _SkipMetrics.phone;

    return FocusableWrapper(
      focusNode: focusNode,
      descendantsAreFocusable: false,
      onSelect: _activate,
      borderRadius: metrics.radius,
      delegateFocusBorder: true,
      focusScale: 1.04,
      autoScroll: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
          onFocusDown();
          return KeyEventResult.handled;
        }
        if (onFocusUp != null && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
          onFocusUp!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = CardFocusScope.maybeOf(context) ?? false;
          final ink = focused ? _focusInk : Colors.white;
          final radius = BorderRadius.circular(metrics.radius);
          final badge = _buildBadge(metrics, ink, focused, showAutoSkipCountdown, remainingSeconds, buttonIcon, isUndo);
          final label = Text(
            buttonText,
            maxLines: 1,
            style: TextStyle(color: ink, fontSize: metrics.fontSize, fontWeight: .w600),
          );
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: const [BoxShadow(color: Color(0x47000000), blurRadius: 22, offset: Offset(0, 6))],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: radius,
                    border: focused
                        ? Border.all(color: _focusRing, width: 3, strokeAlign: BorderSide.strokeAlignInside)
                        : Border.all(
                            color: const Color(0x42FFFFFF),
                            width: 0.5,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                  ),
                  decoration: BoxDecoration(
                    color: focused ? const Color(0xF2FFFFFF) : (isUndo ? _glassUndo : _glass),
                    borderRadius: radius,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: PressFeedbackInkWell(
                      canRequestFocus: false,
                      onTap: _activate,
                      borderRadius: radius,
                      child: Stack(
                        children: [
                          if (showAutoSkipCountdown)
                            Positioned.fill(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: FractionallySizedBox(
                                  widthFactor: autoSkipProgress.clamp(0.0, 1.0),
                                  heightFactor: 1,
                                  child: const ColoredBox(color: Color(0x24FFFFFF)),
                                ),
                              ),
                            ),
                          SizedBox(
                            height: metrics.height,
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                start: isUndo ? metrics.padEnd : metrics.padStart,
                                end: isUndo ? metrics.padStart : metrics.padEnd,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isUndo) ...[badge, SizedBox(width: metrics.badge * .36)],
                                  label,
                                  if (!isUndo) ...[SizedBox(width: metrics.badge * .36), badge],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Round icon chip, or the countdown ring while an auto-skip is pending.
  Widget _buildBadge(
    _SkipMetrics metrics,
    Color ink,
    bool focused,
    bool countdown,
    int remainingSeconds,
    IconData icon,
    bool isUndo,
  ) {
    final size = metrics.badge;
    if (countdown && !isUndo) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: autoSkipProgress.clamp(0.0, 1.0),
              strokeWidth: size / 11,
              backgroundColor: ink.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(ink),
            ),
            Text(
              '$remainingSeconds',
              style: TextStyle(color: ink, fontSize: metrics.countdownFont, fontWeight: .w600, height: 1),
            ),
          ],
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: focused ? _focusInk.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.16),
      ),
      child: AppIcon(isUndo ? Symbols.undo_rounded : icon, fill: 1, color: ink, size: metrics.icon),
    );
  }

  void _activate() => onActivate();
}
