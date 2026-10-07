import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';

/// Les trois chiffres du bilan — durée, séries, volume — et ce que le volume
/// veut dire : « charge × répétitions » se devine mal d'un seul mot.
class WorkoutSummaryStats extends StatelessWidget {
  const WorkoutSummaryStats({required this.workout, super.key});

  final WorkoutWithSets workout;

  @override
  Widget build(BuildContext context) {
    final seconds = workout.session.durationSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Les trois tuiles ont la même structure, donc la même hauteur.
        Row(
          children: [
            Expanded(
              child: _Stat(
                icon: AppIcons.timer,
                value: seconds == null ? '—' : formatMinutes(seconds),
                label: 'Durée',
              ),
            ),
            const SizedBox(width: AppSpacing.gapTile),
            Expanded(
              child: _Stat(
                icon: AppIcons.setsCount,
                value: formatThousands(workout.setsCount),
                label: 'Séries',
              ),
            ),
            const SizedBox(width: AppSpacing.gapTile),
            Expanded(
              child: _Stat(
                icon: AppIcons.workout,
                value: '${formatThousands(workout.totalVolumeKg)} kg',
                label: 'Volume',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Volume = charge × répétitions, cumulé sur toutes les séries.',
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label : $value',
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 28),
            const SizedBox(height: AppSpacing.xs),
            // « 12 480 kg » sur un tiers d'écran étroit : la valeur rétrécit
            // au lieu de passer à la ligne.
            // Hauteur fixe : rétrécie, la valeur garderait sinon une ligne
            // plus basse que ses voisines.
            SizedBox(
              height: 36,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: AppTypography.resized(
                    AppTypography.title,
                    28,
                  ).copyWith(color: AppColors.darkTextPrimary),
                ),
              ),
            ),
            Text(
              label,
              style: AppTypography.body.copyWith(color: AppColors.primaryLight),
            ),
          ],
        ),
      ),
    );
  }
}
