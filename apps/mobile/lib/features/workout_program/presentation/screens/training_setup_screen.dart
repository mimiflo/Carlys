import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../exercises/presentation/providers/exercise_catalog_providers.dart';
import '../../domain/entities/training_goal.dart';
import '../../domain/entities/training_profile.dart';
import '../controllers/training_goal_controllers.dart';
import '../controllers/training_profile_controllers.dart';
import '../widgets/training_goal_sheet.dart';
import '../widgets/training_setup_sections.dart';

/// « Préparer mon programme » : les ENTRÉES DE GÉNÉRATION en un écran —
/// objectif, expérience, rythme, matériel. Chaque geste écrit SON champ au
/// serveur puis relit : l'écran reflète toujours l'état serveur.
///
/// C'est le futur écran de génération (Plan 4, tranche suivante) : il
/// gagnera son bouton « Générer » quand les règles existeront — d'ici là,
/// remplir ces réponses prépare le terrain, rien n'est bloquant.
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
      backgroundColor: AppColors.darkBackground,
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
              _Materiel(profile: value),
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on AppException catch (exception) {
      messenger.showSnackBar(SnackBar(content: Text(exception.message)));
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
          Text(
            'Quatre réponses, et ton futur programme partira de toi, '
            'pas d’un modèle générique.',
            style: AppTypography.label.copyWith(
              color: AppColors.neutral0.withValues(alpha: 0.8),
            ),
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
                decoration: BoxDecoration(
                  borderRadius: AppRadius.fullAll,
                  color: AppColors.neutral0.withValues(alpha: 0.16),
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

/// Le bloc matériel, avec ses états : la taxonomie vient du serveur.
class _Materiel extends ConsumerWidget {
  const _Materiel({required this.profile});

  final TrainingProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(equipmentCatalogProvider);

    return switch (catalog) {
      AsyncData(:final value) when value.isEmpty => const AppEmptyState(
        icon: AppIcons.exercises,
        title: 'Catalogue vide',
        message: 'Le matériel du catalogue n’est pas encore chargé.',
      ),
      AsyncData(:final value) => EquipmentChecklist(
        catalog: value,
        ownedSlugs: profile.equipmentSlugs.toSet(),
        // La bascule vit dans les actions, SÉRIALISÉE : l'écran ne
        // calcule pas la liste — deux coches rapides se courraient après.
        onToggle: (equipment) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref
                .read(trainingProfileActionsProvider)
                .toggleEquipment(equipment.slug);
          } on AppException catch (exception) {
            messenger.showSnackBar(SnackBar(content: Text(exception.message)));
          }
        },
      ),
      AsyncError() => AppErrorState(
        title: 'Matériel indisponible',
        message: 'Impossible de lire la liste du matériel.',
        onRetry: () => ref.invalidate(equipmentCatalogProvider),
      ),
      _ => const AppLoadingIndicator(),
    };
  }
}
