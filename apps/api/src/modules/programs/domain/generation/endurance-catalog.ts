import { TrainingGoal } from '@prisma/client';

/**
 * LES JOURS D'ENDURANCE — des intitulés, parce que le catalogue n'a rien
 * d'autre à offrir.
 *
 * Vérifié avant d'être écrit : le catalogue ne contient aucun mouvement de
 * course, de rameur, de vélo, de corde à sauter, de SkiErg, de traîneau, de
 * farmer's carry, de sandbag lunge ni de wall ball. Et `WorkoutTemplateSet`
 * n'a ni durée ni distance — « 8 × 400 m » n'aurait aucun champ où se loger.
 *
 * On aurait pu inventer huit exercices « course », « rameur », « traîneau ».
 * Refusé : sans `targetDurationSeconds` ni `targetDistanceMeters` sur la
 * série, ils porteraient des répétitions qui n'ont aucun sens (« 3 × 10
 * courses ») et empoisonneraient `PersonalRecord`. L'ordre correct est la
 * migration des cibles temps/distance D'ABORD, les exercices d'endurance
 * ENSUITE, les intitulés libres en attendant.
 *
 * `ProgramDay` accepte exactement cela : un `label` obligatoire avec
 * `templateId` nul. Le rapport annonce combien de jours sont dans ce cas,
 * parce que ces séances-là ne produiront ni séance enregistrée, ni record, ni
 * courbe de progression dans l'application.
 */

/** Les distances de sortie longue, en minutes, semaine par semaine. */
const MARATHON_LONG_RUN_MINUTES = [
  60, 70, 80, 60, 85, 95, 105, 70, 110, 120, 130, 85, 140, 150, 100, 60,
];

/**
 * Table ABSOLUE, et c'est le point.
 *
 * Dériver ces durées de `sessionMinutesTarget` — un champ que le contrat borne
 * à 15..240 pour décrire une séance de MUSCULATION — produirait, à sa valeur
 * courante, un plan dont la plus longue sortie fait une heure. Personne ne
 * termine un marathon là-dessus, et tenter 42 km après un tel plan est un
 * risque réel. Le pic est ici à 2 h 30, qui est le pic standard d'un premier
 * marathon, et les trois dernières semaines sont un affûtage descendant.
 */
function marathonLabel(week: number, position: number): string {
  const long = MARATHON_LONG_RUN_MINUTES[Math.min(week, MARATHON_LONG_RUN_MINUTES.length) - 1]!;
  const allegee = week % 4 === 0;
  const affutage = week >= MARATHON_LONG_RUN_MINUTES.length - 2;
  switch (position) {
    case 0: {
      if (week === MARATHON_LONG_RUN_MINUTES.length)
        return 'Sortie longue 60 min — course dimanche';
      const mention = affutage ? ' (affûtage)' : allegee ? ' (semaine allégée)' : '';
      return `Sortie longue ${long} min${mention}`;
    }
    case 1: {
      // Six répétitions au départ, une de plus toutes les deux semaines,
      // plafond à douze, et retour à six les semaines allégées.
      const repetitions = allegee ? 6 : Math.min(6 + Math.floor((week - 1) / 2), 12);
      return `Fractionné ${repetitions} × 400 m, récupération 1 min`;
    }
    default:
      return `Endurance fondamentale ${allegee ? 30 : 45} min`;
  }
}

/** Le vocabulaire réel des ateliers de l'épreuve, et leur montée en volume. */
function hyroxLabel(week: number, position: number): string {
  const tours = Math.min(4 + Math.floor((week - 1) / 3), 8);
  return position === 0
    ? `Stations : ${tours} × (500 m rameur + 20 fentes lestées)`
    : `Stations : ${tours} × (1 km course + 50 m traîneau)`;
}

/** Une marche, un footing : de quoi dépenser sans concurrencer la séance. */
function generalCardioLabel(week: number, position: number): string {
  const minutes = 30 + Math.min(Math.floor((week - 1) / 2), 3) * 5;
  return position === 0 ? `Cardio modéré ${minutes} min` : `Marche rapide ${minutes + 10} min`;
}

/**
 * L'intitulé du `position`-ième jour d'endurance de la semaine `week`.
 *
 * `ProgramDay.label` est borné à 120 caractères par le contrat : le plus long
 * intitulé produit ici en fait 46, et le test le vérifie sur toutes les
 * semaines de tous les objectifs plutôt que sur un échantillon.
 */
export function enduranceLabel(goal: TrainingGoal, week: number, position: number): string {
  switch (goal) {
    case TrainingGoal.MARATHON:
      return marathonLabel(week, position);
    case TrainingGoal.HYROX:
      return hyroxLabel(week, position);
    default:
      return generalCardioLabel(week, position);
  }
}

/**
 * Ce que le rapport doit dire quand des jours ne portent pas de modèle.
 *
 * Sur un plan marathon à quatre séances, trois quarts des jours actifs ne
 * produiront AUCUNE donnée dans Carlys. L'utilisateur doit l'apprendre du
 * générateur, pas de sa propre déception au bout de trois semaines.
 */
export const FREE_LABEL_NOTE =
  'Les jours de course et d’ateliers sont planifiés mais pas détaillés : le ' +
  'catalogue Carlys ne contient aucun exercice de course, de rameur ni de ' +
  'traîneau. Ces journées ne seront pas enregistrées comme des séances.';
