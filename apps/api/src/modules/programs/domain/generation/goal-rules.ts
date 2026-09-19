import { type TrainingGoal } from '@prisma/client';

/**
 * LES RÈGLES PAR OBJECTIF — la table que la tranche existe pour écrire.
 *
 * Un `Record<TrainingGoal, …>` et non une liste : ajouter une neuvième valeur
 * à l'énumération Prisma doit CASSER LA COMPILATION, pas produire en silence
 * un programme vide. Le test d'exhaustivité le vérifie en plus à l'exécution,
 * parce qu'un `as` malheureux suffirait à rouvrir le trou.
 *
 * CHAQUE LIGNE PORTE SA RAISON (`rationale`). Les dosages sont des opinions —
 * 4 × 8 à 120 s, 5 × 5 à 180 s, 12 à 18 séries hebdomadaires — et sans cette
 * phrase le prochain développeur les modifiera sans savoir s'ils en avaient
 * une. Ce n'est pas de la documentation décorative : c'est le seul endroit où
 * le POURQUOI de la prescription est écrit.
 *
 * CE QUI N'EST PAS ICI, et volontairement : la charge. `targetWeightKg` est
 * TOUJOURS nul. Le serveur ne lit ni `PersonalRecord` ni l'historique dans
 * cette tranche, donc il ne sait pas ce que la personne soulève ; prescrire un
 * poids serait l'inventer. La progression passe par les séries, les
 * répétitions et le repos, et la note de l'exercice dit quand monter.
 */

/** Un pas du mésocycle : trois semaines qui montent, une qui décharge. */
export interface MesocycleStep {
  setsDelta: number;
  repsDelta: number;
  restDelta: number;
  deload: boolean;
}

export interface GoalRules {
  /** Durée du plan. Elle suit la logique du bloc, pas une préférence. */
  weeksCount: number;
  /** Fourchette de séances hebdomadaires propre à l'objectif. */
  sessionsMin: number;
  sessionsMax: number;

  repsBase: number;
  repsMin: number;
  repsMax: number;
  /** Repos après une série, en secondes. */
  restPolyarticular: number;
  restIsolation: number;
  restMin: number;
  restMax: number;

  /** Fourchette de séries hebdomadaires, avant multiplicateur d'expérience. */
  prioritySetsMin: number;
  prioritySetsMax: number;
  secondarySetsMin: number;
  secondarySetsMax: number;
  /** Groupes qui reçoivent la fourchette haute. */
  priorityGroups: string[];

  /** Part des séances passées en jour d'endurance à intitulé libre. */
  cardioShare: number;
  /** Plancher de jours d'endurance quand `cardioShare` en accorde moins. */
  cardioFloor: number;

  /** Quatre pas, joués dans l'ordre à partir de la semaine 1. */
  mesocycle: MesocycleStep[];
  /** Répétitions gagnées d'un bloc de quatre semaines au suivant. */
  repsPerBlock: number;

  /**
   * Groupes dont l'absence rend l'objectif DÉFINITIONNELLEMENT impossible.
   *
   * Vide pour la plupart : un trou de catalogue doit se dégrader et se dire,
   * pas fermer la porte. On ne refuse que là où le nom de l'objectif serait
   * un mensonge — de la force sans aucun mouvement de force, de la
   * callisthénie sans le moindre tirage.
   */
  requiredGroups: string[];

  rationale: string;
}

const MONTEE: MesocycleStep[] = [
  { setsDelta: 0, repsDelta: 0, restDelta: 0, deload: false },
  { setsDelta: 1, repsDelta: 1, restDelta: 0, deload: false },
  { setsDelta: 2, repsDelta: 2, restDelta: 0, deload: false },
  { setsDelta: -1, repsDelta: 0, restDelta: 15, deload: true },
];

/** MAINTENANCE : quatre semaines identiques. Un entretien qui monte n'en est plus un. */
const PLAT: MesocycleStep[] = [
  { setsDelta: 0, repsDelta: 0, restDelta: 0, deload: false },
  { setsDelta: 0, repsDelta: 0, restDelta: 0, deload: false },
  { setsDelta: 0, repsDelta: 0, restDelta: 0, deload: false },
  { setsDelta: 0, repsDelta: 0, restDelta: 0, deload: false },
];

/** STRENGTH : les répétitions DESCENDENT — c'est le signal d'intensité. */
const INTENSIFICATION: MesocycleStep[] = [
  { setsDelta: 0, repsDelta: 0, restDelta: 0, deload: false },
  { setsDelta: 0, repsDelta: -1, restDelta: 15, deload: false },
  { setsDelta: 0, repsDelta: -2, restDelta: 30, deload: false },
  { setsDelta: -2, repsDelta: 0, restDelta: 15, deload: true },
];

