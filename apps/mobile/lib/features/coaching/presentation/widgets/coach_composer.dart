import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'coach_notices.dart';

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
    required this.onRetry,
    this.onStop,
    this.isOffline = false,
    this.isSending = false,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool isOffline;

  /// Sortie de l'état hors ligne, offerte par l'encart qui le remplace.
  final VoidCallback onRetry;

  /// Un envoi est en cours : la saisie reste possible, l'envoi non — sinon
  /// deux questions partent avant la première réponse.
  final bool isSending;

  /// Arrête la réponse en cours. Pendant un envoi, le bouton d'envoi devient
  /// « Arrêter » : la génération s'arrête sur le serveur, la question reste.
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    if (isOffline) {
      return _OfflineNotice(onRetry: onRetry);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
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
              textAlignVertical: TextAlignVertical.center,
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
                // La marge est CELLE DU CHAMP, pas du conteneur : toute la
                // pilule répond au doigt. Posée sur le conteneur, elle
                // laissait un champ de 19 points au milieu d'une pilule
                // qui, autour, ne faisait rien.
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.touchTarget,
                ),
                hintText: 'Pose ta question…',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        if (isSending && onStop != null)
          _RoundButton(icon: AppIcons.stop, label: 'Arrêter', onPressed: onStop)
        else
          _RoundButton(
            icon: AppIcons.send,
            label: 'Envoyer',
            onPressed: isSending ? null : () => onSend(controller.text),
          ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Diamètre du DISQUE, ce qui se voit. La zone qui répond au doigt est
  /// [AppSpacing.touchTarget], centrée dessus.
  static const double _discDiameter = 40;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      label: label,
      // `enabled` ET `onTap` : sans le second, le nœud s'annonce comme un
      // bouton mais ne publie aucune action, et l'activer depuis un lecteur
      // d'écran ne fait rien. `enabled` dit en plus que l'envoi est en cours,
      // au lieu de laisser réessayer dans le vide.
      enabled: enabled,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: Center(
              child: Container(
                width: _discDiameter,
                height: _discDiameter,
                decoration: BoxDecoration(
                  // Le dégradé d'action (celui du login) quand on peut
                  // envoyer ; un violet plat tamisé quand c'est désactivé.
                  gradient: enabled ? AppColors.cta : null,
                  color: enabled
                      ? null
                      : AppColors.primary.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppColors.neutral0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'état hors ligne du coach, AVEC sa porte de sortie.
///
/// Sans ce bouton, la carte remplaçait le champ de saisie et les
/// suggestions sans rien offrir : le seul chemin qui relève le drapeau
/// passe par un envoi, devenu impossible. Le réseau revenu, l'écran
/// continuait d'affirmer le contraire.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.padCard),
      // Liseré orange : un état à surveiller, pas une erreur.
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.all(color: AppColors.accentBadgeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            container: true,
            child: CoachNoticeHeading(
              icon: AppIcons.connectionLost,
              title: 'Connexion perdue',
              message:
                  'Le coach a besoin d’une connexion. Ton historique reste '
                  'lisible.',
              warning: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Réessayer',
            icon: AppIcons.retry,
            semanticLabel: 'Réessayer, revenir à la saisie',
            variant: AppButtonVariant.secondary,
            onPressed: onRetry,
            isExpanded: true,
          ),
        ],
      ),
    );
  }
}
