import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/training_goal.dart';
import '../../domain/entities/training_profile.dart';
import '../providers/training_goal_providers.dart';
import '../providers/training_profile_providers.dart';
import '../widgets/generate_program_card.dart';
import '../widgets/training_equipment_section.dart';
import '../widgets/training_goal_sheet.dart';
import '../widgets/training_setup_sections.dart';

/// « Préparer mon programme » : les ENTRÉES DE GÉNÉRATION en un écran —
/// objectif, expérience, rythme, matériel. Chaque geste écrit SON champ au
/// serveur puis relit : l'écran reflète toujours l'état serveur.
///
/// Le bouton « Générer » vit en bas : c'est l'aboutissement de l'écran, pas
/// son ouverture — on répond, puis on génère.
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
              const Align(
                alignment: Alignment.centerLeft,
                child: AppBackButton(),
              ),
              const SizedBox(height: AppSpacing.xs),
              _Bandeau(goal: goal),
              const SizedBox(height: AppSpacing.gapSection),
              const AppSectionLabel('Ton expérience'),
              const SizedBox(height: AppSpacing.sm),
              ExperienceChoices(
                current: value.experience,
                onChoose: (experience) => _ecrire(
                  context,
                  ref,
                  () => ref
                      .read(trainingProfileActionsProvider)
                      .setExperience(experience),
                ),
              ),
              const SizedBox(height: AppSpacing.gapSection),
              const AppSectionLabel('Séances par semaine'),
              const SizedBox(height: AppSpacing.sm),
              ChoicePills(
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
              const SizedBox(height: AppSpacing.gapSection),
              const AppSectionLabel('Durée d’une séance'),
              const SizedBox(height: AppSpacing.sm),
              ChoicePills(
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
              const SizedBox(height: AppSpacing.gapSection),
              const AppSectionLabel('Ton matériel'),
              const SizedBox(height: AppSpacing.sm),
              TrainingEquipmentSection(profile: value),
              const SizedBox(height: AppSpacing.gapSection),
              GenerateProgramCard(profile: value),
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

/// Le bandeau d'en-tête : ce que cet écran prépare, et l'objectif choisi
/// comme porte d'entrée — le dégradé VIOLET de l'application (`cta`),
/// jamais le dégradé de marque multicolore (réservé aux célébrations).
/// L'objectif vient de `AuthUser` (rafraîchi par la feuille de choix),
/// jamais d'une copie locale qui divergerait.
class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.goal});

  final TrainingGoal? goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        gradient: AppColors.cta,
        borderRadius: AppRadius.cardSecondaryAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Préparer mon programme',
            style: AppTypography.title.copyWith(color: AppColors.neutral0),
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Blanc PLEIN : à 80 %, 3,18:1 sur le départ clair du dégradé.
          Text(
            'Cinq réponses, objectif compris, et ton futur programme partira '
            'de toi, pas d’un modèle générique.',
            style: AppTypography.label.copyWith(color: AppColors.neutral0),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            button: true,
            label: 'Ton objectif : ${goal?.label ?? 'à choisir'}',
            // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
            onTap: () => showTrainingGoalSheet(context),
            excludeSemantics: true,
            child: InkWell(
              onTap: () => showTrainingGoalSheet(context),
              borderRadius: AppRadius.fullAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                // Le violet profond du dégradé : 7,15:1 (voile blanc : 3,38).
                decoration: const BoxDecoration(
                  borderRadius: AppRadius.fullAll,
                  color: AppColors.ctaEnd,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      AppIcons.goal,
                      size: 14,
                      color: AppColors.neutral0,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      goal?.label ?? 'Choisir mon objectif',
                      style: AppTypography.label.copyWith(
                        color: AppColors.neutral0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
