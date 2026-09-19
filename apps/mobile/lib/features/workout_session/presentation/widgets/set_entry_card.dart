import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import 'exercise_picker_sheet.dart' show SetMeasure;
import 'set_entry_actions.dart';
import 'set_entry_fields.dart';

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
    this.plannedDurationSeconds,
    this.measure = SetMeasure.repsAndWeight,
    super.key,
  });

  /// Rang de la série dans l'exercice en cours (1 pour la première).
  final int setNumber;

  /// Dernière performance connue sur cet exercice — `null` s'il n'y en a pas.
  final WorkoutSetEntry? previous;

  /// Cible du programme pour cette série, `null` hors modèle.
  final int? plannedReps;
  final double? plannedWeightKg;
  final int? plannedDurationSeconds;

  /// L'unité PROPOSÉE, venue du catalogue. La carte laisse en changer : un
  /// gainage tenu au maximum se chronomètre même si le catalogue le classe
  /// en renforcement, et un rameur se compte parfois en coups.
  final SetMeasure measure;

  final void Function(SetEntryValues values) onValidate;

  /// Valeurs de départ quand aucune cible ni aucun historique n'existe (pas de
  /// donnée à rappeler : ce sont des valeurs de formulaire, jamais affichées
  /// comme une performance).
  static const double _defaultWeightKg = 20;
  static const int _defaultReps = 10;
  static const double _weightStep = 2.5;

  /// Amorces du mode chronométré. La distance part de ZÉRO : un gainage ne va
  /// nulle part, et proposer mille mètres obligerait à corriger un chiffre
  /// que personne n'a saisi.
  static const int _defaultDurationSeconds = 60;
  static const int _durationStep = 15;
  static const int _distanceStep = 100;

  @override
  State<SetEntryCard> createState() => _SetEntryCardState();
}

class _SetEntryCardState extends State<SetEntryCard> {
  late double _weightKg = _seedWeight();
  late int _reps = _seedReps();
  late int _durationSeconds = _seedDuration();
  late int _distanceMeters = widget.previous?.distanceMeters ?? 0;
  late SetMeasure _measure = _seedMeasure();

  /// Une cible chronométrée du programme l'emporte sur le type du catalogue :
  /// si le plan dit « 45 s », la carte s'ouvre sur le chronomètre, même pour
  /// un mouvement que le catalogue classe en renforcement — c'est le cas de
  /// tous les gainages.
  SetMeasure _seedMeasure() => widget.plannedDurationSeconds != null
      ? SetMeasure.timeAndDistance
      : widget.measure;

  /// La cible du programme prime sur la dernière performance : c'est ce qu'on
  /// a décidé de faire aujourd'hui.
  double _seedWeight() =>
      widget.plannedWeightKg ??
      widget.previous?.weightKg ??
      SetEntryCard._defaultWeightKg;

  int _seedReps() =>
      widget.plannedReps ?? widget.previous?.reps ?? SetEntryCard._defaultReps;

  int _seedDuration() =>
      widget.plannedDurationSeconds ??
      widget.previous?.durationSeconds ??
      SetEntryCard._defaultDurationSeconds;

  @override
  void didUpdateWidget(SetEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changement d'exercice, nouvelle série validée ou nouvelle cible de
    // programme : on repart de la meilleure amorce disponible.
    if (oldWidget.previous?.id != widget.previous?.id ||
        oldWidget.plannedReps != widget.plannedReps ||
        oldWidget.plannedWeightKg != widget.plannedWeightKg ||
        oldWidget.plannedDurationSeconds != widget.plannedDurationSeconds) {
      _weightKg = _seedWeight();
      _reps = _seedReps();
      _durationSeconds = _seedDuration();
      _distanceMeters = widget.previous?.distanceMeters ?? 0;
    }
    // L'unité PROPOSÉE change avec l'exercice ; celle que la personne a
    // choisie à la main ne doit pas survivre au changement d'exercice, sinon
    // le squat suivant s'ouvrirait en chronomètre.
    if (oldWidget.measure != widget.measure ||
        oldWidget.plannedDurationSeconds != widget.plannedDurationSeconds) {
      _measure = _seedMeasure();
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
            style: AppTypography.resized(
              AppTypography.subheading,
              14,
            ).copyWith(color: AppColors.darkTextPrimary),
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
          if (_measure == SetMeasure.repsAndWeight)
            RepsAndWeightFields(
              weightKg: _weightKg,
              reps: _reps,
              weightStep: SetEntryCard._weightStep,
              onWeight: (value) => setState(() => _weightKg = value),
              onReps: (value) => setState(() => _reps = value),
            )
          else
            TimeAndDistanceFields(
              durationSeconds: _durationSeconds,
              distanceMeters: _distanceMeters,
              durationStep: SetEntryCard._durationStep,
              distanceStep: SetEntryCard._distanceStep,
              onDuration: (value) => setState(() => _durationSeconds = value),
              onDistance: (value) => setState(() => _distanceMeters = value),
            ),
          const SizedBox(height: AppSpacing.xs),
          SetMeasureToggle(
            measure: _measure,
            onChange: (value) => setState(() => _measure = value),
          ),
          const SizedBox(height: AppSpacing.md),
          SetValidateCta(onPressed: () => widget.onValidate(_values())),
        ],
      ),
    );
  }

  /// Ce que la validation transmet : le couple de l'unité choisie, et LUI
  /// SEUL. Envoyer les quatre valeurs ferait enregistrer une charge de 20 kg
  /// sur une course, parce que le formulaire l'avait en mémoire.
  SetEntryValues _values() {
    return _measure == SetMeasure.repsAndWeight
        ? SetEntryValues(weightKg: _weightKg, reps: _reps)
        : SetEntryValues(
            durationSeconds: _durationSeconds,
            // Zéro mètre n'est pas une distance : un gainage ne va nulle part,
            // et l'enregistrer à 0 laisserait croire à une mesure.
            distanceMeters: _distanceMeters > 0 ? _distanceMeters : null,
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
          label:
              'Précédent ${formatDecimal(previous.weightKg!)} kg '
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