/** FAT_LOSS : le travail ne change pas, le repos RACCOURCIT. */
const DENSITE: MesocycleStep[] = [
  { setsDelta: 0, repsDelta: 0, restDelta: 30, deload: false },
  { setsDelta: 0, repsDelta: 0, restDelta: 15, deload: false },
  { setsDelta: 0, repsDelta: 0, restDelta: 0, deload: false },
  { setsDelta: -1, repsDelta: 0, restDelta: 30, deload: true },
];

const HAUT_DU_CORPS = ['pectoraux', 'dos', 'epaules'];
const BAS_DU_CORPS = ['quadriceps', 'ischio-jambiers', 'fessiers'];

export const GOAL_RULES: Record<TrainingGoal, GoalRules> = {
  MUSCLE_GAIN: {
    weeksCount: 8,
    sessionsMin: 3,
    sessionsMax: 6,
    repsBase: 10,
    repsMin: 8,
    repsMax: 12,
    restPolyarticular: 90,
    restIsolation: 60,
    restMin: 60,
    restMax: 150,
    prioritySetsMin: 12,
    prioritySetsMax: 18,
    secondarySetsMin: 6,
    secondarySetsMax: 12,
    priorityGroups: [...HAUT_DU_CORPS, 'quadriceps', 'ischio-jambiers'],
    cardioShare: 0,
    cardioFloor: 0,
    mesocycle: MONTEE,
    repsPerBlock: 1,
    requiredGroups: [],
    rationale:
      'L’hypertrophie se pilote au VOLUME : ce sont les séries hebdomadaires par groupe qui produisent l’adaptation, pas le nombre d’exercices d’une séance. Les fourchettes 12-18 (prioritaires) et 6-12 (secondaires) encadrent ce que la littérature d’entraînement donne comme zone productive chez l’intermédiaire ; 8 à 12 répétitions à 90 secondes de repos laissent assez de tension mécanique sans transformer la séance en circuit.',
  },

  STRENGTH: {
    weeksCount: 8,
    sessionsMin: 3,
    sessionsMax: 5,
    repsBase: 5,
    repsMin: 3,
    repsMax: 6,
    restPolyarticular: 180,
    restIsolation: 120,
    restMin: 120,
    restMax: 240,
    prioritySetsMin: 8,
    prioritySetsMax: 12,
    secondarySetsMin: 4,
    secondarySetsMax: 8,
    priorityGroups: [...BAS_DU_CORPS, 'pectoraux', 'dos', 'lombaires'],
    cardioShare: 0,
    cardioFloor: 0,
    mesocycle: INTENSIFICATION,
    repsPerBlock: 0,
    requiredGroups: ['quadriceps', 'dos'],
    rationale:
      'La force se construit en INTENSITÉ, et le serveur ne connaît pas les charges de la personne. Le seul signal d’intensité qu’il puisse écrire est la baisse des répétitions à séries constantes : 5×5, puis 5×4, puis 5×3, avec un repos qui s’allonge de 180 à 210 secondes. Monter les séries à répétitions figées accumulerait du volume, ce qui est un autre objectif.',
  },

  RECOMPOSITION: {
    weeksCount: 8,
    sessionsMin: 3,
    sessionsMax: 6,
    repsBase: 10,
    repsMin: 8,
    repsMax: 12,
    restPolyarticular: 75,
    restIsolation: 60,
    restMin: 60,
    restMax: 120,
    prioritySetsMin: 10,
    prioritySetsMax: 16,
    secondarySetsMin: 6,
    secondarySetsMax: 10,
    priorityGroups: [...HAUT_DU_CORPS, 'quadriceps', 'ischio-jambiers'],
    cardioShare: 0.2,
    cardioFloor: 0,
    mesocycle: MONTEE,
    repsPerBlock: 1,
    requiredGroups: [],
    rationale:
      'Perdre du gras en gardant le muscle demande de PROTÉGER le stimulus de force tout en ajoutant de la dépense. D’où un volume à peine sous celui de la prise de muscle, un repos raccourci à 75 secondes, et un jour d’endurance sur cinq séances plutôt qu’un raccourcissement des repos qui aurait entamé l’intensité.',
  },

  FAT_LOSS: {
    weeksCount: 8,
    sessionsMin: 3,
    sessionsMax: 6,
    repsBase: 12,
    repsMin: 10,
    repsMax: 15,
    restPolyarticular: 60,
    restIsolation: 45,
    restMin: 45,
    restMax: 120,
    prioritySetsMin: 8,
    prioritySetsMax: 14,
    secondarySetsMin: 6,
    secondarySetsMax: 12,
    priorityGroups: [...HAUT_DU_CORPS, ...BAS_DU_CORPS],
    cardioShare: 0.3,
    cardioFloor: 1,
    mesocycle: DENSITE,
    repsPerBlock: 0,
    requiredGroups: [],
    rationale:
      'En déficit, la variable à PROTÉGER est l’intensité : on baisse le repos, jamais la charge relative, et le plancher de repos reste à 45 secondes — en dessous ce n’est plus du renforcement mais du circuit métabolique, et la masse maigre part avec. La progression se fait donc en DENSITÉ : même travail, moins de repos de semaine en semaine.',
  },

  MAINTENANCE: {
    weeksCount: 4,
    sessionsMin: 1,
    sessionsMax: 4,
    repsBase: 10,
    repsMin: 8,
    repsMax: 12,
    restPolyarticular: 90,
    restIsolation: 60,
    restMin: 60,
    restMax: 150,
    prioritySetsMin: 4,
    prioritySetsMax: 9,
    secondarySetsMin: 4,
    secondarySetsMax: 8,
    priorityGroups: [...HAUT_DU_CORPS, ...BAS_DU_CORPS],
    cardioShare: 0.15,
    cardioFloor: 0,
    mesocycle: PLAT,
    repsPerBlock: 0,
    requiredGroups: [],
    rationale:
      'Entretenir, c’est tenir un plancher, pas monter. Le mésocycle est PLAT et il n’y a pas de semaine de décharge : on ne décharge pas une charge d’entretien. Le plan s’arrête à quatre semaines parce qu’au-delà il entretiendrait une routine périmée — l’objectif se rechoisit, il ne se prolonge pas.',
  },

  CALISTHENICS: {
    weeksCount: 8,
    sessionsMin: 3,
    sessionsMax: 6,
    repsBase: 10,
    repsMin: 6,
    repsMax: 15,
    restPolyarticular: 90,
    restIsolation: 60,
    restMin: 60,
    restMax: 150,
    prioritySetsMin: 10,
    prioritySetsMax: 16,
    secondarySetsMin: 4,
    secondarySetsMax: 10,
    priorityGroups: ['dos', 'pectoraux', 'triceps', 'abdominaux'],
    cardioShare: 0,
    cardioFloor: 0,
    mesocycle: MONTEE,
    repsPerBlock: 2,
    requiredGroups: ['dos', 'pectoraux'],
    rationale:
      'Sans charge à ajouter, la progression passe par les RÉPÉTITIONS puis par la variante plus dure du même mouvement. Le plafond de 15 répétitions n’est pas arbitraire : au-delà, on entraîne l’endurance locale et plus la force, donc c’est là qu’il faut changer de mouvement plutôt que d’en faire davantage.',
  },

  HYROX: {
    weeksCount: 12,
    sessionsMin: 3,
    sessionsMax: 6,
    repsBase: 12,
    repsMin: 10,
    repsMax: 15,
    restPolyarticular: 60,
    restIsolation: 45,
    restMin: 45,
    restMax: 90,
    prioritySetsMin: 8,
    prioritySetsMax: 12,
    secondarySetsMin: 4,
    secondarySetsMax: 8,
    priorityGroups: [...BAS_DU_CORPS, 'dos'],
    cardioShare: 0.5,
    cardioFloor: 2,
    mesocycle: MONTEE,
    repsPerBlock: 1,
    requiredGroups: [],
    rationale:
      'Hyrox est une épreuve d’ENDURANCE DE FORCE : huit ateliers entrecoupés de kilomètres. Le renforcement y sert la répétition d’un effort sous fatigue, d’où 3 × 12-15 à 60 secondes de repos plutôt que des séries lourdes. Douze semaines, parce qu’un bloc Hyrox se compte en trois mésocycles.',
  },

  MARATHON: {
    weeksCount: 16,
    sessionsMin: 3,
    sessionsMax: 6,
    repsBase: 12,
    repsMin: 10,
    repsMax: 12,
    restPolyarticular: 60,
    restIsolation: 45,
    restMin: 45,
    restMax: 90,
    prioritySetsMin: 4,
    prioritySetsMax: 8,
    secondarySetsMin: 4,
    secondarySetsMax: 8,
    priorityGroups: [...BAS_DU_CORPS, 'abdominaux', 'lombaires'],
    cardioShare: 0.75,
    cardioFloor: 3,
    mesocycle: PLAT,
    repsPerBlock: 0,
    requiredGroups: [],
    rationale:
      'Le renforcement SERT la course, il ne la concurrence pas : volume volontairement bas et mésocycle PLAT sur les seize semaines, parce qu’on ne fait pas progresser deux choses à la fois. Toute la progression vit dans les jours de course, dont les distances sont une table absolue et non une dérivation de la durée de séance visée — un plan dont la plus longue sortie fait une heure ne prépare pas un marathon.',
  },
};

/** Les deux fourchettes de volume d'un groupe, selon qu'il est prioritaire. */
export function weeklySetsRange(rules: GoalRules, group: string): { min: number; max: number } {
  return rules.priorityGroups.includes(group)
    ? { min: rules.prioritySetsMin, max: rules.prioritySetsMax }
    : { min: rules.secondarySetsMin, max: rules.secondarySetsMax };
}
