import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';
import '../controllers/reward_controllers.dart';
import 'reward_medal.dart';

/// LA VITRINE : ce qui a été gagné, et ce qui est à portée.
///
/// Elle montre les deux, et jamais l'une sans l'autre. Une vitrine qui
/// n'afficherait que l'obtenu ne donnerait aucune direction ; une qui
/// n'afficherait que le manquant serait un compte de ce qu'on n'a pas.
class RewardShowcase extends ConsumerWidget {
  const RewardShowcase({this.limit, super.key});

  /// Nombre de récompenses montrées. `null` pour tout, sur l'écran dédié.
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = ref.watch(earnedRewardsProvider).valueOrNull;
    final next = ref.watch(nextRewardsProvider);
    if (earned == null) return const SizedBox.shrink();

    if (earned.isEmpty) {
      return _Upcoming(rewards: next, isFirst: true);
    }

    final shown = limit == null || earned.length <= limit!
        ? earned
        : earned.sublist(0, limit!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in shown) ...[
          _EarnedRow(entry: entry),
          const SizedBox(height: AppSpacing.gapRow),
        ],
        if (limit != null && earned.length > limit!)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '${earned.length - limit!} de plus dans ton profil.',
              style: AppTypography.label
                  .copyWith(color: AppColors.darkTextTertiary),
            ),
          ),
        if (next.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Upcoming(rewards: next, isFirst: false),
        ],
      ],
    );
  }
}

class _EarnedRow extends StatelessWidget {
  const _EarnedRow({required this.entry});

  final EarnedReward entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RewardMedal(reward: entry.reward, isNew: entry.isNew),
        const SizedBox(width: AppSpacing.gapRow),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      entry.reward.label,
                      style: AppTypography.subheading
                          .copyWith(color: AppColors.darkTextPrimary),
                    ),
                  ),
                  if (entry.isNew) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const AppPill(label: 'NOUVEAU', tone: AppPillTone.accent),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                entry.reward.story,
                style: AppTypography.label
                    .copyWith(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${entry.reward.kind.label} · ${formatMonthYear(entry.earnedAt)}',
                style: AppTypography.label
                    .copyWith(color: AppColors.darkTextTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ce qui est à portée. Formulé comme une invitation, jamais comme un
/// manque : « ce qui vient » plutôt que « ce qui te manque ».
class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.rewards, required this.isFirst});

  final List<Reward> rewards;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return Text(
        'Tout est gagné. Il ne reste qu’à continuer.',
        style: AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel(isFirst ? 'À portée' : 'Ce qui vient'),
        const SizedBox(height: AppSpacing.xs),
        for (final reward in rewards) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                AppIcons.bookmark,
                size: 16,
                color: AppColors.darkTextTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${reward.label} · ${reward.story}',
                  style: AppTypography.label
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}
