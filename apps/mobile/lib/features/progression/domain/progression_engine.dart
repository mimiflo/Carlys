/// Le calcul du profil de progression : une FONCTION PURE, des faits vers
/// cinq axes.
///
/// Pure au sens strict : ni horloge, ni base, ni réseau. Le jour de
/// référence entre par [ProgressionFacts.today]. C'est ce qui rend le barème
/// vérifiable au cas par cas, et ce qui garantit que deux appareils affichent
/// le même profil pour les mêmes faits.
library;

import 'dart:math' as math;

import 'progression.dart';

/// Fenêtre d'observation, en jours.
///
/// Quatre semaines : assez long pour qu'une semaine creuse ne fasse pas
/// chuter le profil, assez court pour qu'une reprise se voie tout de suite.
/// C'est la traduction chiffrée de « aucun axe ne punit une absence ».
const int observationDays = 28;

/// Semaines observées par l'axe de constance.
const int constancyWeeks = 8;

/// Les faits nécessaires au calcul, tous LOCAUX et disponibles hors ligne.
///
/// Le choix du local n'est pas un détail d'implémentation : le profil doit
/// s'afficher dans le métro. Les records et les statistiques du serveur
/// racontent la même histoire, mais ils ne sont pas là quand le réseau
/// manque, et un profil qui disparaît hors ligne ne vaut rien.
class ProgressionFacts {
  const ProgressionFacts({
    required this.today,
    this.completedSessionDays = const [],
    this.startedSessions = 0,
    this.completedSessions = 0,
    this.recentVolumeKg = 0,
    this.previousVolumeKg = 0,
    this.lessonsAnswered = 0,
    this.lessonsTotal = 0,
  });

  /// Jour de référence. Entre par paramètre : voir l'en-tête du fichier.
  final DateTime today;

  /// Jours civils où au moins une séance a été TERMINÉE, sans doublon.
  final List<DateTime> completedSessionDays;

  /// Séances commencées sur la fenêtre d'observation.
  final int startedSessions;

  /// Séances terminées sur la fenêtre d'observation.
  final int completedSessions;

  /// Volume soulevé sur les quatre dernières semaines, en kilos.
  final double recentVolumeKg;

  /// Volume soulevé sur les quatre semaines d'avant, en kilos.
  final double previousVolumeKg;

  /// Leçons de l'Academy auxquelles l'utilisateur a répondu.
  final int lessonsAnswered;

  /// Taille du pack de leçons.
  final int lessonsTotal;
}

/// Calcule le profil.
ProgressionProfile computeProgression(ProgressionFacts facts) {
  return ProgressionProfile(
    axes: [
      _constance(facts),
      _maitrise(facts),
      _performance(facts),
      _discipline(facts),
      _equilibre(facts),
    ],
  );
}

int _pointsFor(double ratio) => (ratio.clamp(0.0, 1.0) * maxAxisPoints).round();

/// Numéro de jour civil, pour comparer des dates sans se soucier de l'heure.
int _dayNumber(DateTime date) {
  final local = date.toLocal();
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(1970)).inDays;
}

/// CONSTANCE — reviens-tu ?
///
/// Compte les SEMAINES où au moins une séance a été terminée, sur les huit
/// dernières. La semaine plutôt que le jour, délibérément : personne ne
/// s'entraîne tous les jours, et compter les jours ferait de la constance un
/// objectif inatteignable, donc décourageant.
ProgressionAxis _constance(ProgressionFacts facts) {
  if (facts.completedSessionDays.isEmpty) {
    return const ProgressionAxis.unknown(
      CarlysValue.constance,
      'Ta première séance ouvrira cet axe.',
    );
  }

  final todayNumber = _dayNumber(facts.today);
  final weeks = <int>{};
  for (final day in facts.completedSessionDays) {
    final age = todayNumber - _dayNumber(day);
    if (age < 0 || age >= constancyWeeks * 7) {
      continue;
    }
    weeks.add(age ~/ 7);
  }

  final ratio = weeks.length / constancyWeeks;
  final plural = weeks.length > 1 ? 's' : '';
  return ProgressionAxis(
    value: CarlysValue.constance,
    ratio: ratio,
    points: _pointsFor(ratio),
    reason:
        '${weeks.length} semaine$plural avec séance '
        'sur les $constancyWeeks dernières.',
  );
}

/// MAÎTRISE — comprends-tu ce que tu fais ?
///
/// La part du pack de l'Academy à laquelle l'utilisateur a répondu. Répondre
/// suffit : se tromper fait apprendre, et n'accorder les points qu'aux bonnes
/// réponses transformerait l'Academy en examen.
ProgressionAxis _maitrise(ProgressionFacts facts) {
  if (facts.lessonsTotal <= 0 || facts.lessonsAnswered <= 0) {
    return const ProgressionAxis.unknown(
      CarlysValue.maitrise,
      'Réponds à une question de l’Academy pour ouvrir cet axe.',
    );
  }

  // Borné comme les points : un pack raccourci après coup, ou un
  // décompte incohérent, ne doit pas produire une jauge qui déborde.
  final ratio = (facts.lessonsAnswered / facts.lessonsTotal).clamp(0.0, 1.0);
  return ProgressionAxis(
    value: CarlysValue.maitrise,
    ratio: ratio,
    points: _pointsFor(ratio),
    reason:
        '${facts.lessonsAnswered} leçons abordées '
        'sur ${facts.lessonsTotal}.',
  );
}

