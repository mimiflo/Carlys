import { type TrainingExperience } from '@prisma/client';

/**
 * Toutes les constantes du générateur, nommées ici et nulle part ailleurs.
 *
 * Aucune valeur littérale ne doit apparaître dans le moteur : une durée de
 * transition écrite à la volée au milieu d'un calcul devient invisible, et
 * personne ne saura plus si 90 était une mesure ou une frappe.
 */

/**
 * Version des RÈGLES, pas du code.
 *
 * Journalisée et écrite au rapport de chaque programme généré. Elle ne rend
 * pas la génération reproductible d'une version à l'autre — c'est impossible
 * et ce n'est pas le but — mais elle rend un programme déjà écrit EXPLICABLE
 * des mois plus tard : on sait quelles règles l'ont produit. À incrémenter
 * dès qu'un dosage, un découpage ou une progression change.
 */
export const GENERATION_RULES_VERSION = 1;

// ── Budget de temps d'une séance ───────────────────────────────────────────

/** Une répétition contrôlée, montée et descente comprises. */
export const TEMPO_SECONDS_PER_REP = 3.5;
/** Plancher d'une série, même à 3 répétitions. */
export const EXEC_SECONDS_MIN = 20;
/** Plafond d'une série, même à 30 répétitions. */
export const EXEC_SECONDS_MAX = 90;
/** Durée d'un maintien ou d'un bloc de cardio, à la place du calcul par reps. */
export const TIMED_SECONDS_DEFAULT = 45;
/** Changement de poste, réglage, mise en place. */
export const TRANSITION_SECONDS = 90;

export const WARMUP_SECONDS_SHORT = 300;
export const WARMUP_SECONDS_STANDARD = 480;
/** Objectif STRENGTH : les séries d'approche coûtent du temps réel. */
export const WARMUP_SECONDS_HEAVY = 600;
/** En deçà de cette durée, l'échauffement passe au format court. */
export const WARMUP_SHORT_THRESHOLD_MINUTES = 30;
/** Retour au calme : court, mais il existe et il occupe la fin de la séance. */
export const COOLDOWN_SECONDS = 180;

/** Dépassement toléré du budget annoncé. */
export const BUDGET_TOLERANCE = 0.05;

/**
 * Sous cette durée, une séance n'est plus une liste de mouvements espacés :
 * c'est un CIRCUIT.
 *
 * Diviser bêtement le budget rend un exercice et demi, ce qui n'est pas une
 * séance. Le format juste n'est pas « moins de mouvements » mais un autre
 * format : repos court, transitions enchaînées, quatre à cinq mouvements.
 */
export const CIRCUIT_THRESHOLD_MINUTES = 25;
export const CIRCUIT_REST_SECONDS = 45;
export const CIRCUIT_TRANSITION_SECONDS = 30;

// ── Bornes de dosage ───────────────────────────────────────────────────────

export const SETS_PER_EXERCISE_MIN = 2;
export const SETS_PER_EXERCISE_MAX = 5;

/**
 * Jamais de séance à un seul exercice.
 *
 * Un quart d'heure rend UN mouvement si on garde 90 secondes de repos et 90 de
 * transition : ce n'est pas une séance courte, c'est un échauffement. Sous
 * `CIRCUIT_THRESHOLD_MINUTES` le format change (voir `session-budget.ts`) et
 * ce plancher garantit qu'au pire on écrit deux mouvements en annonçant le
 * dépassement, plutôt qu'un seul en le taisant.
 */
export const EXERCISES_PER_SESSION_MIN = 2;

/**
 * Plafond d'exercices par séance, PAR EXPÉRIENCE.
 *
 * Un plafond uniforme laisserait un débutant à 90 minutes recevoir douze
 * mouvements parce que le temps le permet. Il n'a ni la technique pour les
 * exécuter ni la capacité de récupération pour en tirer quelque chose : le
 * temps disponible n'est pas une dose d'entraînement.
 */
export const EXERCISES_PER_SESSION_MAX: Record<TrainingExperience, number> = {
  BEGINNER: 6,
  INTERMEDIATE: 8,
  ADVANCED: 10,
};

/** Plafond de séances hebdomadaires, par expérience. */
export const SESSIONS_PER_WEEK_MAX: Record<TrainingExperience, number> = {
  BEGINNER: 4,
  INTERMEDIATE: 6,
  ADVANCED: 7,
};

/** Multiplicateur appliqué aux fourchettes de volume hebdomadaire. */
export const VOLUME_FACTOR: Record<TrainingExperience, number> = {
  BEGINNER: 0.7,
  INTERMEDIATE: 1,
  ADVANCED: 1.2,
};

/** Séries par exercice, avant les ajustements de progression. */
export const SETS_PER_EXERCISE_BASE: Record<TrainingExperience, number> = {
  BEGINNER: 3,
  INTERMEDIATE: 4,
  ADVANCED: 4,
};

/**
 * Sous ce volume hebdomadaire, un groupe n'est pas entraîné : il est décoré.
 * C'est le seuil qui déclenche R6 plutôt qu'un silence poli.
 */
export const WEEKLY_SETS_FLOOR = 4;

/** Au-delà, le volume d'un groupe part sur une autre séance de la semaine. */
export const SETS_PER_GROUP_PER_SESSION_MAX = 10;

