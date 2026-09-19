import { type TrainingExperience } from '@prisma/client';
import {
  BLOCK_PROGRESS_FACTOR,
  MESOCYCLE_WEEKS,
  SETS_PER_EXERCISE_BASE,
  SETS_PER_EXERCISE_MAX,
  SETS_PER_EXERCISE_MIN,
} from './constants';
import { type GoalRules } from './goal-rules';

/**
 * LA PROGRESSION — ce qui distingue un programme d'une séance répétée.
 *
 * Deux échelles se superposent :
 *
 * 1. LE MÉSOCYCLE, sur quatre semaines : trois qui montent, une qui décharge.
 *    Il vient de la ligne de l'objectif (`GoalRules.mesocycle`).
 * 2. LE BLOC, tous les quatre mésocycles de semaines : la semaine 5 repart
 *    AU-DESSUS de la semaine 1, pas à son niveau.
 *
 * La seconde échelle n'est pas un raffinement : sans elle, un programme de
 * huit semaines progresse sur quatre semaines, deux fois — il entretient au
 * lieu de développer, et la personne stagne à partir de la cinquième semaine
 * sans comprendre pourquoi.
 *
 * MAINTENANCE échappe aux deux, et c'est la définition de l'objectif : son
 * mésocycle est plat et son gain par bloc est nul.
 */

export interface Prescription {
  sets: number;
  /** `null` pour un maintien ou un bloc de cardio : la durée est en note. */
  reps: number;
  restSeconds: number;
  /** La semaine est une décharge : le libellé du jour le dira. */
  deload: boolean;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

/**
 * Le dosage d'un exercice à la semaine `week` (1 = première semaine).
 *
 * `polyarticular` change le repos, pas les répétitions : un squat et un curl
 * se font sur la même fourchette de reps, mais pas avec le même temps de
 * récupération.
 */
export function prescriptionFor(
  rules: GoalRules,
  experience: TrainingExperience,
  week: number,
  polyarticular: boolean,
): Prescription {
  const step = rules.mesocycle[(week - 1) % MESOCYCLE_WEEKS]!;
  const block = Math.floor((week - 1) / MESOCYCLE_WEEKS);
  const blockReps = Math.round(block * rules.repsPerBlock * BLOCK_PROGRESS_FACTOR[experience]);

  const baseSets = SETS_PER_EXERCISE_BASE[experience];
  const baseRest = polyarticular ? rules.restPolyarticular : rules.restIsolation;

  return {
    sets: clamp(baseSets + step.setsDelta, SETS_PER_EXERCISE_MIN, SETS_PER_EXERCISE_MAX),
    reps: clamp(rules.repsBase + step.repsDelta + blockReps, rules.repsMin, rules.repsMax),
    restSeconds: clamp(baseRest + step.restDelta, rules.restMin, rules.restMax),
    deload: step.deload,
  };
}

/** Le suffixe du libellé d'un jour de décharge. */
export const DELOAD_LABEL_SUFFIX = ' (semaine allégée)';

/**
 * Une semaine allégée que l'utilisateur ne voit pas est une semaine qu'il
 * croit ratée — et qu'il surcharge pour se rattraper, ce qui annule
 * exactement la décharge. Le libellé du jour la NOMME.
 */
export function dayLabel(slotName: string, deload: boolean): string {
  return deload ? `${slotName}${DELOAD_LABEL_SUFFIX}` : slotName;
}
