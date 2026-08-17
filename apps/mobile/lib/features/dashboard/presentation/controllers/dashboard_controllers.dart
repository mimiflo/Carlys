import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../progress/data/repositories/progress_repository_impl.dart';
import '../../../progress/domain/entities/progress.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../data/daily_quotes.dart';
import '../../domain/entities/consistency_week.dart';
import '../../domain/entities/daily_quote.dart';

/// Objectif hebdomadaire de séances — référence commune de l'indice de forme
/// et du bloc « Ta semaine ».
const int weeklySessionsTarget = 5;

/// Vue « semaine » de l'accueil — indépendante de la période sélectionnée
/// sur l'onglet Progression.
final weekOverviewProvider =
    FutureProvider.autoDispose<ProgressOverviewEntity>((ref) {
  return ref.watch(progressRepositoryProvider).overview(ProgressPeriod.week);
});

/// Indice de forme : part de l'objectif hebdomadaire déjà réalisée, sur 100.
///
/// `null` tant que la semaine n'est pas chargée — l'écran affiche alors un
/// tiret plutôt qu'une valeur inventée.
final fitnessIndexProvider = Provider.autoDispose<int?>((ref) {
  final week = ref.watch(weekOverviewProvider).valueOrNull;
  if (week == null) {
    return null;
  }
  final done = week.sessionsCount.clamp(0, weeklySessionsTarget);
  return (done / weeklySessionsTarget * 100).round();
});

/// LA LECTURE DE LA FORME, en trois bandes.
///
/// L'échelle graduée du bas de l'accueil n'est pas un score de santé : c'est
/// la part de l'objectif hebdomadaire déjà faite, dite en français. Les trois
/// bandes valent chacune un tiers — repos, charge juste, surcharge — et c'est
/// celle où tombe le score qui s'allume.
enum FormBand {
  repos('Repos'),
  chargeJuste('Charge juste'),
  surcharge('Surcharge');

  const FormBand(this.label);

  final String label;

  /// La bande où tombe un score de 0 à 100.
  static FormBand forScore(int score) {
    if (score < 34) return FormBand.repos;
    if (score < 67) return FormBand.chargeJuste;
    return FormBand.surcharge;
  }
}

/// Ce que l'échelle de forme raconte : une lecture courte et son pourquoi.
class FormReading {
  const FormReading({
    required this.score,
    required this.headline,
    required this.explanation,
  });

  final int score;

  /// Trois mots, lus d'un coup d'œil.
  final String headline;

  /// La phrase qui dit d'où vient la lecture — jamais un conseil médical,
  /// toujours un fait de la semaine.
  final String explanation;

  FormBand get band => FormBand.forScore(score);
}

/// La forme du jour, adossée aux séances RÉELLEMENT terminées de la semaine.
///
/// `null` tant que la semaine n'est pas lue : l'écran patiente au lieu
/// d'inventer une lecture.
final formReadingProvider = Provider.autoDispose<FormReading?>((ref) {
  final score = ref.watch(fitnessIndexProvider);
  final week = ref.watch(weekOverviewProvider).valueOrNull;
  if (score == null || week == null) {
    return null;
  }

  final sessions = week.sessionsCount;
  final remaining = weeklySessionsTarget - sessions;
  return switch (FormBand.forScore(score)) {
    FormBand.repos => FormReading(
        score: score,
        headline: sessions == 0 ? 'La semaine commence' : 'De la marge',
        explanation: sessions == 0
            ? 'Rien encore cette semaine. La première séance ouvre tout le '
                'reste.'
            : 'Une séance derrière toi. Le corps est frais, la place est '
                'large.',
      ),
    FormBand.chargeJuste => FormReading(
        score: score,
        headline: 'Prêt pour du lourd',
        explanation: '$sessions séances derrière toi, la récupération suit. '
            'Tu peux charger sans réserve aujourd’hui.',
      ),
    FormBand.surcharge => FormReading(
        score: score,
        headline: remaining <= 0 ? 'Objectif atteint' : 'Semaine chargée',
        explanation: remaining <= 0
            ? 'Les $weeklySessionsTarget séances sont faites. Ce qui vient en '
                'plus est du bonus, pas une dette.'
            : 'Le rythme est haut. Garde une journée pour récupérer, elle '
                'fait partie du travail.',
      ),
  };
});

/// Maxime du jour, tirée du recueil Carlys. Déterministe : même phrase toute
/// la journée, et sur tous les appareils de l'utilisateur.
final dailyQuoteProvider = Provider.autoDispose<DailyQuote>((ref) {
  return quoteOfTheDay(DateTime.now());
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
  final now = DateTime.now();
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
