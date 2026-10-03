import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_program/domain/entities/training_profile.dart';
import '../../../workout_program/presentation/providers/training_goal_providers.dart';
import '../../../workout_program/presentation/providers/training_profile_providers.dart';
import '../../../workout_program/presentation/widgets/training_equipment_section.dart';
import '../../../workout_program/presentation/widgets/training_goal_sheet.dart';
import '../../../workout_program/presentation/widgets/training_setup_sections.dart';
import '../utils/coach_frame.dart';

/// « Avant que je réfléchisse » : la page du COACH, pas celle des
/// programmes. Il n'y demande que ce qu'il lui faut pour composer à coup
/// sûr — ton objectif, ton niveau, ton matériel — et rien d'autre : ni
/// rythme, ni durée, ni génération de programme.
///
/// « C'est parti » ferme la page avec `true` : la question qui attendait
/// part, et c'est alors seulement qu'il réfléchit. Revenir sans valider
/// rend `null` : la question reste dans le champ, rien n'est envoyé.
class CoachGoalScreen extends ConsumerWidget {
  const CoachGoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(trainingProfileProvider);
    final value = profile.valueOrNull;
    final goal = ref.watch(currentTrainingGoalProvider);
    final missing = value == null ? null : coachFrameMissing(value, goal);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch ((value, profile)) {
          (final TrainingProfile value, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: AppBackButton(),
              ),
              const SizedBox(height: AppSpacing.xs),
              const _Bandeau(),
              const SizedBox(height: AppSpacing.gapSection),
              const AppSectionLabel('Ton objectif'),
              const SizedBox(height: AppSpacing.sm),
              TrainingGoalChoices(
                current: goal,
                onChoose: (choice) => _ecrire(
                  context,
                  () => ref.read(trainingGoalActionsProvider).choose(choice),
                ),
              ),
              const SizedBox(height: AppSpacing.gapSection),
              const AppSectionLabel('Ton niveau'),
              const SizedBox(height: AppSpacing.sm),
              ExperienceChoices(
                current: value.experience,
                onChoose: (experience) => _ecrire(
                  context,
                  () => ref
                      .read(trainingProfileActionsProvider)
                      .setExperience(experience),
                ),
              ),
              const SizedBox(height: AppSpacing.gapSection),
              const AppSectionLabel('Ton matériel'),
              const SizedBox(height: AppSpacing.sm),
              TrainingEquipmentSection(profile: value),
            ],
          ),
          (null, AsyncError()) => AppErrorState(
            title: 'Profil indisponible',
            message: 'Impossible de lire ton profil d’entraînement.',
            onRetry: () => ref.invalidate(trainingProfileProvider),
          ),
          _ => const AppLoadingIndicator(),
        },
      ),
      bottomNavigationBar: missing == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: AppCtaButton(
                  // Court, pour tenir sur une ligne : le détail est dans
                  // les sections au-dessus.
                  label: switch (missing.length) {
                    0 => 'C’est parti',
                    1 => 'Encore ${missing.single}',
                    final n => 'Encore $n réponses',
                  },
                  icon: AppIcons.coach,
                  glow: false,
                  onPressed: missing.isEmpty
                      ? () => Navigator.of(context).pop(true)
                      : null,
                ),
              ),
            ),
    );
  }

  /// Chaque choix s'écrit au serveur, puis l'écran relit : un échec
  /// s'affiche et rien ne change.
  Future<void> _ecrire(
    BuildContext context,
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

/// Qui demande, et pourquoi : le dégradé VIOLET de l'application.
class _Bandeau extends StatelessWidget {
  const _Bandeau();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        gradient: AppColors.cta,
        borderRadius: AppRadius.cardSecondaryAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.coach, size: 28, color: AppColors.neutral0),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avant que je réfléchisse',
                  style: AppTypography.title.copyWith(
                    color: AppColors.neutral0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Ton objectif, ton niveau et ton matériel : je compose '
                  'avec ce que tu vises et ce que tu as vraiment, puis je '
                  'réponds à ta question.',
                  style: AppTypography.label.copyWith(
                    color: AppColors.neutral0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
