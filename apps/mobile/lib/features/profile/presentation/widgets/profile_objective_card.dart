import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../workout_program/domain/program_advancement.dart';
import '../../../workout_program/presentation/controllers/training_goal_controllers.dart';
import '../providers/profile_hub_providers.dart';
import 'profile_hub_tile.dart';
import 'profile_hub_wording.dart';

/// « Mon objectif » : ce que tu vises, et où en est le plan qui t'y mène.
///
/// La jauge est la POSITION dans le programme suivi, jamais une note de la
/// personne : elle dit d'abord la semaine (« Semaine 2 sur 8 »), puis un
/// pourcentage qui NOMME SA BASE (« 24 % du programme »), comme l'exige
/// `docs/product/progression.md`. Sans programme daté, pas de jauge — une
/// barre vide se lirait comme un retard.
class ProfileObjectiveCard extends ConsumerWidget {
  const ProfileObjectiveCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(currentTrainingGoalProvider)?.label;
    final advancement = ref.watch(activeProgramAdvancementProvider).valueOrNull;

    final spoken = StringBuffer('Mon objectif : ${goal ?? 'à choisir'}.');
    if (advancement != null) {
      spoken.write(
        ' ${positionLine(advancement)}, '
        '${percentText(advancement)} du programme.',
      );
    }

    return ProfileHubCard(
      children: [
        ProfileHubTile(
          icon: AppIcons.objective,
          title: 'Mon objectif',
          subtitle: goal ?? 'À choisir',
          semanticLabel: spoken.toString(),
          below: advancement == null
              ? null
              : _AdvancementGauge(advancement: advancement),
          onTap: onTap,
        ),
      ],
    );
  }
}

class _AdvancementGauge extends StatelessWidget {
  const _AdvancementGauge({required this.advancement});

  final ProgramAdvancement advancement;

  static const double _height = 8;

  @override
  Widget build(BuildContext context) {
    final caption = AppTypography.label.copyWith(
      color: AppColors.darkTextTertiary,
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppGauge(
                  progress: advancement.ratio,
                  color: AppColors.primary,
                  gradient: AppColors.violetRamp,
                  height: _height,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                percentText(advancement),
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs + 2),
          Row(
            children: [
              Expanded(child: Text(positionLine(advancement), style: caption)),
              Text('du programme', style: caption),
            ],
          ),
        ],
      ),
    );
  }
}
