import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';

/// Une ligne prête à peindre : nom, rôle, couleur et remplissage.
typedef _MuscleBar = ({
  String name,
  bool isPrimary,
  Color color,
  double factor,
});

/// Carte « Muscles sollicités » de la fiche (maquette 2e).
///
/// La seule donnée fournie par l'API est le rôle du muscle (principal ou
/// secondaire) : la largeur de la jauge TRADUIT CE RÔLE, ce n'est en aucun
/// cas un pourcentage d'activation mesuré. Le muscle principal porte
/// l'accent, les suivants le violet.
class ExerciseMusclesCard extends StatelessWidget {
  const ExerciseMusclesCard({required this.muscles, super.key});

  final List<ExerciseMuscleLink> muscles;

  static const double _nameWidth = 88;
  static const double _gaugeHeight = 6;
  static const double _primaryFactor = 0.92;
  static const double _firstSecondaryFactor = 0.58;
  static const double _otherSecondaryFactor = 0.36;

  List<_MuscleBar> _bars() {
    var secondaryRank = 0;
    return [
      for (final link in muscles)
        if (link.isPrimary)
          (
            name: link.muscleGroup.name,
            isPrimary: true,
            color: AppColors.accent,
            factor: _primaryFactor,
          )
        else
          (
            name: link.muscleGroup.name,
            isPrimary: false,
            color:
                secondaryRank == 0 ? AppColors.primary : AppColors.primaryLight,
            factor: secondaryRank++ == 0
                ? _firstSecondaryFactor
                : _otherSecondaryFactor,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Muscles sollicités',
            style: AppTypography.subheading
                .copyWith(color: AppColors.darkTextPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (index, bar) in _bars().indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.xs),
            _MuscleRow(bar: bar),
          ],
        ],
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({required this.bar});

  final _MuscleBar bar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${bar.name} : muscle '
          '${bar.isPrimary ? 'principal' : 'secondaire'}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            SizedBox(
              width: ExerciseMusclesCard._nameWidth,
              child: Text(
                bar.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppGauge(
                progress: bar.factor,
                color: bar.color,
                height: ExerciseMusclesCard._gaugeHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
