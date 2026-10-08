import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';

/// Les records en UNE carte, une ligne par record (maquette d'octobre
/// 2026) : la coupe prend l'or, l'argent puis le bronze de la ligue, dans
/// l'ordre de la liste — du plus récent au plus ancien.
///
/// Une ligne ouvre la progression de son exercice quand le serveur en donne
/// l'identifiant ; sans lui (exercice retiré du catalogue), elle reste
/// muette plutôt que de mener à une erreur.
class RecordsCard extends StatelessWidget {
  const RecordsCard({required this.records, super.key});

  final List<PersonalRecordEntry> records;

  static const List<Color> _cups = [
    AppColors.leagueGold,
    AppColors.leagueSilver,
    AppColors.leagueBronze,
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, record) in records.indexed) ...[
            if (index > 0)
              const Divider(height: 1, color: AppColors.rowDivider),
            _RecordLine(
              record: record,
              cup: _cups[index < _cups.length ? index : _cups.length - 1],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordLine extends StatelessWidget {
  const _RecordLine({required this.record, required this.cup});

  final PersonalRecordEntry record;
  final Color cup;

  @override
  Widget build(BuildContext context) {
    final isReps = record.type == PersonalRecordType.maxReps;
    final value = isReps
        ? '${formatThousands(record.value)} rép.'
        : '${formatDecimal(record.value)} kg';
    final exerciseId = record.exerciseId;

    final line = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(AppIcons.record, size: 28, color: cup),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  record.type.label,
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.subheading.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          if (exerciseId != null) ...[
            const SizedBox(width: AppSpacing.sm),
            const Icon(AppIcons.chevronRight, color: AppColors.primaryLight),
          ],
        ],
      ),
    );

    final spoken =
        '${record.exerciseName}, ${record.type.label} : $value, '
        '${formatRelativeDayMono(record.achievedAt).toLowerCase()}';
    if (exerciseId == null) {
      return Semantics(label: spoken, excludeSemantics: true, child: line);
    }
    void open() => context.push(AppRoutes.exerciseProgression(exerciseId));
    return Semantics(
      label: '$spoken. Voir la progression',
      button: true,
      // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
      onTap: open,
      excludeSemantics: true,
      child: InkWell(onTap: open, child: line),
    );
  }
}
