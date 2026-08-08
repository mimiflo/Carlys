import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import 'set_stepper_field.dart';

/// Carte de saisie de la série en cours (maquette 2e) : rang de la série,
/// rappel de la performance précédente, charge, répétitions et validation.
class SetEntryCard extends StatefulWidget {
  const SetEntryCard({
    required this.setNumber,
    required this.previous,
    required this.onValidate,
    super.key,
  });

  /// Rang de la série dans l'exercice en cours (1 pour la première).
  final int setNumber;

  /// Dernière performance connue sur cet exercice — `null` s'il n'y en a pas.
  final WorkoutSetEntry? previous;

  final void Function(double weightKg, int reps) onValidate;

  /// Valeurs de départ quand aucun historique n'existe (pas de donnée à
  /// rappeler : ce sont des valeurs de formulaire, jamais affichées comme
  /// une performance).
  static const double _defaultWeightKg = 20;
  static const int _defaultReps = 10;
  static const double _weightStep = 2.5;

  /// Géométrie de la maquette : CTA accent avec halo `0 12px 30px -12px`.
  static const double _ctaIconSize = 19;
  static const double _glowBlur = 30;
  static const double _glowSpread = -12;
  static const double _glowOffset = 12;

  @override
  State<SetEntryCard> createState() => _SetEntryCardState();
}

class _SetEntryCardState extends State<SetEntryCard> {
  late double _weightKg = _seedWeight();
  late int _reps = _seedReps();

  double _seedWeight() =>
      widget.previous?.weightKg ?? SetEntryCard._defaultWeightKg;

  int _seedReps() => widget.previous?.reps ?? SetEntryCard._defaultReps;

  @override
  void didUpdateWidget(SetEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changement d'exercice ou nouvelle série validée : on repart de la
    // dernière performance connue.
    if (oldWidget.previous?.id != widget.previous?.id) {
      _weightKg = _seedWeight();
      _reps = _seedReps();
    }
  }

  @override
  Widget build(BuildContext context) {
    final previous = widget.previous;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardMainAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Série ${formatThousands(widget.setNumber)}',
                  style: AppTypography.subheading.copyWith(
                    fontSize: 14,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              if (previous != null &&
                  previous.weightKg != null &&
                  previous.reps != null)
                AppPill(
                  label: 'Précédent ${formatDecimal(previous.weightKg!)} kg '
                      '× ${formatThousands(previous.reps!)}',
                  tone: AppPillTone.accent,
                  mono: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SetStepperField(
                  label: 'Charge',
                  unit: 'kg',
                  value: formatDecimal(_weightKg),
                  onDecrement: _weightKg >= SetEntryCard._weightStep
                      ? () => setState(
                            () => _weightKg -= SetEntryCard._weightStep,
                          )
                      : null,
                  onIncrement: () => setState(
                    () => _weightKg += SetEntryCard._weightStep,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SetStepperField(
                  label: 'Répétitions',
                  unit: 'reps',
                  value: formatThousands(_reps),
                  onDecrement:
                      _reps > 1 ? () => setState(() => _reps -= 1) : null,
                  onIncrement: () => setState(() => _reps += 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ValidateCta(onPressed: () => widget.onValidate(_weightKg, _reps)),
        ],
      ),
    );
  }
}

/// Unique action accent de l'écran : valider la série saisie.
class _ValidateCta extends StatelessWidget {
  const _ValidateCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.buttonAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.7),
            blurRadius: SetEntryCard._glowBlur,
            spreadRadius: SetEntryCard._glowSpread,
            offset: const Offset(0, SetEntryCard._glowOffset),
          ),
        ],
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.darkBackground,
          textStyle:
              AppTypography.subheading.copyWith(fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.check, size: SetEntryCard._ctaIconSize),
            SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                'Valider la série',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
