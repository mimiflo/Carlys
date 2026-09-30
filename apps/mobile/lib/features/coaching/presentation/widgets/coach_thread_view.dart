import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/coach_thread_state.dart';
import 'coach_live_bubble.dart';
import 'coach_message_bubble.dart';
import 'coach_notices.dart';
import 'coach_proposal_card.dart';

/// Le fil du coach, du plus ancien au plus récent, ancré en bas.
///
/// La liste est **inversée** : la conversation s'ancre en bas, là où l'on
/// écrit et là où arrive la réponse. Le tour en cours (question et réponse
/// qui s'écrit) vient d'abord, puis l'historique, puis la mention de tête —
/// dernier rang, elle remonte avec l'histoire au lieu de coller à l'écran.
///
/// Un séparateur de JOUR se pose au-dessus du premier message de chaque
/// journée (« Aujourd’hui », « Hier », « 28/09/2026 ») : revenir le
/// lendemain et comparer n'a de sens que si l'on voit quel échange date de
/// quand. Le jour se lit en heure LOCALE.
class CoachThreadView extends StatelessWidget {
  const CoachThreadView({
    required this.messages,
    required this.live,
    required this.maxBubbleWidth,
    required this.onOpenProposal,
    super.key,
  });

  final List<CoachMessage> messages;
  final CoachLiveTurn? live;
  final double maxBubbleWidth;
  final ValueChanged<CoachSessionProposal> onOpenProposal;

  @override
  Widget build(BuildContext context) {
    final live = this.live;
    // Le tour en cours compte deux rangs : la question, puis la réponse.
    final pending = live == null ? 0 : 2;
    final now = DateTime.now();

    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.md,
      ),
      itemCount: messages.length + pending + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == messages.length + pending) {
          return const CoachDataNotice();
        }
        if (live != null && index < pending) {
          return index == 0
              ? CoachLiveBubble(text: live.text, maxWidth: maxBubbleWidth)
              : CoachBubble(
                  isUser: true,
                  maxWidth: maxBubbleWidth,
                  child: CoachBubbleText(live.question, isUser: true),
                );
        }

        final position = messages.length - 1 - (index - pending);
        final message = messages[position];
        final proposal = message.proposal;
        final day = _newDay(position);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (day != null)
              CoachDaySeparator(label: formatSpokenDay(day, now)),
            CoachMessageBubble(message: message, maxWidth: maxBubbleWidth),
            if (proposal != null) ...[
              const SizedBox(height: AppSpacing.xs),
              CoachProposalCard(
                proposal: proposal,
                maxWidth: maxBubbleWidth,
                onOpen: () => onOpenProposal(proposal),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Le jour LOCAL du message à [position] s'il ouvre une journée, sinon
  /// `null`. Un message sans date n'ouvre rien : on n'invente pas de jour.
  DateTime? _newDay(int position) {
    final at = messages[position].createdAt?.toLocal();
    if (at == null) return null;
    final before = position == 0
        ? null
        : messages[position - 1].createdAt?.toLocal();
    final sameDay =
        before != null &&
        before.year == at.year &&
        before.month == at.month &&
        before.day == at.day;
    return sameDay ? null : at;
  }
}

/// « Hier », centré entre deux traits : un repère, pas un message.
class CoachDaySeparator extends StatelessWidget {
  const CoachDaySeparator({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.darkBorder)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              label,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextTertiary,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.darkBorder)),
        ],
      ),
    );
  }
}
