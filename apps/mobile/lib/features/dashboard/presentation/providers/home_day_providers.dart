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
import '../../../progress/domain/entities/progress.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../progression/presentation/controllers/progression_controllers.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../data/daily_quotes.dart';
import '../../domain/entities/consistency_week.dart';
import '../../domain/entities/daily_quote.dart';
import '../../domain/quote_facts.dart';
import '../controllers/today_metrics.dart';

/// LES FAITS qui décident de la maxime.
///
/// Aucune requête de plus : les six sources sont des providers que l'accueil
/// tient déjà vivants. Deux d'entre elles viennent du réseau — les records
/// et les cibles du jour — et valent donc faux hors ligne ; le repli
/// calendaire reprend alors la main, ce qui est exactement le comportement
/// d'avant cette tranche.
final quoteFactsProvider = Provider.autoDispose<QuoteFacts>((ref) {
  final today = ref.watch(currentDayProvider);
  final semaine = ref.watch(consistencyWeekProvider);
  final volume = ref.watch(weeklyVolumeProvider);
  final records = ref.watch(personalRecordsProvider).valueOrNull;
  final profil = ref.watch(progressionProfileProvider);

  // Le record le PLUS RÉCENT, s'il y en a un. La liste arrive triée par le
  // serveur, mais s'en remettre à un tri qu'on ne contrôle pas rendrait la
  // fraîcheur dépendante d'une promesse tacite.
  DateTime? dernierRecord;
  for (final record in records ?? const <PersonalRecordEntry>[]) {
    final quand = record.achievedAt;
    if (dernierRecord == null || quand.isAfter(dernierRecord)) {
      dernierRecord = quand;
    }
  }

  return buildQuoteFacts(
    today: today,
    history: ref.watch(workoutHistoryProvider).valueOrNull ?? const [],
    streakDays: semaine?.streakDays ?? 0,
    trainedThisWeek: semaine?.trainedCount ?? 0,
    recentRecordAt: dernierRecord,
    goalReached: ref
        .watch(todayMetricsProvider)
        .any((metric) => (metric.ratio ?? 0) >= 1),
    thisWeekVolumeKg: volume.thisWeek ?? 0,
    lastWeekVolumeKg: volume.lastWeek ?? 0,
    masteryPending:
        profil?.axes.any(
          (axe) => axe.value == CarlysValue.maitrise && !axe.known,
        ) ??
        false,
  );
});

/// Maxime du jour : celle que les FAITS appellent, à défaut celle du
/// calendrier.
///
/// Le contrat de stabilité a changé avec cette tranche, et il faut le dire :
/// ce n'est plus « la même phrase toute la journée » mais « la même TANT QUE
/// LES FAITS NE CHANGENT PAS ». Terminer une séance à 18 h change
/// légitimement la citation — c'est tout l'objet de l'affichage contextuel.
///
/// Le jour vient de [currentDayProvider] : `autoDispose` ne suffit pas ici,
/// l'accueil observe cette maxime en permanence (il ne quitte jamais la pile
/// du shell), donc rien ne la renouvelait jamais.
final dailyQuoteProvider = Provider.autoDispose<DailyQuote>((ref) {
  return contextualQuote(
    facts: ref.watch(quoteFactsProvider),
    day: ref.watch(currentDayProvider),
  );
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
  // Le jour COURANT, pas celui du lancement. L'accueil ne quitte jamais la
  // pile du shell : un instant lu au démarrage y restait figé, et passé
  // minuit la tuile félicitait encore pour la séance de la VEILLE. Même
  // défaut, même remède que `consistencyWeekProvider` juste en dessous.
  final today = ref.watch(currentDayProvider);
  for (final entry in history ?? const <WorkoutHistoryEntry>[]) {
    if (entry.session.status != WorkoutStatus.completed) {
      continue;
    }
    final local = entry.session.startedAt.toLocal();
    if (local.year != today.year ||
        local.month != today.month ||
        local.day != today.day) {
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
  // Le jour courant, observé pour la DÉPENDANCE : c'est lui qui fait
  // recalculer le repos au passage de minuit.
  ref.watch(currentDayProvider);
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
    // `DateTime.now()` est ici le bon instant — un REPOS est une durée, pas
    // un jour civil. Ce qui manquait, c'est le réveil : sans la dépendance
    // ci-dessus, ce provider n'était recalculé qu'à une écriture de séance,
    // et « 3 jours de repos » restait affiché une semaine plus tard.
    return rest.isNegative ? Duration.zero : rest;
  }
  return null;
});
