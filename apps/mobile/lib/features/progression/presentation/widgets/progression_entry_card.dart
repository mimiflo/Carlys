import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';
import '../../domain/reward.dart';
import '../controllers/progression_controllers.dart';
import '../controllers/reward_controllers.dart';
import 'award_seal.dart';
import 'majesty.dart';
import 'progression_gauge.dart';
import 'seal_engraving.dart';

/// LE BLOC COMPACT : le profil de progression, vu de l'ACCUEIL.
///
/// Hauteur fixe, une seule ligne de base partagée, un sceau. C'est la
/// première chose qu'on voit en ouvrant l'application, et c'est là que « plus
/// ça évolue, plus c'est majestueux » doit se ressentir sans avoir à ouvrir
/// quoi que ce soit — d'où le fond qui prend la lumière au lieu d'un aplat.
///
/// Adossé aux faits LOCAUX : il s'affiche donc même quand les statistiques du
/// serveur, autour de lui, sont hors ligne ou en erreur.
class ProgressionEntryCard extends ConsumerWidget {
  const ProgressionEntryCard({super.key});

  /// Hauteur fixe : le bloc ne doit pas grandir avec la longueur d'un nom de
  /// récompense, sinon l'accueil se réorganise à chaque médaille.
  static const double height = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(progressionProfileProvider);
    if (profile == null) {
      // L'historique local n'est pas encore lu. Un bloc vide vaut mieux qu'un
      // titre provisoire qui changerait sous les yeux.
      return const SizedBox.shrink();
    }

    final majesty = Majesty.of(ref.watch(highestTitleProvider));
    final earned = ref.watch(showcaseRewardsProvider);
    final latest = earned.isEmpty ? null : earned.first;

    return Semantics(
      button: true,
      label: 'Ton titre : ${profile.title.label}, '
          '${profile.points} points sur $maxTotal',
      onTap: () => context.push(AppRoutes.progression),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => context.push(AppRoutes.progression),
          child: Container(
            height: height,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: AppColors.compactPlate,
              borderRadius: BorderRadius.circular(AppRadius.cardSecondary),
              border: Border.all(color: AppColors.darkBorderStrong),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Summary(
                    profile: profile,
                    majesty: majesty,
                    latest: latest?.reward.label,
                  ),
                ),
                if (latest != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  _LatestSeal(entry: latest),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le titre, le total, la jauge, la dernière récompense nommée.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.profile,
    required this.majesty,
    required this.latest,
  });

  final ProgressionProfile profile;
  final Majesty majesty;

  /// Le nom de la dernière récompense. `null` tant qu'il n'y en a aucune.
  final String? latest;

  @override
  Widget build(BuildContext context) {
    final opened = profile.points > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'TON TITRE',
          style:
              AppTypography.labelMono.copyWith(color: AppColors.primaryLight),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                profile.title.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title
                    .copyWith(color: AppColors.darkTextPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              opened ? '${profile.points}' : '—',
              style: AppTypography.metricS
                  .copyWith(color: AppColors.darkTextPrimary),
            ),
            Text(
              '/$maxTotal',
              style: AppTypography.labelMono
                  .copyWith(color: AppColors.darkTextTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gapTile),
        ProgressionGauge(
          value: profile.totalProgress,
          height: _gaugeHeight,
          fill: opened ? majesty.gaugeFill : null,
        ),
        if (latest case final name?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Dernière : '),
                TextSpan(
                  // Le style part du design system, jamais d'un `TextStyle`
                  // nu : un fragment reconstruit à la main perdrait les
                  // polices de repli, et le premier emoji d'un nom sortirait
                  // en tofu.
                  text: name,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label
                .copyWith(color: AppColors.darkTextSecondary),
          ),
        ],
      ],
    );
  }

  /// La jauge la plus fine de l'application : le bloc compact tient sur
  /// 120 points, chaque trait compte double.
  static const double _gaugeHeight = 5;
}

/// La dernière récompense, réduite à son sceau. Pas de texte « nouveau » ici :
/// la place n'existe pas, un point d'accent suffit à le dire.
class _LatestSeal extends StatelessWidget {
  const _LatestSeal({required this.entry});

  final EarnedReward entry;

  static const double _dotSize = 12;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        EngravedSeal(
          engrave: entry.isNew,
          child: AwardSeal(
            kind: entry.reward.kind,
            figure: entry.reward.figure,
          ),
        ),
        if (entry.isNew)
          Positioned(
            top: -AppSpacing.xxs,
            right: -AppSpacing.xxs,
            child: Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                border: Border.all(color: AppColors.darkSurface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
