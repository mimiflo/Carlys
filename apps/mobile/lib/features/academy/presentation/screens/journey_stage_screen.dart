import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/academy_journey.dart';
import '../controllers/academy_controllers.dart';
import '../widgets/lesson_card.dart';

/// Une étape du Parcours : ses leçons dans l'ordre du manifeste, à lire et
/// à valider une à une — les MÊMES cartes que partout dans l'Academy, la
/// réponse est la même donnée.
///
/// La validation de l'étape se constate au franchissement, comme le domaine
/// bouclé : un bandeau, une fois, jamais rejoué à la réouverture.
class JourneyStageScreen extends ConsumerStatefulWidget {
  const JourneyStageScreen({required this.rang, super.key});

  /// Rang de l'étape (1 à 6), tel que l'URL le porte.
  final int rang;

  @override
  ConsumerState<JourneyStageScreen> createState() => _JourneyStageScreenState();
}

class _JourneyStageScreenState extends ConsumerState<JourneyStageScreen> {
  /// L'étape vient-elle d'être VALIDÉE par une réponse donnée ici ?
  /// Événement d'écran, local — comme la fête d'un domaine bouclé.
  bool _validee = false;

  JourneyStage? get _stage =>
      academyJourney.where((stage) => stage.rang == widget.rang).firstOrNull;

  Future<void> _repondre({
    required String lessonId,
    required int choiceIndex,
    required bool correct,
  }) async {
    // Le franchissement se décide AVANT l'écriture, sur ce qu'on sait déjà :
    // relire le provider juste après l'invalidation ferait la course avec la
    // lecture asynchrone du magasin, et une course qui rate une fête ne se
    // voit qu'en production.
    final stage = _stage!;
    final answeredAvant =
        ref.read(answeredLessonsProvider).valueOrNull ?? const {};
    final packIds =
        ref
            .read(academyPackProvider)
            .valueOrNull
            ?.map((lesson) => lesson.id)
            .toSet() ??
        const <String>{};
    final restantes = stage.lessonIds
        .where(packIds.contains)
        .where((id) => !answeredAvant.containsKey(id))
        .toList();
    final franchit = restantes.length == 1 && restantes.single == lessonId;

    await ref
        .read(academyActionsProvider)
        .answer(lessonId: lessonId, choiceIndex: choiceIndex, correct: correct);
    if (!mounted || !franchit) {
      return;
    }
    setState(() => _validee = true);
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    final pack = ref.watch(academyPackProvider);
    final answered = ref.watch(answeredLessonsProvider).valueOrNull ?? const {};
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AppDarkScaffold(
      appBar: AppBar(
        title: Text(
          stage == null ? 'Parcours' : 'Étape ${stage.rang} · ${stage.nom}',
        ),
      ),
      body: stage == null
          ? const AppEmptyState(
              title: 'Étape introuvable',
              message: 'Le parcours compte six étapes.',
            )
          : pack.when(
              loading: () => const AppLoadingIndicator(),
              error: (error, _) => AppErrorState(
                title: 'Étape indisponible',
                message: 'Le contenu d’apprentissage n’a pas pu être chargé.',
                onRetry: () => ref.invalidate(academyPackProvider),
              ),
              data: (lessons) {
                // L'ordre du manifeste, restreint à ce que le pack sert.
                final duParcours = [
                  for (final id in stage.lessonIds)
                    ...lessons.where((lesson) => lesson.id == id),
                ];
                if (duParcours.isEmpty) {
                  return const AppEmptyState(
                    title: 'Rien à lire ici',
                    message: 'Cette étape n’a plus de leçons servies.',
                  );
                }
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    bottomInset + AppSpacing.gapSection,
                  ),
                  children: [
                    Text(
                      stage.description,
                      style: AppTypography.body.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.gapRow),
                    if (_validee) ...[
                      _EtapeValidee(
                        nom: stage.nom,
                        onDismiss: () => setState(() => _validee = false),
                      ),
                      const SizedBox(height: AppSpacing.gapRow),
                    ],
                    for (final lesson in duParcours) ...[
                      LessonCard(
                        lesson: lesson,
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
                );
              },
            ),
    );
  }
}

/// Le bandeau de validation : la grammaire du domaine bouclé, au format de
/// l'étape.
class _EtapeValidee extends StatelessWidget {
  const _EtapeValidee({required this.nom, required this.onDismiss});

  final String nom;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.padCard),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: const Border.fromBorderSide(
          BorderSide(color: AppColors.accent),
        ),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.checkCircle, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Étape validée : $nom. La suivante t’attend sur le parcours.',
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(
              AppIcons.close,
              size: 18,
              color: AppColors.darkTextTertiary,
            ),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }
}
