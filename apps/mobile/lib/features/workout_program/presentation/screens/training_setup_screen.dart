import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/training_profile.dart';
import '../providers/training_goal_providers.dart';
import '../providers/training_profile_providers.dart';
import '../widgets/choice_tiles.dart';
import '../widgets/experience_sheet.dart';
import '../widgets/setup_summary_card.dart';
import '../widgets/training_equipment_section.dart';
import '../widgets/training_goal_sheet.dart';
import '../widgets/training_setup_sections.dart';

/// « Préparer mon programme » : les objectifs d'entraînement en un écran —
/// objectif, expérience, rythme, matériel. Chaque geste écrit SON champ au
/// serveur puis relit : l'écran reflète toujours l'état serveur.
///
/// Aucun bouton « Générer » : ces réponses servent à l'appli entière (le
/// coach les lit pour composer une séance ou un programme), pas à un seul
/// geste de cet écran.
class TrainingSetupScreen extends ConsumerWidget {
  const TrainingSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(trainingProfileProvider);
    // `valueOrNull` GARDE la dernière valeur pendant un rafraîchissement :
    // chaque écriture invalide le provider, et sans cette lecture l'écran
    // entier clignoterait en chargement à chaque geste.
    final value = profile.valueOrNull;
    final goal = ref.watch(currentTrainingGoalProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch ((value, profile)) {
          (final TrainingProfile value, _) => ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.gutter,
              AppSpacing.gutter,
              bottomInset + AppSpacing.gapSection,
            ),
            children: [
              const AppScreenHeader.centered(
                title: 'Préparer mon programme',
                tagline: 'Un programme à ton image',
              ),
              const SizedBox(height: AppSpacing.gapRow),
              // L'objectif vient de `AuthUser` (rafraîchi par sa feuille),
              // jamais d'une copie locale qui divergerait.
              SetupSummaryCard(
                icon: AppIcons.goal,
                title: goal?.label ?? 'Choisir mon objectif',
                description: goal?.description ?? 'Le pourquoi de tes séances.',
                semanticLabel:
                    'Ton objectif : ${goal?.label ?? 'à choisir'}. Modifier',
                onTap: () => showTrainingGoalSheet(context),
              ),
              const SizedBox(height: AppSpacing.gapRow),
              SetupSummaryCard(
                icon: AppIcons.statistics,
                title: value.experience?.label ?? 'Choisir mon niveau',
                description:
                    value.experience?.description ??
                    'Débutant, intermédiaire ou avancé.',
                semanticLabel:
                    'Ton expérience : ${value.experience?.label ?? 'à choisir'}. Modifier',
                onTap: () async {
                  final experience = await showExperienceSheet(
                    context,
                    current: value.experience,
                  );
                  if (experience == null || !context.mounted) return;
                  await _ecrire(
                    context,
                    ref,
                    () => ref
                        .read(trainingProfileActionsProvider)
                        .setExperience(experience),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.gapRow),
              AppTitledCard(
                icon: AppIcons.calendar,
                title: 'Séances par semaine',
                child: ChoiceTiles(
                  choices: weeklySessionsChoices,
                  current: value.weeklySessionsTarget,
                  labelOf: (sessions) => '$sessions',
                  onChoose: (sessions) => _ecrire(
                    context,
                    ref,
                    () => ref
                        .read(trainingProfileActionsProvider)
                        .setWeeklySessions(sessions),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.gapRow),
              AppTitledCard(
                icon: AppIcons.time,
                title: 'Durée d’une séance',
                child: ChoiceTiles(
                  choices: sessionMinutesChoices,
                  current: value.sessionMinutesTarget,
                  labelOf: (minutes) => '$minutes min',
                  onChoose: (minutes) => _ecrire(
                    context,
                    ref,
                    () => ref
                        .read(trainingProfileActionsProvider)
                        .setSessionMinutes(minutes),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.gapRow),
              AppTitledCard(
                icon: AppIcons.workout,
                title: 'Ton matériel',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sélectionne le matériel disponible',
                      style: AppTypography.label.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TrainingEquipmentSection(profile: value),
                  ],
                ),
              ),
            ],
          ),
          (null, AsyncError()) => AppErrorState(
            title: 'Préparation indisponible',
            message: 'Impossible de lire ton profil d’entraînement.',
            onRetry: () => ref.invalidate(trainingProfileProvider),
          ),
          _ => const AppLoadingIndicator(),
        },
      ),
    );
  }

  /// Toute écriture passe ici : l'échec s'affiche, l'état reste serveur.
  Future<void> _ecrire(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    final notices = AppNotices.of(context);
    try {
      await action();
    } on AppException catch (exception) {
      notices.show(exception.message, tone: AppNoticeTone.error);
    }
  }
}
