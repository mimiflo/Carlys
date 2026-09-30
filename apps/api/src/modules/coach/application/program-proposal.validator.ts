import {
  TRAINING_SESSION_MINUTES_MAX,
  TRAINING_SESSION_MINUTES_MIN,
  TRAINING_WEEKLY_SESSIONS_MAX,
  TRAINING_WEEKLY_SESSIONS_MIN,
} from '@carlys/api-contracts';
import { TrainingGoal } from '@prisma/client';

/**
 * Validation d'un programme proposé par le modèle.
 *
 * Le coach ne compose pas le programme : il en choisit les RÉGLAGES, que le
 * générateur du module `programs` transforme en plan. Les bornes sont celles
 * du profil d'entraînement — l'écran de préparation et le coach ne peuvent
 * pas diverger. Le motif d'un refus revient au modèle, qui corrige : il dit
 * donc quoi changer.
 *
 * Fonction pure : aucune base, aucun réseau.
 */
export interface ValidatedProgramProposal {
  goal: TrainingGoal;
  weeklySessions: number;
  sessionMinutes: number;
}

export type ProgramProposalValidation =
  { ok: true; proposal: ValidatedProgramProposal } | { ok: false; reason: string };

const GOALS = Object.values(TrainingGoal) as string[];

export function validateProgramProposal(raw: Record<string, unknown>): ProgramProposalValidation {
  const { goal, weeklySessions, sessionMinutes } = raw;
  if (typeof goal !== 'string' || !GOALS.includes(goal)) {
    return { ok: false, reason: `goal doit valoir l’un de : ${GOALS.join(', ')}.` };
  }
  if (!isIntegerIn(weeklySessions, TRAINING_WEEKLY_SESSIONS_MIN, TRAINING_WEEKLY_SESSIONS_MAX)) {
    return {
      ok: false,
      reason: `weeklySessions doit être un entier entre ${TRAINING_WEEKLY_SESSIONS_MIN} et ${TRAINING_WEEKLY_SESSIONS_MAX}.`,
    };
  }
  if (!isIntegerIn(sessionMinutes, TRAINING_SESSION_MINUTES_MIN, TRAINING_SESSION_MINUTES_MAX)) {
    return {
      ok: false,
      reason: `sessionMinutes doit être un entier entre ${TRAINING_SESSION_MINUTES_MIN} et ${TRAINING_SESSION_MINUTES_MAX}.`,
    };
  }
  return {
    ok: true,
    proposal: { goal: goal as TrainingGoal, weeklySessions, sessionMinutes },
  };
}

function isIntegerIn(value: unknown, min: number, max: number): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= min && value <= max;
}
