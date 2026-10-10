/// Les deux avis de l'écran du coach : d'où vient la réponse (en tête de
/// fil) et pourquoi un envoi vient d'être refusé (au-dessus du composeur).
library;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach_thread_state.dart';

/// En tête de conversation : d'où vient la réponse du coach.
///
/// Le coach lit les séances, les records et les mesures pour répondre, et
/// depuis septembre 2026 c'est un modèle que Carlys fait tourner sur SON
/// serveur (ADR 0011) : ces données ne partent chez aucun prestataire. La
/// politique de confidentialité le dit ; il faut aussi le dire LÀ, au moment
/// où l'on commence à écrire, pas seulement dans un document que personne
/// n'ouvre. Si le coach repartait un jour chez un prestataire, cette phrase
/// changerait avec lui.
///
/// Volontairement sobre et non actionnable : ce n'est ni une alerte ni un
/// consentement à donner (l'usage du coach relève du contrat), c'est un fait
/// posé une fois, au-dessus du premier message du fil.
class CoachDataNotice extends StatelessWidget {
  const CoachDataNotice({super.key});

  static const String message =
      'Tes données d’entraînement citées ici restent sur les serveurs de '
      'Carlys : c’est là que le coach produit sa réponse.';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            AppIcons.info,
            size: 14,
            color: AppColors.darkTextTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Refus du serveur, posé juste au-dessus du composeur — là où l'on vient
/// d'appuyer, et non en haut d'un écran qu'on ne regarde plus.
///
/// Le titre et l'icône disent la NATURE du refus ; la phrase reste celle du
/// serveur, écrite pour la personne. « Ta question est conservée » ne se
/// dit que si elle l'est : un envoi refusé remet son texte dans le champ
/// (`CoachPage._send`), une reprise refusée au retour, non.
class CoachNotice extends StatelessWidget {
  const CoachNotice({
    required this.refusal,
    required this.questionKept,
    super.key,
  });

  final CoachRefusal refusal;
  final bool questionKept;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (refusal.kind) {
      // Plafond du jour ou rafale de la minute : le serveur dit lequel.
      CoachRefusalKind.limit => (AppIcons.time, 'Limite atteinte'),
      CoachRefusalKind.pending => (AppIcons.coach, 'Réponse en cours'),
      CoachRefusalKind.busy => (AppIcons.time, 'Coach très sollicité'),
      CoachRefusalKind.paused => (AppIcons.coachPaused, 'Coach en pause'),
      CoachRefusalKind.failed => (AppIcons.info, 'Réponse impossible'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.sm,
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoachNoticeHeading(
                icon: icon,
                title: title,
                message: refusal.message,
                warning: refusal.kind == CoachRefusalKind.limit,
              ),
              if (questionKept) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.rowDivider),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      AppIcons.coachStepDone,
                      size: 16,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Ta question est conservée.',
                      style: AppTypography.label.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// La ligne pastille, titre et phrase des cartes du coach : refus, hors
/// ligne, avantages de Premium.
class CoachNoticeHeading extends StatelessWidget {
  const CoachNoticeHeading({
    required this.icon,
    required this.title,
    required this.message,
    this.warning = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Orange : un état à surveiller (plafond, connexion), pas une erreur.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconBadge(
          icon: icon,
          size: 40,
          color: warning ? AppColors.accent : AppColors.primaryLight,
          background: warning
              ? AppColors.accentBadgeBg
              : AppColors.primaryBadgeBg,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                message,
                style: AppTypography.body.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
