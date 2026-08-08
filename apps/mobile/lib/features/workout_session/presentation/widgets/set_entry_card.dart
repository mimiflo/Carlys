import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import 'set_stepper_field.dart';

/// Carte de saisie de la série en cours (maquette 2e) : rang de la série,
/// cible du programme s'il y en a une, rappel de la performance précédente,
/// charge, répétitions et validation.
///
/// Quand la séance suit un modèle, [plannedReps] / [plannedWeightKg] portent
/// la **cible affichée** : elle amorce le pas-à-pas et s'affiche en pastille
/// accent. C'est une **proposition, jamais une contrainte** — l'utilisateur
/// valide ce qu'il a réellement fait, et un écart n'est ni une erreur ni un
/// blocage.
class SetEntryCard extends StatefulWidget {
  const SetEntryCard({
    required this.setNumber,
    required this.previous,
    required this.onValidate,
    this.plannedReps,
    this.plannedWeightKg,
    super.key,
  });

  /// Rang de la série dans l'exercice en cours (1 pour la première).
  final int setNumber;

  /// Dernière performance connue sur cet exercice — `null` s'il n'y en a pas.
  final WorkoutSetEntry? previous;

  /// Cible du programme pour cette série, `null` hors modèle.
  final int? plannedReps;
  final double? plannedWeightKg;

  final void Function(double weightKg, int reps) onValidate;

  /// Valeurs de départ quand aucune cible ni aucun historique n'existe (pas de
  /// donnée à rappeler : ce sont des valeurs de formulaire, jamais affichées
  /// comme une performance).
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

  /// La cible du programme prime sur la dernière performance : c'est ce qu'on
  /// a décidé de faire aujourd'hui.
  double _seedWeight() =>
      widget.plannedWeightKg ??
      widget.previous?.weightKg ??
      SetEntryCard._defaultWeightKg;

  int _seedReps() =>
      widget.plannedReps ?? widget.previous?.reps ?? SetEntryCard._defaultReps;

  @override
  void didUpdateWidget(SetEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changement d'exercice, nouvelle série validée ou nouvelle cible de
    // programme : on repart de la meilleure amorce disponible.
    if (oldWidget.previous?.id != widget.previous?.id ||
        oldWidget.plannedReps != widget.plannedReps ||
        oldWidget.plannedWeightKg != widget.plannedWeightKg) {
      _weightKg = _seedWeight();
      _reps = _seedReps();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Série ${formatThousands(widget.setNumber)}',
            style: AppTypography.subheading.copyWith(
              fontSize: 14,
              color: AppColors.darkTextPrimary,
            ),
          ),
          if (_pills().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            // Les pastilles occupent leur propre ligne : avec une cible ET un
            // rappel de performance, deux pastilles mono ne tiennent pas à
            // côté du titre sur un écran étroit.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xxs,
              runSpacing: AppSpacing.xxs,
              children: _pills(),
            ),
          ],
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

  /// La cible du programme passe en premier, en accent ; le rappel de la
  /// performance précédente devient secondaire et neutre.
  List<Widget> _pills() {
    final planned = _plannedLabel();
    final previous = widget.previous;
    final hasPrevious =
        previous != null && previous.weightKg != null && previous.reps != null;

    return [
      if (planned != null)
        AppPill(label: planned, tone: AppPillTone.accent, mono: true),
      if (hasPrevious)
        AppPill(
          label: 'Précédent ${formatDecimal(previous.weightKg!)} kg '
              '× ${formatThousands(previous.reps!)}',
          tone: planned == null ? AppPillTone.accent : AppPillTone.neutral,
          mono: true,
        ),
    ];
  }

  /// « Prévu 8 × 60 kg » ; une cible partielle reste lisible (« Prévu 8 reps »,
  /// « Prévu 60 kg ») — un modèle sans charge prévue est légitime.
  String? _plannedLabel() {
    final reps = widget.plannedReps;
    final weight = widget.plannedWeightKg;
    if (reps != null && weight != null) {
      return 'Prévu ${formatThousands(reps)} × ${formatDecimal(weight)} kg';
    }
    if (reps != null) {
      return 'Prévu ${formatThousands(reps)} reps';
    }
    if (weight != null) {
      return 'Prévu ${formatDecimal(weight)} kg';
    }
    return null;
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
