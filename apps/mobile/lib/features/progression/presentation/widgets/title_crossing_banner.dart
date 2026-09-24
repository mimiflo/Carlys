import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/explanations/explanation.dart';
import '../../../../core/explanations/explanation_sheet.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';
import '../../domain/reward_engine.dart';
import '../../domain/title_explanations.dart';
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
///
/// Il annonçait un NOM, et rien d'autre : « Nouveau titre / Architecte ».
/// C'est le moment de l'application où l'on est le plus disposé à lire ce
/// qu'un mot veut dire, et c'était le seul où on ne le disait pas. Le
/// bandeau porte donc le sens du palier, et s'ouvre en entier d'un
/// tapotement.
class TitleCrossingBanner extends ConsumerWidget {
  const TitleCrossingBanner({super.key});

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
    // Le journal ne garde qu'un identifiant : on remonte au palier pour en
    // dire le sens. Un identifiant écrit par une version plus ancienne rend
    // `null`, et le bandeau retombe alors sur son ancien comportement.
    final titre = titleOfReward(reward.id);
    final explication = titre == null ? null : TitleExplanations.of(titre);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.resolve(context, AppMotion.reveal),
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
      child: _Bandeau(reward: reward, explication: explication),
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.reward, this.explication});

  final Reward reward;
  final Explanation? explication;

  @override
  Widget build(BuildContext context) {
    final explication = this.explication;

    // La signature SOUS UN TEXTE (`signatureInk`), et chaque texte en blanc
    // PLEIN : sur la signature d'origine, l'explication tombait à 2,25:1
    // au-dessus de l'orange, et même opaque ne tenait que 2,59. La
    // hiérarchie tient par la taille et la graisse, pas par l'opacité.
    final contenu = DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.signatureInk,
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
                      color: AppColors.neutral0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    reward.label,
                    style: AppTypography.title.copyWith(
                      color: AppColors.neutral0,
                    ),
                  ),
                  if (explication != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      explication.cequeCest,
                      style: AppTypography.label.copyWith(
                        color: AppColors.neutral0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (explication != null)
              const Icon(
                AppIcons.info,
                size: AppExplainButton.glyphSize,
                color: AppColors.neutral0,
              ),
          ],
        ),
      ),
    );

    if (explication == null) {
      return contenu;
    }
    return AppExplainable(
      enonce: 'Nouveau titre : ${reward.label}',
      borderRadius: AppRadius.lgAll,
      onExplain: () => showExplanation(context, explication),
      child: contenu,
    );
  }
}
