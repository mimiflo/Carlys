import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/academy_journey.dart';
import '../../domain/academy_progress.dart';
import '../../domain/entities/academy.dart';
import '../providers/academy_progress_providers.dart';
import '../providers/academy_providers.dart';
import '../widgets/academy_domain_bar.dart';
import '../widgets/academy_domain_header.dart';
import '../widgets/academy_domain_sheet.dart';
import '../widgets/academy_progress_card.dart';
import '../widgets/domain_completed_banner.dart';
import '../widgets/journey_entry_card.dart';
import '../widgets/lesson_card.dart';
import '../widgets/quiz_card.dart';

/// Academy — apprendre, et comprendre ce qu'on fait à l'entraînement.
///
/// Maquette d'octobre 2026, de haut en bas : la progression et ses
/// médailles, le parcours guidé, les domaines à explorer, la question du
/// jour (la même que sur l'accueil), puis les leçons de chaque domaine.
/// Le contenu est éditorial et embarqué : l'Academy fonctionne hors ligne,
/// comme le reste de l'application.
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

  /// Domaine tout juste bouclé, à fêter une fois. Local, comme le filtre :
  /// c'est un événement d'écran, pas une donnée partagée.
  AcademyCategory? _aFeter;

  @override
  void initState() {
    super.initState();
    // Les réponses données sur un AUTRE appareil comblent le magasin local,
    // en meilleur effort : hors ligne, l'Academy s'ouvre exactement pareil.
    Future.microtask(() => ref.read(academyActionsProvider).pullAnswers());
  }

  /// Enregistre une réponse, puis regarde si elle vient de BOUCLER un
  /// domaine.
  ///
  /// La comparaison avant/après se fait ici et pas dans l'état final :
  /// rouvrir l'écran d'un domaine déjà terminé ne doit rien rejouer.
  Future<void> _repondre({
    required String lessonId,
    required int choiceIndex,
    required bool correct,
  }) async {
    final avant = ref.read(academyProgressProvider);
    await ref
        .read(academyActionsProvider)
        .answer(lessonId: lessonId, choiceIndex: choiceIndex, correct: correct);
    if (!mounted || avant == null) {
      return;
    }
    final apres = ref.read(academyProgressProvider);
    if (apres == null) {
      return;
    }
    final acheve = domaineAcheve(avant: avant, apres: apres);
    if (acheve != null) {
      setState(() => _aFeter = acheve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(academyPackProvider);
    final daily = ref.watch(dailyLessonProvider);
    final progress = ref.watch(academyProgressProvider);
    final journey = ref.watch(academyJourneyProgressProvider);
    // Les réponses déjà données, d'où qu'elles viennent : la question du
    // jour répondue sur l'accueil arrive ici déjà remplie.
    final answered = ref.watch(answeredLessonsProvider).valueOrNull ?? const {};
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
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
        data: (lessons) {
          int countOf(AcademyCategory category) =>
              lessons.where((lesson) => lesson.category == category).length;
          // Les domaines servis : un domaine vide ne s'annonce pas.
          final domaines = AcademyCategory.values
              .where((category) => countOf(category) > 0)
              .toList();
          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              MediaQuery.paddingOf(context).top + AppSpacing.gapSection,
              AppSpacing.gutter,
              bottomInset + AppSpacing.gapSection,
            ),
            children: [
              AppScreenHeader(
                title: 'Academy',
                tagline: 'Comprendre pour progresser.',
                showBack: false,
                actions: [
                  AppRoundIconButton(
                    icon: AppIcons.brandAcademy,
                    tooltip: 'Parcours guidé',
                    onPressed: () => context.push(AppRoutes.academyJourney),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_aFeter != null) ...[
                DomainCompletedBanner(
                  domaine: _aFeter!,
                  onDismiss: () => setState(() => _aFeter = null),
                ),
                const SizedBox(height: AppSpacing.gapRow),
              ],
              if (progress != null) ...[
                AcademyProgressCard(progress: progress),
                const SizedBox(height: AppSpacing.gapRow),
              ],
              if (journey != null) ...[
                JourneyEntryCard(
                  progress: journey,
                  onOpen: () => context.push(AppRoutes.academyJourney),
                  onResume: () {
                    final courante = journey.etapeCourante;
                    if (courante != null) {
                      context.push(
                        AppRoutes.academyJourneyStage(
                          academyJourney[courante].rang,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.gapRow),
              ],
              AppSectionHeader(
                title: 'Explorer les domaines',
                trailing: 'Voir les ${domaines.length}',
                trailingTone: AppSectionTrailingTone.primary,
                onTrailingTap: () async {
                  final choisi = await pickAcademyDomain(
                    context,
                    domaines: domaines,
                    selected: _domaine,
                    countOf: countOf,
                  );
                  if (choisi != null && mounted) {
                    setState(() => _domaine = choisi);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              AcademyDomainBar(
                domaines: domaines,
                selected: _domaine,
                onSelect: (domaine) => setState(() => _domaine = domaine),
                countOf: countOf,
                readOf: (category) => progress?.parDomaine[category]?.abordees,
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
                  onAnswered: (choice, correct) => _repondre(
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
                // L'en-tête reste même sur un domaine choisi : il ne répète
                // plus seulement le nom que la pastille active porte déjà, il
                // dit où en est la lecture de CE domaine.
                AcademyDomainHeader(
                  category: category,
                  progress: progress?.parDomaine[category],
                  onQuiz: () =>
                      context.push(AppRoutes.academyDomainQuiz(category.name)),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final lesson in lessons.where(
                  (lesson) => lesson.category == category,
                )) ...[
                  LessonCard(
                    lesson: lesson,
                    showCategory: false,
                    answeredChoice: answered[lesson.id],
                    onAnswered: (choice, correct) => _repondre(
                      lessonId: lesson.id,
                      choiceIndex: choice,
                      correct: correct,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gapRow),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
