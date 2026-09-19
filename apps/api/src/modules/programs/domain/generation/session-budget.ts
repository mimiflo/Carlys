import { type TrainingExperience, TrainingGoal } from '@prisma/client';
import {
  BUDGET_TOLERANCE,
  COOLDOWN_SECONDS,
  EXERCISES_PER_SESSION_MIN,
  CIRCUIT_REST_SECONDS,
  CIRCUIT_THRESHOLD_MINUTES,
  CIRCUIT_TRANSITION_SECONDS,
  EXEC_SECONDS_MAX,
  EXEC_SECONDS_MIN,
  EXERCISES_PER_SESSION_MAX,
  TEMPO_SECONDS_PER_REP,
  TIMED_SECONDS_DEFAULT,
  TRANSITION_SECONDS,
  WARMUP_SECONDS_HEAVY,
  WARMUP_SECONDS_SHORT,
  WARMUP_SECONDS_STANDARD,
  WARMUP_SHORT_THRESHOLD_MINUTES,
} from './constants';

/**
 * LE BUDGET DE TEMPS — contrainte H3.
 *
 * Ce n'est pas un garde-fou posé après coup : c'est lui qui DÉTERMINE le
 * nombre d'exercices, avant toute sélection. Choisir d'abord les mouvements
 * puis tronquer produit une séance dont on a coupé la fin, c'est-à-dire dont
 * on a supprimé le tronc et les mollets — toujours les derniers de la liste.
 */

/** Le format d'une séance courte n'est pas « moins », c'est AUTRE CHOSE. */
export interface SessionFormat {
  circuit: boolean;
  transitionSeconds: number;
  /** Repos imposé en circuit ; `null` laisse la règle de l'objectif décider. */
  restOverrideSeconds: number | null;
}

export function formatFor(sessionMinutes: number): SessionFormat {
  if (sessionMinutes > CIRCUIT_THRESHOLD_MINUTES) {
    return { circuit: false, transitionSeconds: TRANSITION_SECONDS, restOverrideSeconds: null };
  }
  // Sous 25 minutes, garder 90 s de repos et 90 s de transition rendrait UN
  // exercice et demi. On apparie les mouvements et on raccourcit le repos :
  // quatre à cinq mouvements tiennent dans le même quart d'heure.
  return {
    circuit: true,
    transitionSeconds: CIRCUIT_TRANSITION_SECONDS,
    restOverrideSeconds: CIRCUIT_REST_SECONDS,
  };
}

export function warmupSeconds(goal: TrainingGoal, sessionMinutes: number): number {
  if (goal === TrainingGoal.STRENGTH) return WARMUP_SECONDS_HEAVY;
  return sessionMinutes <= WARMUP_SHORT_THRESHOLD_MINUTES
    ? WARMUP_SECONDS_SHORT
    : WARMUP_SECONDS_STANDARD;
}

/** Durée d'exécution d'une série : bornée, parce qu'un tempo n'est pas linéaire. */
export function executionSeconds(reps: number | null): number {
  if (reps === null) return TIMED_SECONDS_DEFAULT;
  return Math.min(
    Math.max(Math.round(reps * TEMPO_SECONDS_PER_REP), EXEC_SECONDS_MIN),
    EXEC_SECONDS_MAX,
  );
}

/**
 * Coût d'un exercice : transition, puis les séries, MOINS le dernier repos.
 *
 * On ne se repose pas après la dernière série. L'oublier gonfle l'estimation
 * de 90 secondes par exercice, soit six minutes sur une séance de quatre —
 * assez pour que le générateur retire un mouvement qui tenait.
 */
export function exerciseSeconds(
  sets: number,
  reps: number | null,
  restSeconds: number,
  format: SessionFormat,
): number {
  const exec = executionSeconds(reps);
  return format.transitionSeconds + sets * (exec + restSeconds) - restSeconds;
}

export interface BudgetPlan {
  /** Secondes réellement disponibles, tolérance comprise. */
  budgetSeconds: number;
  warmupSeconds: number;
  exerciseCount: number;
  format: SessionFormat;
  /** Le plancher de deux exercices a mordu : la séance dépasse son budget. */
  overBudget: boolean;
}

/**
 * Combien d'exercices tiennent, en forme fermée.
 *
 * Le plafond par expérience mord souvent avant le temps, et c'est voulu : un
 * débutant à 90 minutes ne doit pas recevoir dix mouvements parce que le
 * temps le permet. Le reliquat de budget n'est PAS dépensé — une séance
 * d'hypertrophie de quatre heures n'existe pas.
 */
export function planBudget(
  goal: TrainingGoal,
  experience: TrainingExperience,
  sessionMinutes: number,
  setsPerExercise: number,
  reps: number | null,
  restSeconds: number,
  poolSize: number,
): BudgetPlan {
  const format = formatFor(sessionMinutes);
  const rest = format.restOverrideSeconds ?? restSeconds;
  const warmup = warmupSeconds(goal, sessionMinutes);
  const budget = Math.round(sessionMinutes * 60 * (1 + BUDGET_TOLERANCE));
  const perExercise = exerciseSeconds(setsPerExercise, reps, rest, format);
  const affordable = Math.floor((budget - warmup - COOLDOWN_SECONDS) / perExercise);
  const ceiling = Math.min(EXERCISES_PER_SESSION_MAX[experience], poolSize);
  // Le plancher gagne contre le budget, jamais contre le pool : on préfère
  // annoncer un dépassement que rendre une séance d'un seul mouvement.
  const wanted = Math.max(affordable, EXERCISES_PER_SESSION_MIN);
  const count = Math.min(wanted, Math.max(ceiling, 1));
  return {
    budgetSeconds: budget,
    warmupSeconds: warmup,
    exerciseCount: count,
    format,
    overBudget: count > affordable,
  };
}

/** Durée réelle d'une séance déjà composée — ce que le rapport annonce. */
export function estimateSessionSeconds(
  warmup: number,
  exercises: { sets: number; reps: number | null; restSeconds: number }[],
  format: SessionFormat,
): number {
  return exercises.reduce(
    (total, exercise) =>
      total + exerciseSeconds(exercise.sets, exercise.reps, exercise.restSeconds, format),
    warmup,
  );
}
