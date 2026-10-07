import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout_template.dart';
import '../utils/template_draft.dart';
import 'planned_number_cell.dart';
import 'set_kind_sheet.dart';

/// Le tableau des séries prévues d'un exercice (maquette d'octobre 2026) :
/// SÉRIE · KG · REPS · REPOS, une ligne par série, saisie au clavier.
///
/// Les bornes sont celles partagées avec l'API : refuser ici, c'est éviter un
/// refus serveur des heures plus tard, en `failed`.
class PlannedSetsTable extends StatelessWidget {
  const PlannedSetsTable({
    required this.exercise,
    required this.onChangeSet,
    required this.onRemoveSet,
    super.key,
  });

  final DraftExercise exercise;
  final void Function(int setIndex, DraftSet set) onChangeSet;
  final void Function(int setIndex) onRemoveSet;

  @override
  Widget build(BuildContext context) {
    final sets = exercise.sets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ExcludeSemantics(
          child: _Line(
            number: _Head('SÉRIE'),
            weight: _Head('KG'),
            reps: _Head('REPS'),
            rest: _Head('REPOS'),
            trailing: SizedBox.shrink(),
          ),
        ),
        for (var index = 0; index < sets.length; index++) ...[
          const SizedBox(height: AppSpacing.xs),
          _SetLine(
            // La ligne suit sa position : retirer la série 2 remonte la 3,
            // et chaque case se remet sur la valeur de sa nouvelle série.
            key: ValueKey('${exercise.localId}-$index'),
            position: index + 1,
            set: sets[index],
            onChanged: (set) => onChangeSet(index, set),
            onRemove: () => onRemoveSet(index),
          ),
        ],
      ],
    );
  }
}

class _SetLine extends StatelessWidget {
  const _SetLine({
    required this.position,
    required this.set,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int position;
  final DraftSet set;
  final ValueChanged<DraftSet> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final rank = formatThousands(position);
    final weight = set.targetWeightKg;
    return _Line(
      number: SetKindCell(
        position: position,
        kind: set.kind,
        onTap: () async {
          final kind = await showSetKindSheet(
            context,
            title: 'Type de la série $rank',
            current: set.kind,
          );
          if (kind != null) onChanged(set.copyWith(kind: kind));
        },
      ),
      weight: PlannedNumberCell(
        text: weight == null ? '' : formatDecimalInput(weight),
        decimal: true,
        semanticLabel: 'Charge de la série $rank, en kilos',
        onChanged: (raw) {
          final value = parseDecimalInput(raw);
          // Vide : aucune charge prévue — poids du corps, ou charge décidée
          // le jour même. Illisible (« , » seule) : rien ne change.
          if (value == null && raw.trim().isNotEmpty) return;
          onChanged(
            set.copyWith(
              targetWeightKg: () =>
                  value?.clamp(0, WorkoutTemplateLimits.weightKgMax).toDouble(),
            ),
          );
        },
      ),
      reps: PlannedNumberCell(
        text: set.targetReps?.toString() ?? '',
        semanticLabel: 'Répétitions de la série $rank',
        onChanged: (raw) {
          final value = int.tryParse(raw.trim());
          if (value == null) return;
          onChanged(
            set.copyWith(
              targetReps: value.clamp(1, WorkoutTemplateLimits.repsMax),
            ),
          );
        },
      ),
      rest: PlannedNumberCell(
        text: '${set.restSeconds ?? 0}',
        suffix: 's',
        semanticLabel: 'Repos après la série $rank, en secondes',
        onChanged: (raw) {
          final value = int.tryParse(raw.trim()) ?? 0;
          onChanged(
            set.copyWith(
              restSeconds: value.clamp(0, WorkoutTemplateLimits.restSecondsMax),
            ),
          );
        },
      ),
      trailing: IconButton(
        tooltip: 'Retirer la série $rank',
        onPressed: () {
          // Le focus tombe AVANT la reconstruction : les lignes suivent leur
          // position, et une case gardant sa saisie l'aurait sinon écrite
          // dans la série remontée à sa place.
          FocusManager.instance.primaryFocus?.unfocus();
          onRemove();
        },
        icon: const Icon(AppIcons.removeSet, color: AppColors.darkTextTertiary),
      ),
    );
  }
}

/// La géométrie commune de l'en-tête et des lignes : les colonnes tombent
/// les unes sous les autres.
class _Line extends StatelessWidget {
  const _Line({
    required this.number,
    required this.weight,
    required this.reps,
    required this.rest,
    required this.trailing,
  });

  final Widget number;
  final Widget weight;
  final Widget reps;
  final Widget rest;
  final Widget trailing;

  static const double _numberWidth = 44;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: _numberWidth, child: number),
        const SizedBox(width: AppSpacing.xs),
        Expanded(flex: 4, child: weight),
        const SizedBox(width: AppSpacing.xs),
        Expanded(flex: 4, child: reps),
        const SizedBox(width: AppSpacing.xs),
        Expanded(flex: 5, child: rest),
        SizedBox(width: AppSpacing.touchTarget, child: trailing),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: AppTypography.labelMono.copyWith(
        color: AppColors.darkTextSecondary,
      ),
    );
  }
}
