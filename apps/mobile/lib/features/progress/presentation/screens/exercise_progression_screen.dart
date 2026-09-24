import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../providers/exercise_progression_providers.dart';
import '../widgets/exercise_cardio_chart.dart';
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

    return AppDarkScaffold(
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
        // La courbe suit ce que l'exercice PRODUIT. Un tapis n'a pas de
        // charge maximale, et la courbe de kilos rendait « pas encore de
        // courbe » à quelqu'un qui courait depuis six mois.
        ?_courbe(progression),
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

/// La courbe qui convient à cet exercice, ou l'explication de son absence.
///
/// Ordre volontaire : le cardio d'abord QUAND l'exercice se lit ainsi, la
/// charge sinon. Un exercice hybride (le rameur chargé) a les deux ; on en
/// trace une seule, celle que ses séances racontent le mieux.
Widget? _courbe(ExerciseProgressionEntity progression) {
  if (progression.readsAsCardio && ExerciseCardioChart.traceable(progression)) {
    return ExerciseCardioChart(progression: progression);
  }
  if (ExerciseProgressionChart.traceable(progression)) {
    return ExerciseProgressionChart(progression: progression);
  }
  if (ExerciseCardioChart.traceable(progression)) {
    return ExerciseCardioChart(progression: progression);
  }
  // Une seule séance ne suffit pas à faire une courbe, et deux séances sans
  // charge, sans chrono ni distance n'en feront jamais. Le dire vaut mieux
  // qu'un graphique vide ou qu'une ligne plate à zéro.
  return AppEmptyState(
    title: 'Pas encore de courbe',
    message:
        progression.chargedPoints.isEmpty && progression.cardioPoints.isEmpty
        ? 'Cet exercice n’a encore ni charge, ni chrono, ni distance notés. '
              'Le volume compte quand même dans tes statistiques.'
        : 'Une seule séance chiffrée pour l’instant : la courbe se trace à '
              'partir de deux.',
    icon: AppIcons.progress,
  );
}

/// Une séance sur cet exercice : sa date, sa charge, son volume.
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.point});

  final ExerciseProgressionPoint point;

  @override
  Widget build(BuildContext context) {
    final date = formatShortDateMono(point.date.toLocal());
    // Une séance de COURSE n'a ni charge ni volume : les deux colonnes
    // affichaient « — » et « 0 kg », c'est-à-dire un échec là où il y avait
    // huit kilomètres. Quand la séance a laissé une trace cardio, ce sont
    // ses chiffres à elle qui s'écrivent.
    final (valeur, detail, dit) = point.hasCardio
        ? _cardio(point)
        : _charge(point);

    return Semantics(
      label: 'Séance du $date, $dit',
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
              valeur,
              style: AppTypography.resized(
                AppTypography.metricS,
                15,
              ).copyWith(color: AppColors.darkTextPrimary),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              detail,
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

  /// Ce qu'une séance de FONTE met dans les deux colonnes : sa charge
  /// maximale, son volume. Une séance sans charge notée ne vaut pas zéro
  /// kilo — elle n'a pas de charge, et le tiret le dit là où « 0 kg »
  /// mentirait.
  static (String, String, String) _charge(ExerciseProgressionPoint point) {
    final charge = point.maxWeightKg == null
        ? '—'
        : '${formatDecimal(point.maxWeightKg!)} kg';
    final volume = formatVolume(point.volumeKg);
    return (
      charge,
      '${volume.value} ${volume.unit}',
      'charge maximale $charge, volume ${volume.value} ${volume.unit}',
    );
  }

  /// Ce qu'une séance de CARDIO y met : sa distance et son chrono, dans
  /// l'ordre où ils ont été notés. L'un peut manquer sans l'autre.
  static (String, String, String) _cardio(ExerciseProgressionPoint point) {
    final distance = point.distanceMeters > 0
        ? formatDistance(point.distanceMeters)
        : null;
    final duree = point.durationSeconds > 0
        ? formatDuration(point.durationSeconds)
        : null;
    final tete = distance ?? duree!;
    final queue = distance == null ? null : duree;
    return (
      '${tete.value} ${tete.unit}',
      queue == null ? '' : '${queue.value} ${queue.unit}',
      [
        if (distance != null) 'distance ${distance.value} ${distance.unit}',
        if (duree != null) 'durée ${duree.value} ${duree.unit}',
      ].join(', '),
    );
  }
}
