import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';
import 'majesty.dart';
import 'majesty_plate.dart';
import 'progression_gauge.dart';

/// LA CARTE DE TITRE : le palier porté, le total, le chemin qui reste.
///
/// Elle ne partage RIEN avec une carte de récompense — ni son rayon (28
/// contre 24), ni sa surface, ni sa densité. C'était le troisième reproche
/// fait à la version précédente : deux cartes du même écran se ressemblaient
/// au point qu'on ne savait plus laquelle portait le titre.
///
/// Le total d'un compte neuf s'écrit « — », jamais « 0 » : un zéro se lit
/// comme un échec là où il n'y a que du temps devant soi.
class TitleCard extends StatelessWidget {
  const TitleCard({
    required this.profile,
    required this.majestyTier,
    super.key,
  });

  final ProgressionProfile profile;

  /// Cran de fabrication. Il suit le titre le plus haut JAMAIS atteint, pas
  /// celui du moment : une interruption fait redescendre les points, jamais
  /// l'écrin.
  final CarlysTitle majestyTier;

  @override
  Widget build(BuildContext context) {
    final majesty = Majesty.of(majestyTier);
    final next = profile.title.next;
    final remaining = profile.pointsToNextTitle;
    final opened = profile.points > 0;

    return MajestyPlate(
      majesty: majesty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TON TITRE',
            style: AppTypography.labelMono.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.title.label, style: majesty.nameStyle),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${majesty.rank} PALIERS',
                      style: AppTypography.labelMono.copyWith(
                        color: AppColors.darkTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _Total(
                points: profile.points,
                opened: opened,
                style: majesty.totalStyle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
          ProgressionGauge(
            // Le CHEMIN ENTIER, pas l'avancement vers le palier suivant :
            // une jauge qui repartirait de zéro à chaque palier effacerait
            // tout ce qui a été fait avant lui.
            value: profile.totalProgress,
            height: majesty.gaugeHeight,
            fill: opened ? majesty.gaugeFill : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Footer(next: next, remaining: remaining, opened: opened),
        ],
      ),
    );
  }
}

/// Le total, et le dénominateur qui le relativise sans lui voler la vedette.
class _Total extends StatelessWidget {
  const _Total({
    required this.points,
    required this.opened,
    required this.style,
  });

  final int points;
  final bool opened;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(opened ? '$points' : '—', style: style),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          '/$maxTotal',
          style: AppTypography.metricS.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Sous la jauge : ce qui reste, et le seuil visé. Le nombre de points est en
/// chiffres dans la phrase — c'est lui qu'on cherche du regard.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.next,
    required this.remaining,
    required this.opened,
  });

  final CarlysTitle? next;
  final int? remaining;
  final bool opened;

  @override
  Widget build(BuildContext context) {
    final body = AppTypography.body.copyWith(
      color: AppColors.darkTextSecondary,
    );

    if (!opened) {
      return Text(
        'La première séance ouvre le compteur. Rien avant, rien de perdu.',
        style: body,
      );
    }
    if (next == null || remaining == null) {
      return Text(
        'Dernier palier atteint. Le reste, c’est la suite de ton histoire.',
        style: body,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Encore '),
                TextSpan(
                  text: '$remaining',
                  style: AppTypography.metricS.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                TextSpan(text: ' points avant ${next!.label}.'),
              ],
            ),
            style: body,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '${next!.label.toUpperCase()} ${next!.threshold}',
          style: AppTypography.labelMono.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
      ],
    );
  }
}
