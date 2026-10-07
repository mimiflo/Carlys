import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../progress/domain/entities/progress.dart';
import '../providers/exercise_catalog_providers.dart';

/// « Tes records » : les trois records personnels réels de l'exercice,
/// recalculés par le serveur à la clôture des séances — « — » tant que
/// l'utilisateur n'en a aucun (maquette d'octobre 2026).
class ExerciseRecordsTiles extends ConsumerWidget {
  const ExerciseRecordsTiles({
    required this.exerciseId,
    required this.exerciseName,
    super.key,
  });

  final String exerciseId;
  final String exerciseName;

  static const String _empty = '—';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(
      exerciseRecordsProvider((id: exerciseId, name: exerciseName)),
    );

    double? valueOf(PersonalRecordType type) {
      for (final record in records) {
        if (record.type == type) return record.value;
      }
      return null;
    }

    final maxWeight = valueOf(PersonalRecordType.maxWeight);
    final maxReps = valueOf(PersonalRecordType.maxReps);
    final maxVolume = valueOf(PersonalRecordType.maxSetVolume);
    final volume = maxVolume == null ? null : formatVolume(maxVolume);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Tes records',
            style: AppTypography.title.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Les trois tuiles ont la même structure, donc la même hauteur.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RecordTile(
                  icon: AppIcons.equipmentDumbbell,
                  accent: true,
                  value: maxWeight == null
                      ? _empty
                      : '${formatDecimal(maxWeight)} kg',
                  label: 'Charge max',
                ),
              ),
              const SizedBox(width: AppSpacing.gapTile),
              Expanded(
                child: _RecordTile(
                  icon: AppIcons.recordReps,
                  value: maxReps == null ? _empty : formatThousands(maxReps),
                  label: 'Répétitions max',
                ),
              ),
              const SizedBox(width: AppSpacing.gapTile),
              Expanded(
                child: _RecordTile(
                  icon: AppIcons.recordVolume,
                  value: volume == null
                      ? _empty
                      : '${volume.value} ${volume.unit}',
                  label: 'Volume max / série',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Une tuile : pastille, chiffre, libellé. L'orange désigne la charge — le
/// record qu'on vient chercher —, le violet les deux autres.
class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.value,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '$label : ${value == ExerciseRecordsTiles._empty ? 'aucun' : value}',
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconBadge(
              icon: icon,
              size: 36,
              color: accent ? AppColors.accent : AppColors.primaryLight,
              background: accent
                  ? AppColors.accentBadgeBg
                  : AppColors.primaryBadgeBg,
            ),
            const SizedBox(height: AppSpacing.xs),
            // « 12 480 kg » sur un tiers d'écran étroit : la valeur rétrécit
            // au lieu de passer à la ligne.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppTypography.title.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
