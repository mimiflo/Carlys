import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Barre de saisie du coach.
///
/// **Seul endroit de l'application qui n'écrit pas hors ligne**, et c'est
/// délibéré : une question posée sans réseau recevrait sa réponse des heures
/// plus tard, ce qui n'est plus une conversation. L'historique, lui, reste
/// lisible. L'état hors ligne le dit au lieu de laisser un envoi échouer.
class CoachComposer extends StatelessWidget {
  const CoachComposer({
    required this.controller,
    required this.onSend,
    this.isOffline = false,
    this.isSending = false,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool isOffline;

  /// Un envoi est en cours : la saisie reste possible, l'envoi non — sinon
  /// deux questions partent avant la première réponse.
  final bool isSending;

  static const double _sendSize = 40;

  @override
  Widget build(BuildContext context) {
    if (isOffline) {
      return const _OfflineNotice();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            // Ni liseré, ni angle : sur fond sombre, un contour dessine une
            // boîte autour du champ au lieu de le poser dessus. La surface
            // seule suffit à dire où l'on écrit, et la forme stadium
            // s'accorde au bouton d'envoi qui la jouxte.
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.fullAll,
            ),
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: isSending ? null : onSend,
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextPrimary,
              ),
              cursorColor: AppColors.primaryLight,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                // Le thème remplit les champs de saisie et leur pose un
                // rectangle de fond. Ici la surface est déjà celle du
                // conteneur, en forme de stade : sans ces deux lignes, le
                // remplissage du thème dessine un rectangle à angles vifs
                // À L'INTÉRIEUR de la pilule, et sa marge s'ajoute à celle
                // du conteneur.
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: 'Pose ta question…',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _SendButton(
          onPressed: isSending ? null : () => onSend(controller.text),
        ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      label: 'Envoyer',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: CoachComposer._sendSize,
            height: CoachComposer._sendSize,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.send,
              size: 20,
              color: AppColors.neutral0,
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      // Même traitement que le champ de saisie qu'il remplace : la barre garde
      // sa place et sa forme, seul son contenu change.
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        children: [
          const Icon(
            AppIcons.offline,
            size: 18,
            color: AppColors.darkTextTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Le coach a besoin d’une connexion. Ton historique reste lisible.',
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
