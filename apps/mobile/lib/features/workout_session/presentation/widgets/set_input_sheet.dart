import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';

/// Résultat de la saisie d'une série.
class SetInputResult {
  const SetInputResult({
    required this.kind,
    required this.reps,
    required this.weightKg,
    required this.restSeconds,
  });

  final SetKind kind;
  final int reps;
  final double weightKg;
  final int restSeconds;
}

/// Feuille de saisie d'une série : répétitions, charge, type, repos.
Future<SetInputResult?> showSetInputSheet(
  BuildContext context, {
  required String exerciseName,
  SetInputResult? previous,
}) {
  return showModalBottomSheet<SetInputResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _SetInputForm(exerciseName: exerciseName, previous: previous),
    ),
  );
}

class _SetInputForm extends StatefulWidget {
  const _SetInputForm({required this.exerciseName, this.previous});

  final String exerciseName;
  final SetInputResult? previous;

  @override
  State<_SetInputForm> createState() => _SetInputFormState();
}

class _SetInputFormState extends State<_SetInputForm> {
  late int _reps = widget.previous?.reps ?? 10;
  late double _weightKg = widget.previous?.weightKg ?? 20;
  late SetKind _kind = widget.previous?.kind ?? SetKind.normal;
  late int _restSeconds = widget.previous?.restSeconds ?? 90;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.exerciseName, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<SetKind>(
              segments: [
                for (final kind in SetKind.values)
                  ButtonSegment(value: kind, label: Text(kind.label)),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) =>
                  setState(() => _kind = selection.first),
            ),
            const SizedBox(height: AppSpacing.md),
            _Stepper(
              label: 'Répétitions',
              value: '$_reps',
              onMinus: _reps > 1 ? () => setState(() => _reps -= 1) : null,
              onPlus: () => setState(() => _reps += 1),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Stepper(
              label: 'Charge (kg)',
              value: _weightKg == _weightKg.roundToDouble()
                  ? _weightKg.toStringAsFixed(0)
                  : _weightKg.toStringAsFixed(1),
              onMinus: _weightKg >= 2.5
                  ? () => setState(() => _weightKg -= 2.5)
                  : null,
              onPlus: () => setState(() => _weightKg += 2.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Stepper(
              label: 'Repos (s)',
              value: '$_restSeconds',
              onMinus: _restSeconds >= 30
                  ? () => setState(() => _restSeconds -= 15)
                  : null,
              onPlus: () => setState(() => _restSeconds += 15),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Valider la série',
              isExpanded: true,
              onPressed: () => Navigator.of(context).pop(
                SetInputResult(
                  kind: _kind,
                  reps: _reps,
                  weightKg: _weightKg,
                  restSeconds: _restSeconds,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onPlus,
    this.onMinus,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        IconButton.outlined(
          onPressed: onMinus,
          tooltip: 'Diminuer $label',
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 72,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: AppTypography.metric.copyWith(
              fontSize: 22,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: onPlus,
          tooltip: 'Augmenter $label',
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
