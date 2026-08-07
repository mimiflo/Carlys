import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';

/// Records personnels, regroupés par exercice.
class RecordsSection extends ConsumerWidget {
  const RecordsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(personalRecordsProvider);

    return records.when(
      loading: () => const AppLoadingIndicator(label: 'Chargement'),
      error: (_, __) => AppErrorState(
        title: 'Records indisponibles',
        onRetry: () => ref.invalidate(personalRecordsProvider),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const AppEmptyState(
            title: 'Aucun record pour l’instant',
            message: 'Terminez une séance pour décrocher vos premiers records.',
            icon: AppIcons.record,
          );
        }
        final byExercise = <String, List<PersonalRecordEntry>>{};
        for (final entry in entries) {
          byExercise.putIfAbsent(entry.exerciseName, () => []).add(entry);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final exercise in byExercise.entries) ...[
              _ExerciseRecordsCard(
                exerciseName: exercise.key,
                records: exercise.value,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _ExerciseRecordsCard extends StatelessWidget {
  const _ExerciseRecordsCard({
    required this.exerciseName,
    required this.records,
  });

  final String exerciseName;
  final List<PersonalRecordEntry> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      semanticLabel: 'Records sur $exerciseName',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.record,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(exerciseName, style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final record in records) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.type.label,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Text(
                  record.formattedValue,
                  style: AppTypography.metric.copyWith(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _formatDate(record.achievedAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (record != records.last) const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime utc) {
  final local = utc.toLocal();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(local.day)}/${pad(local.month)}/${local.year}';
}
