import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/widgets/set_stepper_field.dart';
import '../../domain/entities/workout_template.dart';
import '../controllers/template_draft.dart';
import 'planned_rest_field.dart';

/// Une **série prévue** dans l'éditeur : nature de la série, charge et
/// répétitions visées au pas-à-pas, puis le repos.
///
/// Le pas-à-pas est celui de la séance active ([SetStepperField]) : composer
/// une prescription et la réaliser se font au même geste.
class PlannedSetRow extends StatelessWidget {
  const PlannedSetRow({
    required this.position,
    required this.set,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  /// Rang affiché de la série (1 pour la première).
  final int position;
  final DraftSet set;
  final ValueChanged<DraftSet> onChanged;
  final VoidCallback onRemove;

  /// Pas de saisie de la charge, aligné sur celui de la séance active.
  static const double weightStep = 2.5;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceAlt,
        borderRadius: AppRadius.statTileAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            position: position,
            set: set,
            onChanged: onChanged,
            onRemove: onRemove,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SetStepperField(
                  label: 'Charge',
                  unit: 'kg',
                  value: set.targetWeightKg == null
                      ? '—'
                      : formatDecimal(set.targetWeightKg!),
                  onIncrement: _incrementWeight,
                  // Descendre sous zéro rend la série « sans charge prévue » :
                  // poids du corps, ou charge décidée le jour même.
                  onDecrement: set.targetWeightKg == null
                      ? null
                      : _decrementWeight,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SetStepperField(
                  label: 'Répétitions',
                  unit: 'reps',
                  value: set.targetReps == null
                      ? '—'
                      : formatThousands(set.targetReps!),
                  onIncrement: _incrementReps,
                  onDecrement: (set.targetReps ?? 0) > 1
                      ? _decrementReps
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          PlannedRestField(
            seconds: set.restSeconds,
            onChanged: (seconds) =>
                onChanged(set.copyWith(restSeconds: seconds)),
          ),
        ],
      ),
    );
  }

  void _incrementWeight() => onChanged(
    set.copyWith(
      targetWeightKg: () =>
          _clampWeight((set.targetWeightKg ?? 0) + weightStep),
    ),
  );

  /// En dessous de zéro, la série redevient « sans charge prévue » (`null`).
  void _decrementWeight() => onChanged(
    set.copyWith(
      targetWeightKg: () => set.targetWeightKg! <= 0
          ? null
          : _clampWeight(set.targetWeightKg! - weightStep),
    ),
  );

  void _incrementReps() => onChanged(
    set.copyWith(
      targetReps: ((set.targetReps ?? 0) + 1).clamp(
        1,
        WorkoutTemplateLimits.repsMax,
      ),
    ),
  );

  void _decrementReps() =>
      onChanged(set.copyWith(targetReps: set.targetReps! - 1));

  static double _clampWeight(double value) =>
      value.clamp(0, WorkoutTemplateLimits.weightKgMax).toDouble();
}

/// Rang, nature de la série et retrait.
class _Header extends StatelessWidget {
  const _Header({
    required this.position,
    required this.set,
    required this.onChanged,
    required this.onRemove,
  });

  final int position;
  final DraftSet set;
  final ValueChanged<DraftSet> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'SÉRIE ${formatThousands(position)}',
                style: AppTypography.labelMono.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Retirer la série ${formatThousands(position)}',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: onRemove,
              icon: const Icon(
                AppIcons.delete,
                size: 18,
                color: AppColors.darkTextTertiary,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.xxs,
          runSpacing: AppSpacing.xxs,
          children: [
            for (final kind in SetKind.values)
              AppPill(
                label: kind.label,
                selected: set.kind == kind,
                onTap: () => onChanged(set.copyWith(kind: kind)),
              ),
          ],
        ),
      ],
    );
  }
}
