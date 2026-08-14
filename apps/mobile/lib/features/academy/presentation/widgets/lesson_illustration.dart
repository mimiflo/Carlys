import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../exercises/presentation/widgets/muscle_group_card.dart';
import '../../domain/entities/academy.dart';

/// Illustration d'une leçon, avec des replis en cascade — jamais un trou :
///
/// 1. l'illustration dédiée (`assets/academy/<id>.webp`) si elle est livrée ;
/// 2. pour l'anatomie, la vignette du muscle enseigné, déjà embarquée pour
///    la bibliothèque d'exercices — une vraie image dès aujourd'hui ;
/// 3. sinon, le dégradé de marque et l'icône du domaine.
class LessonIllustration extends StatelessWidget {
  const LessonIllustration({required this.lesson, super.key});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final image = lesson.image;

    // La boîte épouse le ratio RÉEL de l'illustration (déclaré par la
    // leçon) : l'image s'affiche entière — une hauteur fixe en rognait
    // le haut et le bas.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AspectRatio(
        aspectRatio: lesson.imageRatio,
        child: image == null
            ? _Fallback(lesson: lesson)
            : Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Fallback(lesson: lesson),
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    // La vignette du muscle n'est utilisée QUE pour le muscle enseigné —
    // `assetFor` refuse de substituer une autre image : une anatomie fausse
    // enseignerait une erreur.
    final vignette = lesson.muscleGroupSlugs.isEmpty
        ? null
        : MuscleGroupCard.assetFor(lesson.muscleGroupSlugs.first);
    final icon = Icon(
      _categoryIcon(lesson.category),
      size: 40,
      color: AppColors.primaryLight,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.neutral950],
        ),
      ),
      child: vignette == null
          ? Center(child: icon)
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Image.asset(
                vignette,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(child: icon),
              ),
            ),
    );
  }
}

IconData _categoryIcon(AcademyCategory category) => switch (category) {
      AcademyCategory.anatomie => AppIcons.workout,
      AcademyCategory.technique => AppIcons.exercises,
      AcademyCategory.nutrition => AppIcons.nutrition,
      AcademyCategory.recuperation => AppIcons.recovery,
    };
