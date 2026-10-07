import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import '../utils/set_labels.dart';

/// Une ligne du tableau des séries de l'exercice : rang, charge (ou durée),
/// répétitions (ou distance), état.
///
/// Série enregistrée : ses valeurs, une coche verte, et l'appui long pour la
/// supprimer. Série en cours ([current]) : surlignée, « À saisir » en
/// violet, avec la cible du programme quand il y en a une. Série prévue
/// ensuite : des tirets et « À venir ».
class ExerciseSetRow extends StatelessWidget {
  const ExerciseSetRow({
    required this.position,
    this.set,
    this.onDelete,
    this.current = false,
    this.plannedWeightKg,
    this.plannedReps,
    this.finished = false,
    super.key,
  });

  /// Rang affiché (1 pour la première série).
  final int position;

  /// `null` pour une série pas encore faite.
  final WorkoutSetEntry? set;

  /// Suppression offline-first (appui long) — `null` pour une série à venir.
  final Future<void> Function()? onDelete;

  /// La série en cours de saisie.
  final bool current;

  /// Cible du programme, montrée sur la ligne en cours.
  final double? plannedWeightKg;
  final int? plannedReps;

  /// Ligne du BILAN d'une séance terminée : les unités dans les cellules
  /// (« 80 kg »), et la cible affichée au moment de la validation sous les
  /// valeurs — l'écart prévu/réalisé reste lisible des mois plus tard.
  final bool finished;

  static const double _statusIconSize = 24;

  @override
  Widget build(BuildContext context) {
    final entry = set;
    final done = entry != null;
    final (first, second) = _cells(entry);
    final ink = done || current
        ? AppColors.darkTextPrimary
        : AppColors.darkTextSecondary;
    final valueStyle = AppTypography.subheading.copyWith(color: ink);

    final row = Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: current ? AppColors.primaryCardSoft : null,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          SizedBox(
            width: ExerciseSetColumns.rank,
            child: Text(
              formatThousands(position),
              textAlign: TextAlign.center,
              style: valueStyle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(first, style: valueStyle)),
                    Expanded(child: Text(second, style: valueStyle)),
                  ],
                ),
                // Un échauffement, une série dégressive : ce que la série
                // ÉTAIT, sous ses valeurs.
                if (_note(entry) case final note?)
                  Text(
                    note,
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: ExerciseSetColumns.status,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (entry != null &&
                    entry.syncState != LocalSyncState.synced) ...[
                  Tooltip(
                    message: entry.syncState == LocalSyncState.failed
                        ? 'Synchronisation en échec, elle sera réessayée'
                        : 'En attente de synchronisation',
                    child: const Icon(
                      AppIcons.offline,
                      size: 18,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                if (done)
                  const Icon(
                    AppIcons.checkCircle,
                    size: _statusIconSize,
                    color: AppColors.success,
                  )
                else
                  Flexible(
                    child: Text(
                      current ? 'À saisir' : 'À venir',
                      textAlign: TextAlign.end,
                      style: AppTypography.body.copyWith(
                        color: current
                            ? AppColors.primaryLight
                            : AppColors.darkTextSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );

    if (entry == null) {
      return Semantics(
        label:
            'Série ${formatThousands(position)} '
            '${current ? 'à saisir' : 'à venir'}${_spokenTarget()}',
        excludeSemantics: true,
        child: row,
      );
    }

    return Semantics(
      label:
          'Série ${formatThousands(position)} : ${spokenSetValue(entry)}'
          '${entry.syncState == LocalSyncState.synced ? '' : ', en attente de synchronisation'}',
      hint: onDelete == null ? null : 'Appui long pour supprimer',
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: onDelete == null ? null : () => _confirmDelete(context),
        child: row,
      ),
    );
  }

  /// Sous les valeurs : ce que la série ÉTAIT (échauffement, dégressive)
  /// et, au bilan, la cible qu'elle visait (« Prévu 8 × 60 kg »).
  String? _note(WorkoutSetEntry? entry) {
    if (entry == null) {
      return null;
    }
    final planned = finished ? plannedLabel(entry) : null;
    final parts = [
      if (entry.kind != SetKind.normal) entry.kind.label,
      ?planned,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// « , cible 82,5 kg × 6 » : ce que la ligne en cours AFFICHE, pour le
  /// lecteur d'écran aussi.
  String _spokenTarget() {
    if (!current) {
      return '';
    }
    final parts = [
      if (plannedWeightKg != null) '${formatDecimal(plannedWeightKg!)} kg',
      if (plannedReps != null) '${formatThousands(plannedReps!)} répétitions',
    ];
    return parts.isEmpty ? '' : ', cible ${parts.join(' × ')}';
  }

  /// Les deux cellules de valeur, DANS L'UNITÉ de la série : une série
  /// chronométrée montre sa durée et sa distance, pas « — kg × — ».
  (String, String) _cells(WorkoutSetEntry? entry) {
    if (entry == null) {
      if (!current) {
        return ('—', '—');
      }
      return (
        plannedWeightKg == null ? '—' : formatDecimal(plannedWeightKg!),
        plannedReps == null ? '—' : formatThousands(plannedReps!),
      );
    }
    final seconds = entry.durationSeconds;
    if (seconds != null) {
      final duration = formatDuration(seconds);
      final distance = entry.distanceMeters;
      return (
        '${duration.value} ${duration.unit}',
        distance == null ? '—' : '${formatThousands(distance)} m',
      );
    }
    final kg = finished ? ' kg' : '';
    return (
      entry.weightKg == null ? '—' : '${formatDecimal(entry.weightKg!)}$kg',
      entry.reps == null ? '—' : formatThousands(entry.reps!),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Supprimer la série ?',
      message: 'La suppression est enregistrée localement puis synchronisée.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (confirmed) {
      await onDelete?.call();
    }
  }
}

/// Les largeurs fixes du tableau, partagées par l'en-tête et les lignes :
/// sans elles, « KG » ne tomberait pas au-dessus de « 80 ».
abstract final class ExerciseSetColumns {
  static const double rank = 52;
  static const double status = 88;
}
