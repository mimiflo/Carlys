import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';

/// Ligne de série de l'exercice en cours (maquette 2e).
///
/// Série enregistrée : fond primaire teinté, pastille et coche accent.
/// Série à venir (celle en cours de saisie) : fond surface, valeurs vides.
class ExerciseSetRow extends StatelessWidget {
  const ExerciseSetRow({
    required this.position,
    this.set,
    this.onDelete,
    super.key,
  });

  /// Rang affiché dans la pastille (1 pour la première série).
  final int position;

  /// `null` pour la série à venir.
  final WorkoutSetEntry? set;

  /// Suppression offline-first (appui long) — `null` pour la série à venir.
  final Future<void> Function()? onDelete;

  /// Géométrie de la maquette : pastille carrée 26, coche 18.
  static const double _badgeSize = 26;
  static const double _statusIconSize = 18;

  /// Fond de la série faite : primaire à 12 % (pas de jeton dédié).
  static const double _doneBackgroundAlpha = 0.12;

  @override
  Widget build(BuildContext context) {
    final entry = set;
    final done = entry != null;
    final detail = _detail(entry);

    final row = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: done
            ? AppColors.primary.withValues(alpha: _doneBackgroundAlpha)
            : AppColors.darkSurface,
        borderRadius: AppRadius.buttonAll,
        border: Border.all(
          color: done ? AppColors.primaryLightBorder : AppColors.darkBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: _badgeSize,
            height: _badgeSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? AppColors.accentBadgeBg : AppColors.rowDivider,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              formatThousands(position),
              style: AppTypography.metricS.copyWith(
                fontSize: 11,
                color: done ? AppColors.accent : AppColors.darkIconInactive,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              detail,
              style: AppTypography.body.copyWith(
                height: 1,
                fontWeight: FontWeight.w500,
                color: done
                    ? AppColors.neutralBadgeText
                    : AppColors.darkIconInactive,
              ),
            ),
          ),
          if (entry != null && entry.syncState != LocalSyncState.synced) ...[
            Tooltip(
              message: entry.syncState == LocalSyncState.failed
                  ? 'Synchronisation en échec, elle sera réessayée'
                  : 'En attente de synchronisation',
              child: const Icon(
                AppIcons.offline,
                size: _statusIconSize,
                color: AppColors.darkTextTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          if (done)
            const Icon(
              AppIcons.checkCircle,
              size: _statusIconSize,
              color: AppColors.accent,
            ),
        ],
      ),
    );

    if (!done) {
      return Semantics(
        label: 'Série ${formatThousands(position)} à saisir',
        child: row,
      );
    }

    return Semantics(
      label: 'Série ${formatThousands(position)} : $detail',
      hint: 'Appui long pour supprimer',
      child: GestureDetector(
        onLongPress: onDelete == null ? null : () => _confirmDelete(context),
        child: row,
      ),
    );
  }

  String _detail(WorkoutSetEntry? entry) {
    final weight = entry?.weightKg == null
        ? '—'
        : formatDecimal(entry!.weightKg!);
    final reps = entry?.reps == null ? '—' : formatThousands(entry!.reps!);
    final kind = entry != null && entry.kind != SetKind.normal
        ? ' · ${entry.kind.label}'
        : '';
    return '$weight kg × $reps$kind';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la série ?'),
        content: const Text(
          'La suppression est enregistrée localement puis synchronisée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onDelete?.call();
    }
  }
}
