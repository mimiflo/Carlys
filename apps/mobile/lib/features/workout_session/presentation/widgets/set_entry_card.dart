import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import 'exercise_picker_sheet.dart' show SetMeasure;
import 'set_entry_actions.dart';
import 'set_entry_fields.dart';
import 'set_entry_heading.dart';
import 'set_entry_labels.dart';

/// Carte de saisie de la série en cours : rang de la série, objectif du
/// programme s'il y en a un, charge et répétitions, rappel de la dernière
/// série, validation — et, sous un programme, de quoi passer.
///
/// Quand la séance suit un modèle, [plannedReps] / [plannedWeightKg] portent
/// la **cible affichée** : elle amorce le pas-à-pas et s'écrit en objectif. C'est une **proposition, jamais une contrainte** — l'utilisateur
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
    this.onSkipSet,
    this.onSkipExercise,
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

  /// Passer la série prévue / tout le reste de l'exercice. `null` hors modèle.
  final VoidCallback? onSkipSet;
  final VoidCallback? onSkipExercise;

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
    final objective = setObjectiveLabel(
      reps: widget.plannedReps,
      weightKg: widget.plannedWeightKg,
      durationSeconds: widget.plannedDurationSeconds,
    );
    final previous = previousSetLabel(widget.previous);
    final skips = widget.onSkipSet != null || widget.onSkipExercise != null;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.padCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SetEntryHeading(setNumber: widget.setNumber, objective: objective),
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
          if (previous != null) ...[
            const SizedBox(height: AppSpacing.sm),
            PreviousSetLine(label: previous),
          ],
          SetMeasureToggle(
            measure: _measure,
            onChange: (value) => setState(() => _measure = value),
          ),
          const SizedBox(height: AppSpacing.xs),
          SetValidateCta(onPressed: () => widget.onValidate(_values())),
          if (skips) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, thickness: 1, color: AppColors.rowDivider),
            SetSkipActions(
              onSkipSet: widget.onSkipSet,
              onSkipExercise: widget.onSkipExercise,
            ),
          ],
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
}
