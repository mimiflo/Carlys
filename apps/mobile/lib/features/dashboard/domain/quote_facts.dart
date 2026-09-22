/// LES FAITS qui décident de la maxime du jour.
///
/// Une structure plate, et un builder PUR pour la remplir : le choix de la
/// citation devient éprouvable au cas par cas, sans base ni réseau, comme
/// `progression_facts_builder.dart` l'a fait pour le profil.
///
/// Dix faits sur douze sont LOCAUX, et c'est délibéré : le recueil est
/// offline-first, son contexte doit l'être aussi. Les deux exceptions sont
/// dites à l'endroit où elles comptent.
library;

import '../../workout_session/domain/entities/workout.dart';

/// Écart à partir duquel un retour est un RETOUR, et non la séance suivante.
///
/// Dix jours : deux semaines ratées se sentent, cinq jours non. Assez long
/// pour qu'une semaine chargée ne déclenche pas « content de te revoir » à
/// quelqu'un qui n'est jamais parti.
const int retourApresJours = 10;

/// Jours sans séance à partir desquels la pause se dit.
const int pauseApresJours = 4;

/// Jours d'affilée à partir desquels une série se félicite.
const int serieMinimum = 3;

/// Séances dans la semaine au-delà desquelles c'est trop.
///
/// Six : à partir de là, féliciter contredirait la valeur Équilibre — « le
/// repos fait partie de l'entraînement ». La santé passe avant la
/// félicitation, et c'est ce qui place `surcharge` avant `serieEnCours`
/// dans la priorité.
const int surchargeMinimum = 6;

/// Un record est « frais » ce jour-là et le suivant.
const int recordFraisJours = 2;

/// Fenêtre de récupération : après ces heures, le repos a servi ; avant
/// celles-là, il n'a pas fini.
const int recuperationMinHeures = 20;
const int recuperationMaxHeures = 72;

/// Recul de volume à partir duquel la semaine marque le pas.
const double plateauSeuil = 0.9;

/// Jour de la semaine (lundi = 1) à partir duquel une semaine sans séance
/// se dit. Jeudi : avant, il reste trop de temps pour en faire un constat.
const int semaineCreuseDepuis = DateTime.thursday;

/// Les faits du jour, tous déjà lus par l'accueil.
class QuoteFacts {
  const QuoteFacts({
    required this.today,
    this.completedSessions = 0,
    this.lastCompletedAt,
    this.previousCompletedAt,
    this.lastSessionAbandoned = false,
    this.streakDays = 0,
    this.trainedThisWeek = 0,
    this.recentRecordAt,
    this.goalReached = false,
    this.thisWeekVolumeKg = 0,
    this.lastWeekVolumeKg = 0,
    this.masteryPending = false,
  });

  /// Jour de référence, passé en paramètre : le sélecteur reste une
  /// fonction pure de ses entrées.
  final DateTime today;

  final int completedSessions;

  /// Les DEUX dernières séances terminées. La seconde est indispensable :
  /// un retour se mesure à l'écart AVANT la séance d'aujourd'hui, et le
  /// temps depuis la dernière ne le dit pas.
  final DateTime? lastCompletedAt;
  final DateTime? previousCompletedAt;

  /// La séance la plus récente, quelle qu'elle soit, a été abandonnée.
  final bool lastSessionAbandoned;

  final int streakDays;
  final int trainedThisWeek;

  /// Date du record le plus récent. VIENT DU RÉSEAU
  /// (`GET /progress/records`) : hors ligne il est nul, et `recordBattu`
  /// est alors silencieusement faux. Acceptable — le repli reprend la main
  /// et personne ne lit une félicitation fausse — mais à savoir.
  final DateTime? recentRecordAt;

  /// Une cible du jour atteinte. VIENT DU RÉSEAU lui aussi, par les cibles
  /// du rapport métabolique. Même repli, même raison.
  final bool goalReached;

  final double thisWeekVolumeKg;
  final double lastWeekVolumeKg;

