/// Les deux lignes discrètes de l'écran du coach : d'où vient la réponse
/// (en tête de fil) et pourquoi un envoi vient d'être refusé (au-dessus du
/// composeur). Même famille, même sobriété, même fichier.
library;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

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
class CoachNotice extends StatelessWidget {
  const CoachNotice({required this.text, super.key});

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
