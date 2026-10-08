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
  const LessonIllustration({
    required this.lesson,
    this.thumbnailSize,
    super.key,
  });

  final Lesson lesson;

  /// Une vignette carrée de ce côté (la ligne repliée d'une leçon), rognée
  /// au centre. `null` : l'illustration entière, à son ratio.
  final double? thumbnailSize;

  @override
  Widget build(BuildContext context) {
    final image = lesson.image;
    final thumbnail = thumbnailSize;
    if (thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox.square(
          dimension: thumbnail,
          child: image == null
              ? _Fallback(lesson: lesson, compact: true)
              : Image.asset(
                  image,
                  fit: BoxFit.cover,
                  // Décodée à la taille de la vignette, pas à celle du
                  // fichier (800 pixels de large), rognée au carré par `cover` : une liste de leçons ne
                  // garde pas douze grandes images en mémoire.
                  cacheWidth:
                      (thumbnail *
                              MediaQuery.devicePixelRatioOf(context) *
                              lesson.imageRatio)
                          .round(),
                  errorBuilder: (_, __, ___) =>
                      _Fallback(lesson: lesson, compact: true),
                ),
        ),
      );
    }

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
  const _Fallback({required this.lesson, this.compact = false});

  final Lesson lesson;

  /// La vignette : une icône et une marge à sa mesure.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // La vignette du muscle n'est utilisée QUE pour le muscle enseigné —
    // `assetFor` refuse de substituer une autre image : une anatomie fausse
    // enseignerait une erreur.
    final vignette = lesson.muscleGroupSlugs.isEmpty
        ? null
        : MuscleGroupCard.assetFor(lesson.muscleGroupSlugs.first);
    final icon = Icon(
      academyCategoryIcon(lesson.category),
      size: compact ? 24 : 40,
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
              padding: EdgeInsets.all(compact ? AppSpacing.xxs : AppSpacing.sm),
              child: Image.asset(
                vignette,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(child: icon),
              ),
            ),
    );
  }
}

/// L'icône qui tient lieu d'illustration quand la leçon n'en déclare pas.
///
/// Le `switch` est EXHAUSTIF sans clause par défaut, et c'est une garde
/// volontaire : ajouter un domaine sans lui choisir d'icône ne compile pas.
IconData academyCategoryIcon(AcademyCategory category) => switch (category) {
  AcademyCategory.nutrition => AppIcons.nutrition,
  AcademyCategory.technique => AppIcons.exercises,
  AcademyCategory.cardio => AppIcons.lessonHeart,
  AcademyCategory.mobilite => AppIcons.voicePhilosophe,
  AcademyCategory.mental => AppIcons.spark,
  AcademyCategory.recuperation => AppIcons.recovery,
  AcademyCategory.blessures => AppIcons.lessonHealth,
  AcademyCategory.anatomie => AppIcons.workout,
  AcademyCategory.mythes => AppIcons.question,
  AcademyCategory.hyrox => AppIcons.spark,
  AcademyCategory.running => AppIcons.lessonCardio,
  AcademyCategory.calisthenics => AppIcons.lessonPosture,
};
