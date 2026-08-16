import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';
import '../controllers/reward_controllers.dart';
import 'award_seal.dart';
import 'seal_engraving.dart';

/// LE FRANCHISSEMENT D'UN CAP.
///
/// Passer un titre est le seul événement du profil qui mérite une
/// célébration : c'est rare, c'est long à obtenir, et ça change le nom qu'on
/// porte. Le sceau se grave, le bandeau se déplie, et l'affaire est close.
///
/// Il n'apparaît QUE le jour où le titre est inscrit au journal. Une
/// célébration qui reviendrait à chaque ouverture ne célébrerait plus rien.
class TitleCrossingBanner extends ConsumerWidget {
  const TitleCrossingBanner({super.key});

  static const Duration revealDuration = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = ref.watch(earnedRewardsProvider).valueOrNull ?? const [];
    EarnedReward? crossing;
    for (final entry in earned) {
      if (entry.isNew && entry.reward.kind == RewardKind.titre) {
        crossing = entry;
        break;
      }
    }
    if (crossing == null) return const SizedBox.shrink();

    final reward = crossing.reward;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.resolve(context, revealDuration),
      curve: AppMotion.emphasized,
      builder: (context, value, child) => Opacity(
        opacity: value,
        // Le bandeau se DÉPLIE : il pousse le contenu au lieu de se poser
        // dessus, sinon il masquerait le titre qu'il célèbre.
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: value,
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.signature,
          borderRadius: AppRadius.lgAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              EngravedSeal(
                engrave: true,
                child: AwardSeal(kind: reward.kind, figure: reward.figure),
              ),
              const SizedBox(width: AppSpacing.gapRow),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nouveau titre',
                      style: AppTypography.label.copyWith(
                        color: AppColors.neutral0.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      reward.label,
                      style: AppTypography.title
                          .copyWith(color: AppColors.neutral0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
