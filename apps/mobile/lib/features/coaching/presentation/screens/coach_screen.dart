import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';
import '../widgets/coach_composer.dart';
import '../widgets/coach_message_bubble.dart';
import '../widgets/coach_proposal_card.dart';
import '../widgets/coach_suggestions.dart';

/// Écran du coach : une conversation qui se termine par une **action**.
///
/// Volontairement PRÉSENTATIONNEL — il reçoit ses données, il ne les va pas
/// chercher. Le contrôleur qui l'alimentera arrive avec la couche data ; d'ici
/// là, rien dans cet écran ne prétend être connecté à quoi que ce soit.
class CoachScreen extends StatelessWidget {
  const CoachScreen({
    required this.messages,
    required this.suggestions,
    required this.composerController,
    required this.onSend,
    required this.onOpenProposal,
    this.isOffline = false,
    this.isSending = false,
    this.notice,
    this.showBackButton = true,
    this.bottomInset = 0,
    super.key,
  });

  final List<CoachMessage> messages;
  final List<String> suggestions;
  final TextEditingController composerController;
  final ValueChanged<String> onSend;
  final ValueChanged<CoachSessionProposal> onOpenProposal;
  final bool isOffline;
  final bool isSending;

  /// Refus explicite du serveur (plafond du jour, coach coupé). Jamais un
  /// message d'ambiance : s'il est là, c'est qu'un envoi a été refusé.
  final String? notice;

  /// L'écran est atteint par un onglet : il n'y a alors nulle part où
  /// revenir, et une flèche de retour promettrait un écran précédent.
  final bool showBackButton;

  /// Hauteur réservée sous le composeur. Dans la coquille, la barre d'onglets
  /// flotte au-dessus du contenu : sans cette réserve, on écrirait derrière.
  final double bottomInset;

  /// Part de la colonne qu'une bulle peut occuper. Au-delà, on ne lit plus une
  /// conversation mais un document : il faut voir que le bord est libre en
  /// face pour comprendre qui parle.
  static const double _bubbleWidthFactor = 0.78;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            _CoachHeader(showBackButton: showBackButton),
            Expanded(
              child: messages.isEmpty
                  ? const _CoachIntro()
                  : LayoutBuilder(
                      builder: (context, constraints) => _Conversation(
                        messages: messages,
                        isSending: isSending,
                        maxBubbleWidth:
                            constraints.maxWidth * _bubbleWidthFactor,
                        onOpenProposal: onOpenProposal,
                      ),
                    ),
            ),
            if (notice case final text?) _CoachNotice(text: text),
            if (suggestions.isNotEmpty && !isOffline) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: CoachSuggestions(
                  suggestions: suggestions,
                  onSelected: onSend,
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.md + bottomInset,
              ),
              child: CoachComposer(
                controller: composerController,
                onSend: onSend,
                isOffline: isOffline,
                isSending: isSending,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.messages,
    required this.isSending,
    required this.maxBubbleWidth,
    required this.onOpenProposal,
  });

  final List<CoachMessage> messages;
  final bool isSending;
  final double maxBubbleWidth;
  final ValueChanged<CoachSessionProposal> onOpenProposal;

  @override
  Widget build(BuildContext context) {
    // `reverse` ancre la conversation EN BAS : c'est là qu'on lit, c'est là
    // qu'arrive la réponse, et une histoire courte ne flotte pas en haut d'un
    // écran vide. Le défilement remonte alors vers le passé, comme partout.
    final pending = isSending ? 1 : 0;

    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.md,
      ),
      itemCount: messages.length + pending,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (isSending && index == 0) {
          return const CoachTypingBubble();
        }

        // La liste est inversée : l'index 0 est le bas de l'écran.
        final message = messages[messages.length - 1 - (index - pending)];
        final proposal = message.proposal;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
}

/// Refus du serveur, posé juste au-dessus du composeur — là où l'on vient
/// d'appuyer, et non en haut d'un écran qu'on ne regarde plus.
class _CoachNotice extends StatelessWidget {
  const _CoachNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            AppIcons.info,
            size: 16,
            color: AppColors.darkTextTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachHeader extends StatelessWidget {
  const _CoachHeader({required this.showBackButton});

  final bool showBackButton;

  /// Le bouton de retour et son symétrique à droite : sans le second, le titre
  /// n'est pas centré sur la page mais sur ce qui reste.
  static const double _sideWidth = AppSpacing.touchTarget;
  static const double _markSize = 18;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: _sideWidth,
            child: showBackButton
                ? IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(AppIcons.back),
                    color: AppColors.darkTextSecondary,
                    tooltip: 'Retour',
                  )
                : null,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  AppIcons.coach,
                  size: _markSize,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Coach IA',
                  style: AppTypography.heading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _sideWidth),
        ],
      ),
    );
  }
}

/// Première ouverture : le coach dit ce qu'il sait faire plutôt que d'ouvrir
/// un champ vide sur lequel on ne sait pas quoi écrire.
class _CoachIntro extends StatelessWidget {
  const _CoachIntro();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: AppEmptyState(
          icon: AppIcons.coach,
          title: 'Ton coach est là',
          message: 'Pose-lui une question sur ta progression, ou demande-lui '
              'd’adapter ta séance à ton temps du jour.',
        ),
      ),
    );
  }
}
