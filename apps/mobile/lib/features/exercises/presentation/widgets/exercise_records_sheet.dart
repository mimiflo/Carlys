import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../progress/presentation/widgets/record_row.dart';
import '../controllers/exercise_library_controller.dart';

/// Historique de l'exercice : ses records personnels, du plus récent au plus
/// ancien. C'est la seule trace par mouvement que l'API expose aujourd'hui.
Future<void> showExerciseRecordsSheet(
  BuildContext context, {
  required String exerciseId,
  required String exerciseName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.darkSurfaceAlt,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.cardMain),
      ),
    ),
    builder: (sheetContext) => _ExerciseRecordsSheet(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
    ),
  );
}

class _ExerciseRecordsSheet extends ConsumerWidget {
  const _ExerciseRecordsSheet({
    required this.exerciseId,
    required this.exerciseName,
  });

  final String exerciseId;
  final String exerciseName;

  static const double _maxHeightFactor = 0.8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = [
      ...ref.watch(
        exerciseRecordsProvider((id: exerciseId, name: exerciseName)),
      ),
    ]..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * _maxHeightFactor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(
                title: 'Records — $exerciseName',
                trailing: records.isEmpty ? null : '${records.length}',
              ),
              const SizedBox(height: AppSpacing.sm),
              if (records.isEmpty)
                const AppEmptyState(
                  title: 'Aucun record sur ce mouvement',
                  message: 'Terminez une série pour enregistrer '
                      'votre premier record.',
                  icon: AppIcons.record,
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: records.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, index) => RecordRow(
                      record: records[index],
                      isLatest: index == 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
