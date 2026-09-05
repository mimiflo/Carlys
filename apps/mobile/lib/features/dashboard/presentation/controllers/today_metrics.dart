import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../../../nutrition/presentation/controllers/water_controllers.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';

/// LES QUATRE MESURES DU JOUR.
///
/// Chacune se lit de la même façon : ce qui est fait, ce qui était visé, ce
/// qu'il reste. Une valeur sans cible ne dit rien — « 654 kcal » n'est ni bon
/// ni mauvais tant qu'on ignore ce qu'on visait.
///
/// D'où la règle tenue ici : une mesure sans cible connue n'affiche PAS de
/// jauge remplie. Elle passe en attente, comme un axe de progression sans
/// fait, plutôt que de laisser croire à un objectif qui n'existe pas.
enum TodayMetricKind { calories, proteines, hydratation, volume }

/// Une mesure prête à afficher : l'écran ne calcule ni ne formate rien.
class TodayMetric {
  const TodayMetric({
    required this.kind,
    required this.label,
    required this.value,
    required this.target,
    required this.note,
    this.ratio,
  });

  final TodayMetricKind kind;

  /// Libellé court, mis en capitales à l'affichage.
  final String label;

  /// Ce qui est fait. « — » quand la donnée n'est pas suivie.
  final String value;

  /// La cible, préfixée du séparateur (« / 2 759 »). Vide sans cible.
  final String target;

  /// Ce qu'il reste, ou la portée de la mesure (« cette semaine »).
  final String note;

  /// Part remplie, de 0 à 1. `null` : la piste passe en tirets.
  final double? ratio;
}

/// Les quatre mesures, dans l'ordre de lecture de la grille.
final todayMetricsProvider = Provider.autoDispose<List<TodayMetric>>((ref) {
  final metabolism = ref
      .watch(metabolismReportProvider)
      .valueOrNull
      ?.metabolism;
  final kcal = ref.watch(consumedKcalTodayProvider);
  final protein = ref.watch(consumedProteinTodayProvider);
  final water = ref.watch(consumedWaterTodayProvider).valueOrNull;
  final volume = ref.watch(weeklyVolumeProvider);

  return [
    _counted(
      kind: TodayMetricKind.calories,
      label: 'Calories',
      done: kcal?.toDouble(),
      target: metabolism?.targetKcal.toDouble(),
      unit: 'kcal',
    ),
    _counted(
      kind: TodayMetricKind.proteines,
      label: 'Protéines',
      done: protein?.toDouble(),
      target: metabolism?.proteinG.toDouble(),
      unit: 'g',
    ),
    _counted(
      kind: TodayMetricKind.hydratation,
      label: 'Hydratation',
      done: water?.toDouble(),
      target: metabolism?.waterMl.toDouble(),
      unit: 'L',
      // Les litres se lisent en dixièmes : « 1,2 / 2,4 L » plutôt que
      // « 1 200 / 2 400 ml », qui ne se retient pas.
      scale: 1000,
    ),
    _counted(
      kind: TodayMetricKind.volume,
      label: 'Volume',
      done: volume.thisWeek,
      // La cible du volume est la semaine PRÉCÉDENTE : c'est la seule
      // référence que l'application possède, et la seule qui ait un sens —
      // progresser se mesure contre soi, pas contre un barème.
      target: volume.lastWeek,
      unit: 't',
      // Les tonnes se lisent en dixièmes ; les kilos bruts feraient un
      // nombre à cinq chiffres dans une cellule de 170 points.
      scale: 1000,
      fallbackNote: 'cette semaine',
    ),
  ];
});

/// Une mesure « fait sur visé ». Sans cible, elle reste en attente.
TodayMetric _counted({
  required TodayMetricKind kind,
  required String label,
  required double? done,
  required double? target,
  required String unit,
  double scale = 1,
  String? fallbackNote,
}) {
  String show(double raw) {
    final scaled = raw / scale;
    return scale == 1 ? formatThousands(scaled.round()) : formatDecimal(scaled);
  }

  if (done == null) {
    return TodayMetric(
      kind: kind,
      label: label,
      value: '—',
      target: target == null ? '' : '/ ${show(target)} $unit',
      note: fallbackNote ?? 'pas encore noté',
    );
  }
  if (target == null || target <= 0) {
    return TodayMetric(
      kind: kind,
      label: label,
      value: show(done),
      target: unit,
      note: fallbackNote ?? 'objectif à calculer',
    );
  }

  // Une journée qui commence n'est pas une journée en retard : à zéro, on
  // n'annonce pas ce qu'il « reste » — le reste, c'est la cible entière, et
  // la répéter sous la jauge sonne comme un reproche avant l'effort.
  if (done == 0) {
    return TodayMetric(
      kind: kind,
      label: label,
      value: show(0),
      target: '/ ${show(target)} $unit',
      note: fallbackNote ?? 'à toi de jouer',
      ratio: 0,
    );
  }

  final left = target - done;
  return TodayMetric(
    kind: kind,
    label: label,
    value: show(done),
    target: '/ ${show(target)} $unit',
    // Passé la cible, on ne dit pas « reste −37 g » : le dépassement est un
    // fait, pas une dette.
    note: left <= 0 ? 'objectif atteint' : 'reste ${show(left)} $unit',
    ratio: (done / target).clamp(0.0, 1.0),
  );
}

/// Volume soulevé cette semaine et la précédente, en kilos.
///
/// Lu dans l'historique LOCAL, comme la série de constance : l'accueil doit
/// rester juste hors ligne, et le serveur ne sert pas la semaine passée.
final weeklyVolumeProvider =
    Provider.autoDispose<({double? thisWeek, double? lastWeek})>((ref) {
      final history = ref.watch(workoutHistoryProvider).valueOrNull;
      if (history == null) {
        return (thisWeek: null, lastWeek: null);
      }

      final now = DateTime.now();
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final previousMonday = monday.subtract(const Duration(days: 7));

      var current = 0.0;
      var previous = 0.0;
      for (final entry in history) {
        if (entry.session.status != WorkoutStatus.completed) continue;
        final local = entry.session.startedAt.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        if (!day.isBefore(monday)) {
          current += entry.totalVolumeKg;
        } else if (!day.isBefore(previousMonday)) {
          previous += entry.totalVolumeKg;
        }
      }

      // Une semaine passée à zéro n'est pas une cible : elle rendrait la jauge
      // pleine au premier kilo soulevé.
      return (thisWeek: current, lastWeek: previous > 0 ? previous : null);
    });
