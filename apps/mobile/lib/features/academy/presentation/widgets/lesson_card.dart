import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';
import 'lesson_illustration.dart';
import 'quiz_card.dart';

/// Une leçon dépliable : titre + catégorie repliés ; ouverte, elle déroule
/// l'illustration, le corps, l'essentiel à retenir, la question — et, pour
/// l'anatomie, le pont vers les exercices du muscle. La question vit DANS
/// la leçon : on lit, puis on se teste, puis on pratique.
class LessonCard extends StatefulWidget {
  const LessonCard({
    required this.lesson,
    this.showCategory = true,
    this.onAnswered,
    super.key,
  });

  final Lesson lesson;

  /// Relais de la réponse au quiz de CETTE leçon (défis culturels).
  final ValueChanged<bool>? onAnswered;

  /// À désactiver quand la carte est déjà rangée sous l'en-tête de sa
  /// catégorie : répéter « ANATOMIE » sous « ANATOMIE » n'apprend rien.
  final bool showCategory;

  @override
  State<LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<LessonCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showCategory) ...[
                        AppSectionLabel(lesson.category.label),
                        const SizedBox(height: AppSpacing.xxs),
                      ],
                      Text(
                        lesson.title,
                        style: AppTypography.subheading
                            .copyWith(color: AppColors.darkTextPrimary),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: AppMotion.fast,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Le contenu est RETIRÉ de l'arbre quand la leçon est repliée —
          // pas simplement masqué : une liste de leçons repliées ne paie
          // ni leurs textes, ni leurs images, ni leurs questions.
          if (_open) ...[
            const SizedBox(height: AppSpacing.sm),
            LessonIllustration(lesson: lesson),
            const SizedBox(height: AppSpacing.sm),
            Text(
              lesson.body,
              style: AppTypography.body
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
            if (lesson.points.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              const AppSectionLabel('À retenir'),
              const SizedBox(height: AppSpacing.xxs),
              for (final point in lesson.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          point,
                          style: AppTypography.label.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.sm),
            QuizCard(question: lesson.question, onAnswered: widget.onAnswered),
            // Le pont vers la pratique : la bibliothèque, déjà filtrée sur
            // le muscle qu'on vient d'apprendre.
            if (lesson.muscleGroupSlugs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: AppPill(
                  label: 'Voir les exercices de ce muscle',
                  tone: AppPillTone.accent,
                  onTap: () => context.push(
                    AppRoutes.exercisesForGroup(lesson.muscleGroupSlugs.first),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
