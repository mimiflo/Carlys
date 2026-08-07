import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../progress/domain/entities/progress.dart';

/// Tuiles de records personnels de la fiche exercice (2e) — les vraies
/// valeurs recalculées par le serveur à la clôture des séances.
class ExerciseRecordsTiles extends StatelessWidget {
  const ExerciseRecordsTiles({
    required this.exerciseName,
    required this.records,
    super.key,
  });

  final String exerciseName;
  final List<PersonalRecordEntry>? records;

  @override
  Widget build(BuildContext context) {
    final mine = records
            ?.where((record) => record.exerciseName == exerciseName)
            .toList() ??
        const <PersonalRecordEntry>[];
    double? of(PersonalRecordType type) {
      for (final record in mine) {
        if (record.type == type) return record.value;
      }
      return null;
    }

    final maxWeight = of(PersonalRecordType.maxWeight);
    final maxReps = of(PersonalRecordType.maxReps);
    final maxVolume = of(PersonalRecordType.maxSetVolume);

    return Row(
      children: [
        Expanded(
          child: AppStatTile(
            label: 'Charge max',
            value: maxWeight == null ? '—' : _round(maxWeight),
            unit: maxWeight == null ? null : ' kg',
          ),
        ),
        const SizedBox(width: AppSpacing.gapTile),
        Expanded(
          child: AppStatTile(
            label: 'Reps max',
            value: maxReps == null ? '—' : _round(maxReps),
          ),
        ),
        const SizedBox(width: AppSpacing.gapTile),
        Expanded(
          child: AppStatTile(
            label: 'Volume max',
            value: maxVolume == null ? '—' : _round(maxVolume),
            unit: maxVolume == null ? null : ' kg',
          ),
        ),
      ],
    );
  }

  static String _round(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1).replaceAll('.', ',');
}
