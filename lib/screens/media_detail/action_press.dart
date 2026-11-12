import 'package:flutter/material.dart';

import '../../theme/interaction_tokens.dart';
import '../../widgets/press_feedback.dart';

/// Keeps a Material control's pressed state local without duplicating its
/// gesture recognizer, callback, semantics, or focus target.
class DetailActionPress extends StatefulWidget {
  const DetailActionPress({super.key, required this.builder});
  final Widget Function(WidgetStatesController states) builder;

  @override
  State<DetailActionPress> createState() => _DetailActionPressState();
}

class _DetailActionPressState extends State<DetailActionPress> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _states,
    builder: (context, _) => PressFeedback(
      pressed: _states.value.contains(WidgetState.pressed),
      enabled: !_states.value.contains(WidgetState.disabled),
      pressedScale: InteractionTokens.secondaryPressedScale,
      borderRadius: const BorderRadius.all(Radius.circular(100)),
      child: widget.builder(_states),
    ),
  );
}
