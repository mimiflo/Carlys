import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'coach_live_bubble.dart';
import 'coach_message_bubble.dart';

/// Le bonjour du coach à l'ouverture (`coachGreeting`).
///
/// Un court « Réfléchit… » le précède, comme une vraie réponse : le coach
/// arrive, il ne s'affiche pas. Quand le système demande moins
/// d'animations, le bonjour est là tout de suite. Annoncé aux lecteurs
/// d'écran à son arrivée.
class CoachGreetingBubble extends StatefulWidget {
  const CoachGreetingBubble({
    required this.text,
    required this.since,
    this.maxWidth = double.infinity,
    super.key,
  });

  final String text;

  /// L'ouverture (`CoachGreeting.at`) : l'attente se compte à partir d'elle.
  final DateTime since;
  final double maxWidth;

  @override
  State<CoachGreetingBubble> createState() => _CoachGreetingBubbleState();
}

class _CoachGreetingBubbleState extends State<CoachGreetingBubble>
    with SingleTickerProviderStateMixin {
  /// Une animation plutôt qu'un minuteur : elle s'arrête avec l'écran, et
  /// une durée nulle (moins d'animations) la termine d'emblée.
  late final AnimationController _arrival = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status.isCompleted && mounted) setState(() {});
    });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrival.isAnimating || _arrival.isCompleted) return;
    final left = widget.since
        .add(AppMotion.resolve(context, AppMotion.reveal))
        .difference(DateTime.now());
    if (left <= Duration.zero) {
      _arrival.value = _arrival.upperBound;
    } else {
      _arrival
        ..duration = left
        ..forward();
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.resolve(context, AppMotion.normal),
      child: _arrival.isCompleted
          ? CoachBubble(
              key: const ValueKey('bonjour'),
              isUser: false,
              maxWidth: widget.maxWidth,
              child: Semantics(
                liveRegion: true,
                child: CoachBubbleText(widget.text, isUser: false),
              ),
            )
          : CoachLiveBubble(
              key: const ValueKey('arrivée'),
              text: '',
              maxWidth: widget.maxWidth,
            ),
    );
  }
}
