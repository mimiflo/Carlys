import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';
import 'lesson_illustration.dart';
import 'lesson_key_points.dart';
import 'quiz_card.dart';

/// Une leçon dépliable : vignette, titre et état repliés ; ouverte, elle déroule
/// l'illustration, le corps, l'essentiel à retenir, la question — et, pour
/// l'anatomie, le pont vers les exercices du muscle. La question vit DANS
/// la leçon : on lit, puis on se teste, puis on pratique.
class LessonCard extends StatefulWidget {
  const LessonCard({
    required this.lesson,
    this.showCategory = true,
    this.answeredChoice,
    this.onAnswered,
    super.key,
  });

  final Lesson lesson;

  /// Choix déjà retenu pour cette leçon, s'il y en a un : c'est ce qui
  /// remplit la carte quand on a répondu depuis l'accueil.
  final int? answeredChoice;

  /// Relais de la réponse au quiz de CETTE leçon : l'index choisi et s'il
  /// est juste.
  final void Function(int choiceIndex, bool correct)? onAnswered;

  /// À désactiver quand la carte est déjà rangée sous l'en-tête de sa
  /// catégorie : répéter « ANATOMIE » sous « ANATOMIE » n'apprend rien.
  final bool showCategory;

  @override
  State<LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<LessonCard> {
  bool _open = false;

  static const double _thumbnailSize = 56;
  static const double _openIconSize = 28;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Row(
                children: [
                  // La vignette cède au livre quand la leçon s'ouvre : son
                  // illustration entière prend le relais juste dessous.
                  if (_open)
                    const Icon(
                      AppIcons.lessonOpen,
                      size: _openIconSize,
                      color: AppColors.primaryLight,
                    )
                  else
                    LessonIllustration(
                      lesson: lesson,
                      thumbnailSize: _thumbnailSize,
                    ),
                  const SizedBox(width: AppSpacing.sm),
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
                          style: AppTypography.subheading.copyWith(
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          widget.answeredChoice == null
                              ? 'À lire, puis une question'
                              : 'Lue · question répondue',
                          style: AppTypography.label.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: AppMotion.fast,
                    child: const Icon(
                      AppIcons.expand,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Le contenu est RETIRÉ de l'arbre quand la leçon est repliée —
          // pas simplement masqué : une liste de leçons repliées ne paie
          // ni leurs textes, ni leurs images, ni leurs questions.
          if (_open) ...[
            const SizedBox(height: AppSpacing.sm),
            LessonIllustration(lesson: lesson),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                'Comprendre le principe',
                style: AppTypography.heading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              lesson.body,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
            if (lesson.points.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              LessonKeyPoints(points: lesson.points),
            ],
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.rowDivider),
            const SizedBox(height: AppSpacing.md),
            QuizCard(
              question: lesson.question,
              title: 'À toi de jouer',
              embedded: true,
              // Une leçon ne se rejoue pas le lendemain : la tentative est
              // unique, pas quotidienne.
              hint: 'Choisis, puis valide : une seule tentative.',
              answeredChoice: widget.answeredChoice,
              onAnswered: widget.onAnswered,
            ),
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
