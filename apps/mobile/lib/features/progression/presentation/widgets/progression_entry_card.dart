import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';
import '../controllers/progression_controllers.dart';
import '../controllers/reward_controllers.dart';
import 'reward_medal.dart';
import 'title_regalia.dart';

/// Le profil de progression, vu de l'ACCUEIL : le titre porté, les points,
/// et la dernière récompense gagnée.
///
/// L'écrin monte en majesté avec le titre le plus haut jamais atteint. C'est
/// la première chose qu'on voit en ouvrant l'application, et c'est là que
/// « plus ça évolue, plus c'est majestueux » doit se ressentir sans avoir à
/// ouvrir quoi que ce soit.
///
/// Adossée aux faits LOCAUX : elle s'affiche donc même quand les
/// statistiques du serveur, autour d'elle, sont hors ligne ou en erreur.
class ProgressionEntryCard extends ConsumerWidget {
  const ProgressionEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(progressionProfileProvider);
    if (profile == null) {
      // L'historique local n'est pas encore lu. Une carte vide vaut mieux
      // qu'un titre provisoire qui changerait sous les yeux.
      return const SizedBox.shrink();
    }

    final regalia = TitleRegalia.of(ref.watch(highestTitleProvider));
    final earned = ref.watch(earnedRewardsProvider).valueOrNull ?? const [];
    final latest = earned.isEmpty ? null : earned.first;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.progression),
      child: DecoratedBox(
        decoration: regalia.decoration,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppSectionLabel('Ton titre'),
                            if (regalia.crowned) ...[
                              const SizedBox(width: AppSpacing.xs),
                              const Icon(
                                AppIcons.crown,
                                size: 13,
                                color: AppColors.primaryLight,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              regalia.gradient.createShader(bounds),
                          child: Text(
                            profile.title.label,
                            style: AppTypography.title
                                .copyWith(color: AppColors.neutral0),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${profile.points} points sur les cinq axes.',
                          style: AppTypography.label
                              .copyWith(color: AppColors.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    AppIcons.chevronRight,
                    color: AppColors.darkTextTertiary,
                  ),
                ],
              ),
              if (latest != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _LatestReward(entry: latest),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// La dernière récompense gagnée, en une ligne. Si elle vient d'être
/// obtenue, elle se grave ici même : c'est le premier endroit où
/// l'utilisateur repasse après une séance.
class _LatestReward extends StatelessWidget {
  const _LatestReward({required this.entry});

  final EarnedReward entry;

  static const double _medalSize = 34;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RewardMedal(
          reward: entry.reward,
          isNew: entry.isNew,
          size: _medalSize,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            entry.reward.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                AppTypography.label.copyWith(color: AppColors.darkTextPrimary),
          ),
        ),
        if (entry.isNew)
          const AppPill(label: 'NOUVEAU', tone: AppPillTone.accent),
      ],
    );
  }
}
