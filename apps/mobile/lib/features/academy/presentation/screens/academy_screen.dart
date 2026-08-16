import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';
import '../controllers/academy_controllers.dart';
import '../widgets/lesson_card.dart';
import '../widgets/quiz_card.dart';

/// Academy — apprendre, et comprendre ce qu'on fait à l'entraînement.
///
/// Trois étages : la question du jour (la même que sur l'accueil), la
/// nutrition — intégrée ici plutôt qu'en sixième onglet —, puis les leçons
/// par domaine. Le contenu est éditorial et embarqué : l'Academy fonctionne
/// hors ligne, comme le reste de l'application.
class AcademyScreen extends ConsumerWidget {
  const AcademyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(academyPackProvider);
    final daily = ref.watch(dailyLessonProvider);
    final actions = ref.read(academyActionsProvider);
    // Les réponses déjà données, d'où qu'elles viennent : la question du
    // jour répondue sur l'accueil arrive ici déjà remplie.
    final answered = ref.watch(answeredLessonsProvider).valueOrNull ?? const {};
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: pack.when(
        loading: () => const AppLoadingIndicator(),
        error: (error, _) => const AppErrorState(
          title: 'Academy indisponible',
          message: 'Le contenu d’apprentissage n’a pas pu être chargé.',
        ),
        data: (lessons) => ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            MediaQuery.paddingOf(context).top + AppSpacing.gapSection,
            AppSpacing.gutter,
            bottomInset + AppSpacing.gapSection,
          ),
          children: [
            Text(
              'Academy',
              style: AppTypography.display
                  .copyWith(color: AppColors.darkTextPrimary),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Comprendre, c’est progresser deux fois.',
              style: AppTypography.body
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: AppSpacing.gapRow),
            if (daily != null) ...[
              QuizCard(
                question: daily.question,
                title: 'Question du jour',
                // La réponse est notée sur l'appareil (axe « Maîtrise » du
                // profil de progression) puis rejoint les défis culturels,
                // sans jamais gêner le quiz, qui fonctionne hors ligne.
                answeredChoice: answered[daily.id],
                onAnswered: (choice, correct) => actions.answer(
                  lessonId: daily.id,
                  choiceIndex: choice,
                  correct: correct,
                ),
              ),
              const SizedBox(height: AppSpacing.gapRow),
            ],
            _NutritionEntry(
              onOpen: () => context.push(AppRoutes.nutrition),
            ),
            const SizedBox(height: AppSpacing.gapSection),
            for (final category in AcademyCategory.values) ...[
              AppSectionLabel(category.label),
              const SizedBox(height: AppSpacing.xs),
              for (final lesson in lessons
                  .where((lesson) => lesson.category == category)) ...[
                LessonCard(
                  lesson: lesson,
                  showCategory: false,
                  answeredChoice: answered[lesson.id],
                  onAnswered: (choice, correct) => actions.answer(
                    lessonId: lesson.id,
                    choiceIndex: choice,
                    correct: correct,
                  ),
                ),
                const SizedBox(height: AppSpacing.gapRow),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// La porte d'entrée vers la nutrition : métabolisme, objectifs, macros.
class _NutritionEntry extends StatelessWidget {
  const _NutritionEntry({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      child: Row(
        children: [
          const Icon(AppIcons.nutrition, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nutrition',
                  style: AppTypography.subheading
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                Text(
                  'Métabolisme, objectifs caloriques et macros.',
                  style: AppTypography.body
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.darkTextTertiary,
          ),
        ],
      ),
    );
  }
}
