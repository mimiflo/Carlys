/// LE JOUR de l'accueil : la maxime, la semaine de constance, l'entraînement
/// du jour, la phrase d'état et le repos depuis la dernière séance.
///
/// Tout ce qui dépend de « quel jour on est » passe par `currentDayProvider`
/// plutôt que par `DateTime.now()` : l'accueil ne quitte jamais la pile du
/// shell, donc rien ici n'est jamais disposé, et un instant lu au lancement
/// y restait figé jusqu'à la fermeture de l'application.
///
/// Des providers DÉRIVÉS, pas des contrôleurs : aucun Notifier ici.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/current_day.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../data/daily_quotes.dart';
import '../../domain/entities/consistency_week.dart';
import '../../domain/entities/daily_quote.dart';

/// Maxime du jour, tirée du recueil Carlys. Déterministe : même phrase toute
/// la journée, et sur tous les appareils de l'utilisateur.
///
/// Le jour vient de [currentDayProvider] : `autoDispose` ne suffit pas ici,
/// l'accueil observe cette maxime en permanence (il ne quitte jamais la pile
/// du shell), donc rien ne la renouvelait jamais — « même phrase toute la
/// journée » devenait la même phrase indéfiniment.
final dailyQuoteProvider = Provider.autoDispose<DailyQuote>((ref) {
  return quoteOfTheDay(ref.watch(currentDayProvider));
});

/// Semaine de constance, déduite des séances RÉELLEMENT terminées.
///
/// `null` tant que l'historique n'est pas chargé : l'écran affiche alors des
/// jours en attente plutôt qu'une série inventée.
final consistencyWeekProvider = Provider.autoDispose<ConsistencyWeek?>((ref) {
  final history = ref.watch(workoutHistoryProvider).valueOrNull;
  if (history == null) {
    return null;
  }
  // Le jour COURANT, pas celui du lancement : l'accueil garde ce provider
  // vivant en permanence, et la semaine affichée restait celle d'hier après
  // minuit — jusqu'à ce qu'une écriture de séance réveille l'historique.
  final now = ref.watch(currentDayProvider);
  final trainedDays = <DateTime>{};
  for (final entry in history) {
    if (entry.session.status != WorkoutStatus.completed) {
      continue;
    }
    // Le jour retenu est celui du DÉBUT de la séance, en heure locale : une
    // séance commencée à 23 h 30 compte pour le jour où on s'y est mis.
    final local = entry.session.startedAt.toLocal();
    trainedDays.add(DateTime(local.year, local.month, local.day));
  }
  return buildConsistencyWeek(
    trainedDays: trainedDays,
    today: DateTime(now.year, now.month, now.day),
  );
});

/// Ce que l'accueil peut dire de l'entraînement du JOUR, sans rien inventer.
class TodayTraining {
  const TodayTraining({required this.value, this.detail});

  /// Ligne principale de la tuile (nom de séance, « À faire »…).
  final String value;

  /// Précision facultative (durée, « en cours »).
  final String? detail;
}

/// Entraînement du jour : séance en cours, séance déjà faite, ou rien encore.
final todayTrainingProvider = Provider.autoDispose<TodayTraining>((ref) {
  final active = ref.watch(activeWorkoutProvider).valueOrNull;
  if (active != null) {
    return TodayTraining(
      value: active.session.name ?? 'Séance libre',
      detail: 'en cours',
    );
  }

  final history = ref.watch(workoutHistoryProvider).valueOrNull;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  for (final entry in history ?? const <WorkoutHistoryEntry>[]) {
    if (entry.session.status != WorkoutStatus.completed) {
      continue;
    }
    final local = entry.session.startedAt.toLocal();
    if (DateTime(local.year, local.month, local.day) != today) {
      continue;
    }
    final seconds = entry.session.durationSeconds;
    return TodayTraining(
      value: entry.session.name ?? 'Séance faite',
      // La tuile n'est pas en mono : on reprend le format partagé, en bas de
      // casse, plutôt que d'en écrire un second.
      detail: seconds == null
          ? 'terminée'
          : formatDurationShort(seconds).toLowerCase(),
    );
  }
  return const TodayTraining(value: 'À faire');
});

/// Phrase d'état sous la salutation — toujours adossée à un fait : séance en
/// cours, séance du jour déjà faite, ou temps de récupération écoulé.
final homeSubtitleProvider = Provider.autoDispose<String>((ref) {
  if (ref.watch(activeWorkoutProvider).valueOrNull != null) {
    return 'Séance en cours.';
  }
  if (ref.watch(todayTrainingProvider).value != 'À faire') {
    return 'Séance faite aujourd’hui. Beau travail.';
  }

  final rest = ref.watch(restSinceLastWorkoutProvider);
  if (rest == null) {
    return 'Ton parcours commence aujourd’hui.';
  }
  final hours = rest.inHours;
  if (hours < 20) {
    return 'Ton corps encaisse encore la dernière séance.';
  }
  if (hours < 72) {
    return 'Récupération faite : le créneau est bon.';
  }
  return '${rest.inDays} jours de repos. On s’y remet ?';
});

/// Temps écoulé depuis la fin de la dernière séance terminée — seule base
/// réelle du fait « récupération » affiché en haut de l'accueil.
///
/// `null` si aucune séance terminée n'est connue localement.
final restSinceLastWorkoutProvider = Provider.autoDispose<Duration?>((ref) {
  final history = ref.watch(workoutHistoryProvider).valueOrNull;
  if (history == null) {
    return null;
  }
  for (final entry in history) {
    if (entry.session.status != WorkoutStatus.completed) {
      continue;
    }
    final endedAt = entry.session.endedAt ?? entry.session.startedAt;
    final rest = DateTime.now().difference(endedAt.toLocal());
    return rest.isNegative ? Duration.zero : rest;
  }
  return null;
});
