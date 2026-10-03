import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../exercises/presentation/providers/exercise_catalog_providers.dart';
import '../../../workout_program/presentation/providers/training_goal_providers.dart';
import '../../../workout_program/presentation/providers/training_profile_providers.dart';
import '../utils/coach_frame.dart';
import 'coach_card_frame.dart';

/// Le CADRE du coach, en tête du fil : ton objectif et ton matériel.
///
/// Rien de choisi : une carte le demande d'emblée et ouvre l'écran de
/// préparation — sans eux, il compose à l'aveugle, et on l'oublie. Et la
/// première question envoyée sans eux ouvre ce même écran AVANT que le
/// coach ne réfléchisse (`CoachPage._send`). Tout
/// choisi : une ligne le rappelle (« Objectif : Perte de gras · avec
/// haltères, barre »), qu'un appui permet de changer.
///
/// Lecture en échec ou pas encore là : rien, le coach reste utilisable.
class CoachTrainingFrame extends ConsumerWidget {
  const CoachTrainingFrame({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(trainingProfileProvider).valueOrNull;
    if (profile == null) return const SizedBox.shrink();
    final goal = ref.watch(currentTrainingGoalProvider);
    final catalog = ref.watch(equipmentCatalogProvider).valueOrNull;
    final names = {
      if (catalog != null)
        for (final item in catalog) item.slug: item.name.toLowerCase(),
    };
    final missing = coachFrameMissing(profile, goal);
    void open() => context.push(AppRoutes.programSetup);

    if (missing.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xs,
          AppSpacing.gutter,
          AppSpacing.xs,
        ),
        child: CoachCardFrame(
          maxWidth: double.infinity,
          children: [
            const CoachCardHeader(
              icon: AppIcons.goal,
              label: 'AVANT DE COMMENCER',
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Dis-moi ${coachFrameList(missing)} : je composerai tes séances avec '
              'ce que tu vises et ce que tu as vraiment.',
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Choisir maintenant',
              onPressed: open,
              isExpanded: true,
              icon: AppIcons.goal,
            ),
          ],
        ),
      );
    }

    final owned = [
      for (final slug in profile.equipmentSlugs) names[slug] ?? slug,
    ];
    final equipment = owned.length <= 3
        ? owned.join(', ')
        : '${owned.take(3).join(', ')} +${owned.length - 3}';
    // Catalogue pas encore lu (hors ligne) : l'objectif seul, jamais les
    // identifiants bruts du matériel.
    final summary = catalog == null
        ? 'Objectif : ${goal!.label}'
        : 'Objectif : ${goal!.label} · avec $equipment';
    return Semantics(
      button: true,
      label: '$summary. Modifier',
      excludeSemantics: true,
      onTap: open,
      child: InkWell(
        onTap: open,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              const Icon(
                AppIcons.goal,
                size: CoachCardHeader.iconSize,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Modifier',
                style: AppTypography.label.copyWith(
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
