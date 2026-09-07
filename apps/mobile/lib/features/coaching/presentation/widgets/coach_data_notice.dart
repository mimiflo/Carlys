import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// En tête de conversation : d'où vient la réponse du coach.
///
/// Le coach lit les séances, les records et les mesures pour répondre, et
/// c'est un prestataire externe qui produit le texte. La politique de
/// confidentialité le dit ; il faut aussi le dire LÀ, au moment où l'on
/// commence à écrire, pas seulement dans un document que personne n'ouvre.
///
/// Volontairement sobre et non actionnable : ce n'est ni une alerte ni un
/// consentement à donner (l'usage du coach relève du contrat), c'est un fait
/// posé une fois, au-dessus du premier message du fil.
class CoachDataNotice extends StatelessWidget {
  const CoachDataNotice({super.key});

  static const String message =
      'Tes données d’entraînement citées ici sont traitées par un prestataire '
      'externe pour produire la réponse.';

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
