import { type ChallengeKind, type ChallengeMetric } from '@prisma/client';

/**
 * Catalogue des défis du mois.
 *
 * Défini dans le CODE, pas dans le seed : le seed ne tourne qu'au
 * développement, et un défi créé une fois avec une date de fin fixe laissait
 * la liste vide pour toujours au bout d'un mois. Ici, chaque mois reçoit le
 * même jeu, matérialisé à la première lecture (voir
 * `CommunityChallengesService.ensureMonthlyChallenges`).
 *
 * Les objectifs sont exprimés dans l'unité RÉELLEMENT comptée, et cette
 * unité est désormais une DONNÉE (`metric`) et non plus une phrase : c'est
 * elle qui décide ce qu'un défi additionne, et elle qui permet à l'écran
 * d'écrire « 127 / 500 séances » plutôt qu'une barre sans légende. Les textes
 * sont visibles dans l'application (tutoiement, pas de tiret cadratin).
 */
export interface ChallengeTemplate {
  readonly slug: string;
  readonly kind: ChallengeKind;
  readonly metric: ChallengeMetric;
  readonly title: string;
  readonly description: string;
  readonly target: number;
}

/**
 * Comment une quantité se dit, au singulier et au pluriel.
 *
 * Servi par l'API plutôt que traduit par le client : les titres et les
 * descriptions des défis viennent déjà du serveur, et deux endroits où
 * nommer la même unité, c'est un endroit de trop pour la faire diverger.
 */
export const METRIC_UNITS: Readonly<Record<ChallengeMetric, string>> = {
  WORKOUTS: 'séances',
  QUIZ_CORRECT: 'bonnes réponses',
  ACTIVE_SECONDS: 'secondes d’effort',
  DISTANCE_METERS: 'mètres',
};

export const MONTHLY_CHALLENGE_CATALOG: readonly ChallengeTemplate[] = [
  {
    slug: 'seances-du-mois',
    kind: 'SPORT',
    metric: 'WORKOUTS',
    title: '500 séances à plusieurs',
    description:
      'Chaque séance que tu termines ce mois-ci s’ajoute au compteur du groupe. ' +
      'Objectif : 500 séances avant la fin du mois.',
    target: 500,
  },
  {
    slug: 'quiz-du-mois',
    kind: 'CULTURE',
    metric: 'QUIZ_CORRECT',
    title: 'Le quiz du mois',
    description:
      'Chaque bonne réponse dans l’Academy compte, une par leçon et par jour. ' +
      'Objectif : 300 bonnes réponses ensemble.',
    target: 300,
  },
  {
    slug: 'distance-du-mois',
    kind: 'SPORT',
    metric: 'DISTANCE_METERS',
    title: '500 km à plusieurs',
    description:
      'Chaque mètre parcouru dans une séance compte : course, rameur, vélo. ' +
      'Objectif : 500 000 mètres avant la fin du mois.',
    // En MÈTRES, l'unité réellement saisie série par série. Convertir en
    // kilomètres pour l'affichage est le travail de l'écran ; le compteur,
    // lui, additionne ce que les gens déclarent.
    target: 500_000,
  },
];

/** Un défi prêt à être écrit en base pour un mois donné. */
export interface MonthlyChallengeSeed extends ChallengeTemplate {
  readonly month: string;
  readonly startsAt: Date;
  readonly endsAt: Date;
}

export interface MonthWindow {
  /** `YYYY-MM`, en UTC. */
  readonly month: string;
  /** Premier jour du mois, minuit UTC (inclus). */
  readonly startsAt: Date;
  /** Premier jour du mois SUIVANT, minuit UTC (exclu). */
  readonly endsAt: Date;
}

/**
 * Le mois qui contient `now`, découpé en UTC : les défis sont collectifs et
 * ont besoin d'un seul calendrier pour tout le monde. Les dates sont
 * stockées et échangées en UTC dans tout le dépôt ; le mois l'est aussi.
 */
export function monthWindowUtc(now: Date): MonthWindow {
  const year = now.getUTCFullYear();
  const monthIndex = now.getUTCMonth();
  const startsAt = new Date(Date.UTC(year, monthIndex, 1));
  // Date.UTC normalise décembre + 1 en janvier de l'année suivante.
  const endsAt = new Date(Date.UTC(year, monthIndex + 1, 1));
  return { month: startsAt.toISOString().slice(0, 7), startsAt, endsAt };
}

/** Le jeu complet du mois de `now`, prêt pour `createMany`. */
export function buildMonthlyChallenges(now: Date): MonthlyChallengeSeed[] {
  const window = monthWindowUtc(now);
  return MONTHLY_CHALLENGE_CATALOG.map((template) => ({ ...template, ...window }));
}
