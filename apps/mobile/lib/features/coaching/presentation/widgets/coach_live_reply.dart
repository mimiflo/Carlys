import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/coach_controllers.dart';
import 'coach_live_bubble.dart';

/// La réponse du coach pendant qu'elle s'écrit, lue SEULE sur le fil.
///
/// Chaque morceau de texte refait l'état du fil. La page ne regarde que
/// ce qui la change ([coachPageKey]) ; cette bulle-ci regarde le tour en
/// cours, et c'est la seule à se reconstruire mot après mot
/// (`coach_page_test.dart`).
class CoachLiveReply extends ConsumerWidget {
  const CoachLiveReply({required this.maxWidth, super.key});

  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(
      coachThreadProvider.select((thread) => thread.valueOrNull?.live),
    );
    if (live == null) return const SizedBox.shrink();
    return CoachLiveBubble.turn(live, maxWidth: maxWidth);
  }
}

/// Ce qui reconstruit la page du coach : tout l'état du fil, SAUF l'avancée
/// du tour en cours (texte, étapes, file d'attente) — [CoachLiveReply] la
/// lit seul. La présence du tour et sa question, elles, en font partie.
Object? coachPageKey(AsyncValue<CoachThreadState> thread) => switch (thread) {
  AsyncData(:final value) => (
    value.conversation,
    value.isOffline,
    value.isReadOnly,
    value.notice,
    value.live?.question,
  ),
  _ => thread,
};
