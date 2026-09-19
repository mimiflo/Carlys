import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import 'set_stepper_field.dart';

/// Ce qu'une série vaut, quelle que soit son UNITÉ.
///
/// Quatre champs et non deux, parce que tous les mouvements ne se comptent
/// pas pareil : une planche se tient en secondes, une course se parcourt en
/// mètres. Les deux couples sont exclusifs à la saisie — une série porte des
/// répétitions OU un chrono — mais le type les porte tous, parce que c'est
/// ainsi que le serveur et la base les stockent depuis toujours.
class SetEntryValues {
  const SetEntryValues({
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.distanceMeters,
  });

  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final int? distanceMeters;
}

/// Charge et répétitions : le couple du renforcement.
class RepsAndWeightFields extends StatelessWidget {
  const RepsAndWeightFields({
    required this.weightKg,
    required this.reps,
    required this.onWeight,
    required this.onReps,
    required this.weightStep,
    super.key,
  });

  final double weightKg;
  final int reps;
  final ValueChanged<double> onWeight;
  final ValueChanged<int> onReps;
  final double weightStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SetStepperField(
            label: 'Charge',
            unit: 'kg',
            value: formatDecimal(weightKg),
            onDecrement: weightKg >= weightStep
                ? () => onWeight(weightKg - weightStep)
                : null,
            onIncrement: () => onWeight(weightKg + weightStep),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SetStepperField(
            label: 'Répétitions',
            unit: 'reps',
            value: formatThousands(reps),
            onDecrement: reps > 1 ? () => onReps(reps - 1) : null,
            onIncrement: () => onReps(reps + 1),
          ),
        ),
      ],
    );
  }
}

/// Temps et distance : le couple du cardio et des maintiens.
///
/// La distance peut rester à zéro — un gainage ne va nulle part — et c'est
/// pourquoi elle part de là : proposer « 1 000 m » à quelqu'un qui tient une
/// planche lui ferait corriger un chiffre inventé.
class TimeAndDistanceFields extends StatelessWidget {
  const TimeAndDistanceFields({
    required this.durationSeconds,
    required this.distanceMeters,
    required this.onDuration,
    required this.onDistance,
    required this.durationStep,
    required this.distanceStep,
    super.key,
  });

  final int durationSeconds;
  final int distanceMeters;
  final ValueChanged<int> onDuration;
  final ValueChanged<int> onDistance;
  final int durationStep;
  final int distanceStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SetStepperField(
            label: 'Durée',
            unit: formatDuration(durationSeconds).unit,
            value: formatDuration(durationSeconds).value,
            onDecrement: durationSeconds > durationStep
                ? () => onDuration(durationSeconds - durationStep)
                : null,
            onIncrement: () => onDuration(durationSeconds + durationStep),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SetStepperField(
            label: 'Distance',
            unit: 'm',
            value: formatThousands(distanceMeters),
            onDecrement: distanceMeters >= distanceStep
                ? () => onDistance(distanceMeters - distanceStep)
                : null,
            onIncrement: () => onDistance(distanceMeters + distanceStep),
          ),
        ),
      ],
    );
  }
}

/// Une durée lisible : des secondes tant qu'elles se comptent, des minutes
/// ensuite. « 180 s » se lit moins bien que « 3:00 », et « 45 s » se lit
/// mieux que « 0:45 ».
({String value, String unit}) formatDuration(int seconds) {
  if (seconds < 60) {
    return (value: '$seconds', unit: 's');
  }
  final minutes = seconds ~/ 60;
  final reste = seconds % 60;
  return (value: '$minutes:${reste.toString().padLeft(2, '0')}', unit: 'min');
}
