import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// L'illustration de chaque étape : une scène de nuit violette par pièce,
/// tirée des maquettes du propriétaire (octobre 2026), au format 7:3.
/// Comme les icônes, la table vit dans la présentation, et un test vérifie
/// qu'elle couvre chaque étape du manifeste.
const Map<String, String> mentorTourIllustrations = {
  'accueil': 'assets/illustrations/visite_accueil.webp',
  'entrainement': 'assets/illustrations/visite_entrainement.webp',
  'nutrition': 'assets/illustrations/visite_nutrition.webp',
  'progres': 'assets/illustrations/visite_progres.webp',
  'academy': 'assets/illustrations/visite_academy.webp',
  'communaute': 'assets/illustrations/visite_communaute.webp',
  'coach': 'assets/illustrations/visite_coach.webp',
};

/// La scène de fin : le sommet atteint.
const String mentorTourFinIllustration =
    'assets/illustrations/visite_terminee.webp';

/// La carte d'une étape : l'illustration, le titre, le propos, centrés.
///
/// Les illustrations portent leur propre fondu (canal alpha) : elles se
/// posent sur la surface de la carte sans bord visible. Décoratives pour un
/// lecteur d'écran, le titre dit déjà ce qu'elles montrent. [action] se
/// pose dans le coin haut droit (le bouton « écouter » du Mentor).
class MentorTourCard extends StatelessWidget {
  const MentorTourCard({
    required this.illustration,
    required this.titre,
    required this.corps,
    this.action,
    super.key,
  });

  final String illustration;
  final String titre;
  final String corps;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: AspectRatio(
                  aspectRatio: 7 / 3,
                  child: Image.asset(
                    illustration,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                titre,
                textAlign: TextAlign.center,
                style: AppTypography.title.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                corps,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          if (action != null) Positioned(top: 0, right: 0, child: action!),
        ],
      ),
    );
  }
}
