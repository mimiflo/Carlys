import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';
import '../controllers/academy_controllers.dart';
import '../widgets/academy_domain_bar.dart';
import '../widgets/lesson_card.dart';
import '../widgets/quiz_card.dart';

/// Academy — apprendre, et comprendre ce qu'on fait à l'entraînement.
///
/// Trois étages : la question du jour (la même que sur l'accueil), la barre
/// des domaines, puis les leçons. Le contenu est éditorial et embarqué :
/// l'Academy fonctionne hors ligne, comme le reste de l'application.
class AcademyScreen extends ConsumerStatefulWidget {
  const AcademyScreen({super.key});

  @override
  ConsumerState<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends ConsumerState<AcademyScreen> {
  /// Domaine affiché, `null` pour « Tous ».
  ///
  /// État LOCAL et non provider : c'est une préférence d'affichage, propre à
  /// cette visite de l'écran, que rien d'autre ne lit. La promouvoir en
  /// provider créerait une donnée partagée là où il n'y a qu'un filtre.
  AcademyCategory? _domaine;

  @override
  Widget build(BuildContext context) {
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
        // `academyPackProvider` n'est pas `autoDispose` : sans reprise, un
        // unique échec de lecture resterait mémoïsé et l'Academy serait morte
        // jusqu'à la fin de la session, même après avoir quitté l'écran. Le
        // chargeur, lui, sait réessayer : il ne mémoïse jamais une future en
        // échec.
        error: (error, _) => AppErrorState(
          title: 'Academy indisponible',
          message: 'Le contenu d’apprentissage n’a pas pu être chargé.',
          onRetry: () => ref.invalidate(academyPackProvider),
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
              style: AppTypography.display.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Comprendre, c’est progresser deux fois.',
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.gapRow),
            AcademyDomainBar(
              selected: _domaine,
              onSelect: (domaine) => setState(() => _domaine = domaine),
              countOf: (category) =>
                  lessons.where((lesson) => lesson.category == category).length,
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
            // « Tous » déroule les douze sections ; un domaine choisi n'en
            // montre qu'une, et l'en-tête disparaît alors : la pastille
            // active le dit déjà, le répéter ne fait que pousser la première
            // leçon vers le bas.
            for (final category in AcademyCategory.values.where(
              (category) => _domaine == null || category == _domaine,
            )) ...[
              if (_domaine == null) ...[
                AppSectionLabel(category.label),
                const SizedBox(height: AppSpacing.xs),
              ],
              for (final lesson in lessons.where(
                (lesson) => lesson.category == category,
              )) ...[
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