/// PERFORMANCE — progresses-tu ?
///
/// Compare le volume des quatre dernières semaines à celui des quatre
/// précédentes. C'est une TENDANCE, pas un total : mesurer le volume absolu
/// avantagerait mécaniquement les plus lourds et les plus anciens, alors que
/// la promesse de la marque est de progresser depuis là où l'on est.
///
/// Le maintien vaut déjà la moitié des points : tenir son niveau n'est pas
/// un échec, et une blessure ou une sèche ne doivent pas vider l'axe.
ProgressionAxis _performance(ProgressionFacts facts) {
  if (facts.recentVolumeKg <= 0) {
    return const ProgressionAxis.unknown(
      CarlysValue.performance,
      'Note tes charges sur une séance pour ouvrir cet axe.',
    );
  }
  if (facts.previousVolumeKg <= 0) {
    // Rien à comparer : on crédite le maintien plutôt que d'inventer une
    // progression, et la phrase le dit franchement.
    return ProgressionAxis(
      value: CarlysValue.performance,
      ratio: 0.5,
      points: _pointsFor(0.5),
      reason:
          'Premier bloc enregistré : la comparaison arrive '
          'dans quatre semaines.',
    );
  }

  final change =
      (facts.recentVolumeKg - facts.previousVolumeKg) / facts.previousVolumeKg;
  // −20 % vide l'axe, le maintien le remplit à moitié, +20 % le remplit.
  final ratio = (0.5 + change / 0.4).clamp(0.0, 1.0);
  final percent = (change * 100).round();
  final wording = percent > 0
      ? 'Volume en hausse de $percent % sur quatre semaines.'
      : percent < 0
      ? 'Volume en baisse de ${percent.abs()} % : un bloc plus léger '
            'fait partie du chemin.'
      : 'Volume stable sur quatre semaines.';

  return ProgressionAxis(
    value: CarlysValue.performance,
    ratio: ratio,
    points: _pointsFor(ratio),
    reason: wording,
  );
}

/// DISCIPLINE — tiens-tu ce que tu as prévu ?
///
/// La part des séances COMMENCÉES qui sont allées jusqu'à la clôture. Une
/// séance écourtée mais close tient l'engagement ; c'est l'abandon en cours
/// de route que l'axe distingue, pas la longueur.
ProgressionAxis _discipline(ProgressionFacts facts) {
  if (facts.startedSessions <= 0) {
    return const ProgressionAxis.unknown(
      CarlysValue.discipline,
      'Ta première séance ouvrira cet axe.',
    );
  }

  final ratio = (facts.completedSessions / facts.startedSessions).clamp(
    0.0,
    1.0,
  );
  return ProgressionAxis(
    value: CarlysValue.discipline,
    ratio: ratio,
    points: _pointsFor(ratio),
    reason:
        '${facts.completedSessions} séances terminées '
        'sur ${facts.startedSessions} commencées.',
  );
}

/// ÉQUILIBRE — récupères-tu ?
///
/// Vise deux à quatre séances par semaine sur la fenêtre d'observation. Les
/// deux bords coûtent des points, et c'est tout l'intérêt de l'axe : trop peu
/// ne construit pas, trop souvent ne laisse pas récupérer. Un axe qui
/// récompenserait le volume maximal contredirait la valeur qu'il porte.
ProgressionAxis _equilibre(ProgressionFacts facts) {
  final todayNumber = _dayNumber(facts.today);
  final days = facts.completedSessionDays
      .where((day) {
        final age = todayNumber - _dayNumber(day);
        return age >= 0 && age < observationDays;
      })
      .map(_dayNumber)
      .toSet();

  if (days.isEmpty) {
    return const ProgressionAxis.unknown(
      CarlysValue.equilibre,
      'Cet axe s’ouvre dès que tu t’entraînes régulièrement.',
    );
  }

  const weeks = observationDays / 7;
  final perWeek = days.length / weeks;
  // Plein entre 2 et 4 séances par semaine, dégressif de part et d'autre.
  final double ratio;
  if (perWeek < 2) {
    ratio = perWeek / 2;
  } else if (perWeek <= 4) {
    ratio = 1;
  } else {
    ratio = math.max(0, 1 - (perWeek - 4) / 3);
  }

  final rounded = perWeek.toStringAsFixed(1).replaceAll('.', ',');
  final wording = perWeek > 4
      ? '$rounded séances par semaine : pense à intercaler du repos.'
      : perWeek < 2
      ? '$rounded séance par semaine : une de plus ouvrirait l’axe.'
      : '$rounded séances par semaine, et du repos entre les deux.';

  return ProgressionAxis(
    value: CarlysValue.equilibre,
    ratio: ratio,
    points: _pointsFor(ratio),
    reason: wording,
  );
}
