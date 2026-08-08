import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';

/// Une ligne = un record : trophée, nom de l'exercice, date relative et
/// valeur en mono. Le record le plus récent porte l'accent.
class RecordRow extends StatelessWidget {
  const RecordRow({required this.record, this.isLatest = false, super.key});

  final PersonalRecordEntry record;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final tint = isLatest ? AppColors.accent : AppColors.primaryLight;
    final achievedAt = formatRelativeDayMono(record.achievedAt);
    final isReps = record.type == PersonalRecordType.maxReps;
    final value =
        isReps ? formatThousands(record.value) : formatDecimal(record.value);
    final unit = isReps ? 'rép.' : 'kg';

    return Semantics(
      label: '${record.exerciseName}, ${record.type.label} : '
          '$value $unit, $achievedAt',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.gapRow,
        ),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.statTileAll,
          border:
              Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
        ),
        child: Row(
          children: [
            Icon(AppIcons.record, size: 22, color: tint),
            const SizedBox(width: AppSpacing.gapRow),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.exerciseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subheading.copyWith(
                      fontSize: 14,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    achievedAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMono.copyWith(
                      fontSize: 11,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text.rich(
              TextSpan(
                text: value,
                style: AppTypography.metricS.copyWith(
                  fontSize: 15,
                  color: AppColors.darkTextPrimary,
                ),
                children: [
                  TextSpan(
                    text: unit,
                    style: AppTypography.metricS.copyWith(
                      fontSize: 11,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
