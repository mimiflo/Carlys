import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../progress/domain/entities/progress.dart';

/// Rangée de faits d'entraînement sous l'indice de forme.
///
/// La maquette y place des données de santé (BPM, sommeil) que le domaine ne
/// fournit pas : on garde le rendu, on n'affiche que des faits réels —
/// récupération déduite de la dernière séance, séances et volume de la
/// semaine. Une pastille sans donnée est simplement omise.
class HomeFactPills extends StatelessWidget {
  const HomeFactPills({
    required this.week,
    required this.restSinceLastWorkout,
    super.key,
  });

  final ProgressOverviewEntity? week;
  final Duration? restSinceLastWorkout;

  @override
  Widget build(BuildContext context) {
    final facts = <_Fact>[];

    final rest = restSinceLastWorkout;
    if (rest != null) {
      final recovery = _recoveryLabel(rest);
      facts.add(
        _Fact(
          icon: AppIcons.recovery,
          iconColor: AppColors.accent,
          label: recovery,
          semanticsLabel: recovery,
        ),
      );
    }

    final overview = week;
    if (overview != null) {
      final sessions = overview.sessionsCount;
      facts.add(
        _Fact(
          icon: AppIcons.workout,
          iconColor: AppColors.primaryLight,
          label: '$sessions séance${sessions > 1 ? 's' : ''}',
          semanticsLabel:
              '$sessions séance${sessions > 1 ? 's' : ''} cette semaine',
        ),
      );

      if (overview.totalVolumeKg > 0) {
        final volume = formatVolume(overview.totalVolumeKg);
        facts.add(
          _Fact(
            icon: AppIcons.trendingUp,
            iconColor: AppColors.primaryLight,
            label: '${volume.value} ${volume.unit}',
            semanticsLabel:
                'Volume de la semaine : ${volume.value} ${volume.unit}',
          ),
        );
      }
    }

    if (facts.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Row(
        children: [
          for (final (index, fact) in facts.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.xs),
            _FactPill(fact: fact),
          ],
        ],
      ),
    );
  }

  /// Lecture de récupération déduite du seul délai réel depuis la dernière
  /// séance terminée : < 20 h le corps encaisse encore, < 72 h le créneau est
  /// bon, au-delà on annonce la durée du repos.
  static String _recoveryLabel(Duration rest) {
    final hours = rest.inHours;
    if (hours < 20) {
      return 'Récup en cours';
    }
    if (hours < 72) {
      return 'Récup OK';
    }
    return 'Repos ${rest.inDays} j';
  }
}

class _Fact {
  const _Fact({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.semanticsLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String semanticsLabel;
}

/// Pastille mono à icône colorée : `AppPill` ne permet pas de teinter son
/// icône indépendamment du texte, la maquette l'exige ici.
class _FactPill extends StatelessWidget {
  const _FactPill({required this.fact});

  final _Fact fact;

  /// Géométrie de la maquette : icône 14 dans une pastille stadium.
  static const double _iconSize = 14;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: fact.semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gapTile,
            vertical: AppSpacing.xs,
          ),
          decoration: const BoxDecoration(
            color: AppColors.neutralBadgeBg,
            borderRadius: AppRadius.fullAll,
            border:
                Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fact.icon, size: _iconSize, color: fact.iconColor),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                fact.label.toUpperCase(),
                style: AppTypography.labelMono.copyWith(
                  fontSize: 11,
                  color: AppColors.neutralBadgeText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
