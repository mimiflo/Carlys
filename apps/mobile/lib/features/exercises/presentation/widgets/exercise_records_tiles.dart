import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../progress/domain/entities/progress.dart';
import '../controllers/exercise_library_controller.dart';

/// Grille de trois tuiles mono sous le média de la fiche (maquette 2e).
///
/// La maquette y prescrit séries / répétitions / repos : le domaine ne les
/// fournit pas. On y met donc les trois records personnels réels de
/// l'exercice, recalculés par le serveur à la clôture des séances — « — »
/// tant que l'utilisateur n'en a aucun.
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

    // Les trois tuiles ont la même structure : leurs hauteurs s'égalisent
    // sans contrainte supplémentaire.
    return Row(
      children: [
        Expanded(
          child: AppStatTile(
            label: 'Charge max',
            value: maxWeight == null ? _empty : formatDecimal(maxWeight),
            unit: maxWeight == null ? null : ' kg',
          ),
        ),
        const SizedBox(width: AppSpacing.gapTile),
        Expanded(
          child: AppStatTile(
            label: 'Répétitions',
            value: maxReps == null ? _empty : formatThousands(maxReps),
          ),
        ),
        const SizedBox(width: AppSpacing.gapTile),
        Expanded(
          child: AppStatTile(
            label: 'Volume max',
            value: volume == null ? _empty : volume.value,
            unit: volume == null ? null : ' ${volume.unit}',
          ),
        ),
      ],
    );
  }
}
