import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';

/// Les records en UNE carte, une ligne par record (maquette d'octobre
/// 2026), du plus récent au plus ancien.
///
/// La coupe est la même pour tous : l'or, l'argent puis le bronze de la
/// maquette suivaient l'ordre de la liste, donc la RÉCENCE, et se lisaient
/// comme un podium que rien ne fonde — une charge et un nombre de
/// répétitions ne se classent pas entre eux.
///
/// Une ligne ouvre la progression de son exercice quand le serveur en donne
/// l'identifiant ; sans lui (exercice retiré du catalogue), elle reste
/// muette plutôt que de mener à une erreur.
class RecordsCard extends StatelessWidget {
  const RecordsCard({
    required this.records,
    this.scrollable = false,
    super.key,
  });

  final List<PersonalRecordEntry> records;

  /// Vrai dans la feuille « Tous mes records » : la liste défile et ne
  /// construit que les lignes en vue. Faux dans la page, où elle n'en
  /// montre que trois et suit le défilement de l'écran.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    const divider = Divider(height: 1, color: AppColors.rowDivider);
    return AppCard(
      padding: EdgeInsets.zero,
      child: scrollable
          ? ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: records.length,
              separatorBuilder: (_, __) => divider,
              itemBuilder: (_, index) => _RecordLine(record: records[index]),
            )
          // Dans la page, une colonne et non une liste : un second
          // défilement vertical imbriqué dans celui de l'écran ne ferait
          // que capter les gestes.
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, record) in records.indexed) ...[
                  if (index > 0) divider,
                  _RecordLine(record: record),
                ],
              ],
            ),
    );
  }
}

class _RecordLine extends StatelessWidget {
  const _RecordLine({required this.record});

  final PersonalRecordEntry record;

  static const double _cupSize = 28;

  @override
  Widget build(BuildContext context) {
    final isReps = record.type == PersonalRecordType.maxReps;
    final value = isReps
        ? '${formatThousands(record.value)} rép.'
        : '${formatDecimal(record.value)} kg';
    final exerciseId = record.exerciseId;
    final when = formatRelativeDayMono(record.achievedAt).toLowerCase();

    final line = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(
            AppIcons.record,
            size: _cupSize,
            color: AppColors.leagueGold,
          ),
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
                  '${record.type.label} · $when',
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
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
        '${record.exerciseName}, ${record.type.label} : $value, $when';
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
