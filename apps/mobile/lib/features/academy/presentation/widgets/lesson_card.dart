import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';
import 'quiz_card.dart';

/// Une leçon dépliable : titre + catégorie repliés, corps et question une
/// fois ouverte. La question vit DANS la leçon — on lit, puis on se teste.
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
          // ni leurs textes ni leurs questions.
          if (_open) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              lesson.body,
              style: AppTypography.body
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            QuizCard(question: lesson.question, onAnswered: widget.onAnswered),
          ],
        ],
      ),
    );
  }
}
