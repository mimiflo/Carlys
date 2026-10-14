import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/mentor_tour.dart';

/// L'image de chaque étape : le même dessin que la pièce qu'elle présente.
/// La table vit ICI, pas dans le manifeste (le domaine ne connaît pas les
/// icônes), et un test vérifie qu'elle couvre chaque étape.
const Map<String, IconData> mentorTourIcons = {
  'accueil': AppIcons.home,
  'entrainement': AppIcons.workout,
  'nutrition': AppIcons.nutrition,
  'progres': AppIcons.progress,
  'academy': AppIcons.brandAcademy,
  'communaute': AppIcons.community,
  'coach': AppIcons.coach,
};

/// Le chemin de la visite : les sept pièces en pastilles, d'un coup d'œil.
///
/// Trois états, du plus discret au plus visible : à venir (éteinte), vue
/// (icône violette et coche), courante (dégradé violet `cta`). Purement décoratif
/// pour un lecteur d'écran : l'en-tête « x sur 7 » dit déjà l'avancement.
class MentorTourChemin extends StatelessWidget {
  const MentorTourChemin({required this.vues, this.etapeCourante, super.key});

  /// Identifiants des étapes déjà vues.
  final Set<String> vues;

  /// Identifiant de l'étape en cours, `null` quand la visite est terminée.
  final String? etapeCourante;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final step in mentorTour)
            _Pastille(
              icon: mentorTourIcons[step.id] ?? AppIcons.mentor,
              vue: vues.contains(step.id),
              courante: step.id == etapeCourante,
            ),
        ],
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.icon,
    required this.vue,
    required this.courante,
  });

  final IconData icon;
  final bool vue;
  final bool courante;

  @override
  Widget build(BuildContext context) {
    final pastille = Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: courante ? AppColors.cta : null,
        color: courante ? null : AppColors.darkSurfaceAlt,
        border: courante ? null : Border.all(color: AppColors.darkBorder),
      ),
      child: Icon(
        icon,
        size: 20,
        color: courante
            ? AppColors.neutral0
            : (vue ? AppColors.primaryLight : AppColors.darkIconInactive),
      ),
    );
    if (!vue || courante) return pastille;
    // Une pièce vue porte sa coche, comme sur la maquette.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        pastille,
        Positioned(
          top: -AppSpacing.xxs,
          right: -AppSpacing.xxs,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xxs / 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(
                color: AppColors.darkSurface,
                width: AppSpacing.xxs / 2,
              ),
            ),
            child: const Icon(
              AppIcons.check,
              size: 10,
              color: AppColors.neutral0,
            ),
          ),
        ),
      ],
    );
  }
}
