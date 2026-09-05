import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';
import 'award_seal.dart';
import 'dashed_outline.dart';
import 'seal_engraving.dart';

/// LA VITRINE, EN TROIS DENSITÉS.
///
/// Neuf lignes identiques devenaient un mur : personne ne lisait après la
/// troisième. La récompense la plus récente passe donc en VEDETTE, les deux
/// suivantes en LIGNES, et le reste se compte dans l'en-tête de section.
/// Trois densités, une hiérarchie, plus de mur.

/// La vedette : sceau 56, histoire sur deux lignes, surface alternative.
class FeaturedAwardCard extends StatelessWidget {
  const FeaturedAwardCard({required this.entry, super.key});

  final EarnedReward entry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.cardSecondary),
        border: Border.all(color: AppColors.darkBorderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.padCard),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EngravedSeal(
              engrave: entry.isNew,
              child: AwardSeal(
                kind: entry.reward.kind,
                figure: entry.reward.figure,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.reward.label,
                          style: AppTypography.heading.copyWith(
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                      ),
                      if (entry.isNew) const _NewPill(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entry.reward.story,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _Meta(entry: entry),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La ligne : sceau 34, histoire sur UNE ligne. Sa densité est ce qui fait
/// exister la vedette au-dessus.
class AwardRow extends StatelessWidget {
  const AwardRow({required this.entry, super.key});

  final EarnedReward entry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.listRow),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.gapRow,
        ),
        child: Row(
          children: [
            EngravedSeal(
              engrave: entry.isNew,
              child: AwardSeal(
                kind: entry.reward.kind,
                size: AwardSeal.small,
                figure: entry.reward.figure,
              ),
            ),
            const SizedBox(width: AppSpacing.gapRow),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.reward.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subheading.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    entry.reward.story,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _Meta(entry: entry),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « BADGE · AOÛT 2026 » : la forme, puis la date. Dans cet ordre — la forme
/// dit ce que la récompense vaut, la date seulement quand elle est tombée.
class _Meta extends StatelessWidget {
  const _Meta({required this.entry});

  final EarnedReward entry;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${entry.reward.kind.label} · ${formatMonthYear(entry.earnedAt)}'
          .toUpperCase(),
      style: AppTypography.labelMono.copyWith(
        color: AppColors.darkTextTertiary,
      ),
    );
  }
}

/// La SEULE occurrence d'orange de l'écran d'un compte avancé.
class _NewPill extends StatelessWidget {
  const _NewPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        'NOUVEAU',
        style: AppTypography.labelMono.copyWith(
          color: AppColors.onAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// CE QUI VIENT : une invitation, jamais un manque.
///
/// La bordure en tirets et le fond en retrait la font lire comme « pas
/// encore » sans jamais paraître désactivée. Pas de jauge, pas de compteur :
/// une chose à faire, pas une barre à remplir.
class UpcomingAwardRow extends StatelessWidget {
  const UpcomingAwardRow({required this.reward, super.key});

  final Reward reward;

  static const double _dotSize = 30;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const DashedOutline(radius: AppRadius.listRow),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.gapRow,
        ),
        child: Row(
          children: [
            Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.majestyBorder),
              ),
              child: const Icon(
                AppIcons.bookmark,
                size: 16,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(width: AppSpacing.gapRow),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.label,
                    style: AppTypography.subheading.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    reward.story,
                    style: AppTypography.body.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