/** Un exercice au plus deux fois par semaine — assoupli à 3 par R2. */
export const EXERCISE_WEEKLY_REPEAT_MAX = 2;
export const EXERCISE_WEEKLY_REPEAT_RELAXED = 3;

// ── Mésocycle ──────────────────────────────────────────────────────────────

/** Trois semaines qui montent, une qui décharge. */
export const MESOCYCLE_WEEKS = 4;
/** Repos allongé en semaine de décharge : la fatigue nerveuse tombe aussi. */
export const DELOAD_REST_BONUS_SECONDS = 15;

/**
 * Le débutant progresse par la TECHNIQUE et la régularité, pas par le volume :
 * son gain de répétitions d'un bloc à l'autre est moitié moindre.
 */
export const BLOCK_PROGRESS_FACTOR: Record<TrainingExperience, number> = {
  BEGINNER: 0.5,
  INTERMEDIATE: 1,
  ADVANCED: 1,
};

// ── Sélection ──────────────────────────────────────────────────────────────

/**
 * Au-delà de ce nombre de répétitions au poids du corps, on travaille
 * l'endurance locale — plus la force ni l'hypertrophie. Le générateur passe
 * alors à la variante plus dure si elle existe et que le niveau l'autorise.
 */
export const BODYWEIGHT_VARIANT_THRESHOLD_REPS = 15;

/** Poids de score : ce que le moteur préfère, et de combien. */
export const SCORE_POLYARTICULAR = 3;
export const SCORE_BEGINNER_TAG = 2;
export const SCORE_ISOLATION_PENALTY = 2;

/** Tag qui marque un maintien : la série se compte en secondes, pas en reps. */
export const ISOMETRIC_TAG = 'isometrique';

/** Le kit contient toujours le poids du corps : on s'entraîne avec, ou sans. */
export const BODYWEIGHT_SLUG = 'poids-du-corps';

// ── Placement des jours ────────────────────────────────────────────────────

/**
 * Où tombent les séances dans la semaine, par nombre de séances (1 = lundi).
 *
 * Table figée : le placement est donc déterministe, et l'espacement se
 * vérifie en le lisant. La contrainte de récupération (H2) le contrôle
 * ensuite sur les GROUPES réellement chargés, ce qu'une table ne peut pas
 * garantir toute seule.
 */
export const DAY_PLACEMENT: Record<number, number[]> = {
  1: [3],
  2: [1, 4],
  3: [1, 3, 5],
  4: [1, 2, 4, 5],
  5: [1, 2, 3, 5, 6],
  6: [1, 2, 3, 4, 5, 6],
  7: [1, 2, 3, 4, 5, 6, 7],
};

/** Distance minimale entre deux séances chargeant lourdement le même groupe. */
export const RECOVERY_MIN_DAYS = 2;
/** En deçà de ce volume, un groupe est seulement sollicité : 1 jour suffit. */
export const RECOVERY_HEAVY_SETS = 4;

/** Namespace des identifiants dérivés de la génération. */
export const GENERATION_UUID_NAMESPACE = 'carlys.program.generation';

/**
 * Le RATIO TIRAGE / POUSSÉE — contrainte H9, la seule qui protège l'épaule.
 *
 * Le refus d'un objectif entier traite le cas extrême (plus aucun exercice de
 * dos) ; rien ne bordait le cas intermédiaire, qui est le fréquent. Un kit
 * mince donne souvent une poussée abondante et un tirage famélique, et huit
 * semaines à ce régime, ce n'est pas « un programme pauvre » : c'est le
 * protocole d'enroulement d'épaules, chez la personne la moins outillée pour
 * s'en apercevoir.
 *
 * 0,66 et non 1 : l'équilibre parfait n'est pas atteignable sur un catalogue
 * où le tirage sans matériel tient à un exercice. Sous ce seuil, le rapport le
 * NOMME — c'est une information, pas un refus.
 */
export const PULL_TO_PUSH_MIN_RATIO = 0.66;
export const PUSH_GROUPS = ['pectoraux', 'epaules', 'triceps'];
export const PULL_GROUPS = ['dos', 'biceps'];

/**
 * Le groupe VOISIN d'un groupe, quand le sien n'a plus rien à offrir.
 *
 * Une table explicite plutôt qu'une heuristique : « quadriceps » se replie sur
 * les fessiers, pas sur les biceps. Chaque report est inscrit au rapport, donc
 * personne ne croit avoir entraîné ce qu'il n'a pas entraîné.
 */
export const GROUP_NEIGHBOURS: Record<string, string[]> = {
  quadriceps: ['fessiers', 'ischio-jambiers'],
  'ischio-jambiers': ['fessiers', 'lombaires'],
  fessiers: ['ischio-jambiers', 'quadriceps'],
  pectoraux: ['triceps', 'epaules'],
  dos: ['biceps', 'lombaires'],
  epaules: ['pectoraux', 'triceps'],
  biceps: ['dos'],
  triceps: ['pectoraux', 'epaules'],
  lombaires: ['abdominaux', 'fessiers'],
  abdominaux: ['lombaires'],
  mollets: ['quadriceps'],
  'avant-bras': ['biceps'],
};
