import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';

/// Une ligne = un record : trophée, nom de l'exercice, date relative et
/// valeur en mono. Le record le plus récent porte l'accent.
///
/// Elle OUVRE la progression de son exercice quand le serveur en donne
/// l'identifiant. C'est la question qui vient juste après avoir lu un
/// record — « et avant, j'en étais où ? » — et l'écran de Progrès n'y
/// répondait pas : son volume agrégé noie un mouvement dans tous les autres.
/// Un record sans `exerciseId` (exercice retiré du catalogue) reste une
/// ligne muette plutôt qu'un bouton qui mènerait à une erreur.
class RecordRow extends StatelessWidget {
  const RecordRow({required this.record, this.isLatest = false, super.key});

  final PersonalRecordEntry record;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final tint = isLatest ? AppColors.accent : AppColors.primaryLight;
    final achievedAt = formatRelativeDayMono(record.achievedAt);
    final isReps = record.type == PersonalRecordType.maxReps;
    final value = isReps
        ? formatThousands(record.value)
        : formatDecimal(record.value);
    final unit = isReps ? 'rép.' : 'kg';

    final exerciseId = record.exerciseId;
    final ligne = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.gapRow,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.statTileAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
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
                  style: AppTypography.resized(
                    AppTypography.subheading,
                    14,
                  ).copyWith(color: AppColors.darkTextPrimary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  achievedAt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.resized(
                    AppTypography.labelMono,
                    11,
                  ).copyWith(color: AppColors.darkTextTertiary),
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
    );

    final enonce =
        '${record.exerciseName}, ${record.type.label} : '
        '$value $unit, $achievedAt';

    if (exerciseId == null) {
      return Semantics(label: enonce, child: ligne);
    }

    return Semantics(
      label: '$enonce. Voir la progression',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.statTileAll,
        child: InkWell(
          onTap: () => context.push(AppRoutes.exerciseProgression(exerciseId)),
          borderRadius: AppRadius.statTileAll,
          child: ligne,
        ),
      ),
    );
  }
}