  /// L'axe Maîtrise attend encore des faits.
  final bool masteryPending;

  /// Une séance a-t-elle été terminée AUJOURD'HUI ?
  bool get trainedToday {
    final derniere = lastCompletedAt?.toLocal();
    if (derniere == null) {
      return false;
    }
    final jour = today.toLocal();
    return derniere.year == jour.year &&
        derniere.month == jour.month &&
        derniere.day == jour.day;
  }

  /// Jours écoulés depuis la dernière séance terminée, ou `null`.
  int? get daysSinceLast {
    final derniere = lastCompletedAt;
    return derniere == null ? null : joursCivilsEntre(derniere, today);
  }

  /// Heures écoulées depuis la dernière séance terminée, ou `null`.
  int? get hoursSinceLast {
    final derniere = lastCompletedAt;
    return derniere == null ? null : today.difference(derniere).inHours;
  }

  /// L'écart qui a PRÉCÉDÉ la dernière séance — celui qui dit un retour.
  int? get gapBeforeLast {
    final derniere = lastCompletedAt;
    final avant = previousCompletedAt;
    if (derniere == null || avant == null) {
      return null;
    }
    return joursCivilsEntre(avant, derniere);
  }
}

/// Jours civils LOCAUX entre deux instants.
///
/// Par les composantes de date, jamais par une différence d'heures : deux
/// séances à 23 h et 1 h sont à deux heures l'une de l'autre et pourtant à
/// un jour d'écart, et c'est le jour qui compte ici.
///
/// Les deux dates sont reconstruites en UTC. Ce n'est pas un changement de
/// fuseau — les composantes viennent du LOCAL, juste au-dessus — c'est le
/// retrait de l'heure d'été du calcul : dans un fuseau qui avance, la nuit
/// du passage ne dure que 23 heures, et `inDays` rendait alors 0 pour deux
/// jours civils voisins. Un jour par an, « hier » devenait « aujourd'hui ».
///
/// Public parce que la fraîcheur d'un record se compte de la même façon
/// (`quote_selection.dart`), et qu'elle l'avait recomptée autrement.
int joursCivilsEntre(DateTime debut, DateTime fin) {
  final a = debut.toLocal();
  final b = fin.toLocal();
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// Construit les faits depuis l'historique local et ce que le serveur a bien
/// voulu donner. Fonction PURE : ni horloge, ni base, ni réseau.
QuoteFacts buildQuoteFacts({
  required DateTime today,
  required List<WorkoutHistoryEntry> history,
  int streakDays = 0,
  int trainedThisWeek = 0,
  DateTime? recentRecordAt,
  bool goalReached = false,
  double thisWeekVolumeKg = 0,
  double lastWeekVolumeKg = 0,
  bool masteryPending = false,
}) {
  final terminees =
      history
          .where((e) => e.session.status == WorkoutStatus.completed)
          .map((e) => e.session.startedAt)
          .toList()
        ..sort((a, b) => b.compareTo(a));

  // La plus récente TOUTES issues confondues : c'est elle qui dit si la
  // dernière tentative a été abandonnée. Une séance terminée depuis efface
  // l'abandon, et c'est voulu — on ne rappelle pas un échec dépassé.
  final recentes = [...history]
    ..sort((a, b) => b.session.startedAt.compareTo(a.session.startedAt));
  final derniereTentative = recentes.isEmpty ? null : recentes.first.session;

  return QuoteFacts(
    today: today,
    completedSessions: terminees.length,
    lastCompletedAt: terminees.isEmpty ? null : terminees.first,
    previousCompletedAt: terminees.length < 2 ? null : terminees[1],
    lastSessionAbandoned: derniereTentative?.status == WorkoutStatus.abandoned,
    streakDays: streakDays,
    trainedThisWeek: trainedThisWeek,
    recentRecordAt: recentRecordAt,
    goalReached: goalReached,
    thisWeekVolumeKg: thisWeekVolumeKg,
    lastWeekVolumeKg: lastWeekVolumeKg,
    masteryPending: masteryPending,
  );
}
