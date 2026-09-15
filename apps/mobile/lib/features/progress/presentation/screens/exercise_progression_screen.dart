import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../providers/exercise_progression_providers.dart';
import '../widgets/exercise_progression_chart.dart';
import '../widgets/record_row.dart';

/// La progression sur UN exercice : sa courbe de charge et ses records.
///
/// `GET /progress/exercises/:id` était écrite, testée et SANS AUCUN CLIENT
/// depuis septembre : le serveur savait répondre, personne ne demandait.
/// L'écran de Progrès ne montrait que le volume agrégé par période, où la
/// progression d'un exercice donné se noie dans celle de tous les autres.
class ExerciseProgressionScreen extends ConsumerWidget {
  const ExerciseProgressionScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression = ref.watch(exerciseProgressionProvider(exerciseId));

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        leading: const AppBackButton(),
        title: Text(
          progression.valueOrNull?.exerciseName ?? 'Progression',
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: progression.when(
          loading: () =>
              const AppLoadingIndicator(label: 'Chargement de ta progression'),
          error: (_, __) => AppErrorState(
            title: 'Progression indisponible',
            message: AppErrorState.retryConnectionMessage,
            onRetry: () =>
                ref.invalidate(exerciseProgressionProvider(exerciseId)),
          ),
          data: (data) => _Body(progression: data),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.progression});

  final ExerciseProgressionEntity progression;

  @override
  Widget build(BuildContext context) {
    if (progression.points.isEmpty) {
      return const AppEmptyState(
        title: 'Aucune séance sur cet exercice',
        message:
            'Termine une séance qui le contient : sa courbe apparaîtra ici.',
        icon: AppIcons.progress,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        if (ExerciseProgressionChart.traceable(progression))
          ExerciseProgressionChart(progression: progression)
        else
          // Une charge notée ne suffit pas à faire une courbe, et deux
          // séances au poids du corps n'en feront jamais. Le dire vaut mieux
          // qu'un graphique vide ou qu'une ligne plate à zéro.
          AppEmptyState(
            title: 'Pas encore de courbe',
            message: progression.chargedPoints.isEmpty
                ? 'Cet exercice n’a encore aucune charge notée. Le volume '
                      'compte quand même dans tes statistiques.'
                : 'Une seule séance chargée pour l’instant : la courbe se '
                      'trace à partir de deux.',
            icon: AppIcons.progress,
          ),
        const SizedBox(height: AppSpacing.gapSection),
        AppSectionHeader(
          title: 'Séances',
          trailing: '${progression.points.length}',
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final (index, point)
            in progression.points.reversed.toList().indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.sm),
          _SessionRow(point: point),
        ],
        if (progression.records.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gapSection),
          const AppSectionHeader(title: 'Records sur cet exercice'),
          const SizedBox(height: AppSpacing.sm),
          for (final (index, record) in progression.records.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            RecordRow(record: record, isLatest: index == 0),
          ],
        ],
      ],
    );
  }
}

/// Une séance sur cet exercice : sa date, sa charge, son volume.
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.point});

  final ExerciseProgressionPoint point;

  @override
  Widget build(BuildContext context) {
    final date = formatShortDateMono(point.date.toLocal());
    // Une séance sans charge notée ne vaut pas zéro kilo : elle n'a pas de
    // charge. Le tiret le dit, un « 0 kg » mentirait.
    final charge = point.maxWeightKg == null
        ? '—'
        : '${formatDecimal(point.maxWeightKg!)} kg';
    final volume = formatVolume(point.volumeKg);

    return Semantics(
      label:
          'Séance du $date, charge maximale $charge, '
          'volume ${volume.value} ${volume.unit}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.gapRow,
        ),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.statTileAll,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.darkBorder),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: AppTypography.resized(
                      AppTypography.metricS,
                      13,
                    ).copyWith(color: AppColors.darkTextPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    formatRelativeDayMono(point.date),
                    style: AppTypography.resized(
                      AppTypography.labelMono,
                      11,
                    ).copyWith(color: AppColors.darkTextTertiary),
                  ),
                ],
              ),
            ),
            Text(
              charge,
              style: AppTypography.resized(
                AppTypography.metricS,
                15,
              ).copyWith(color: AppColors.darkTextPrimary),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${volume.value} ${volume.unit}',
              style: AppTypography.resized(
                AppTypography.labelMono,
                11,
              ).copyWith(color: AppColors.darkTextTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
