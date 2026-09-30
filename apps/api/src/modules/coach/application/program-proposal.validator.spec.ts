import {
  TRAINING_SESSION_MINUTES_MAX,
  TRAINING_SESSION_MINUTES_MIN,
  TRAINING_WEEKLY_SESSIONS_MAX,
  TRAINING_WEEKLY_SESSIONS_MIN,
} from '@carlys/api-contracts';
import { TrainingGoal } from '@prisma/client';
import { validateProgramProposal } from './program-proposal.validator';

/**
 * Validation d'un programme proposé : trois réglages, aux bornes mêmes que
 * l'écran de préparation. Un refus revient au MODÈLE, qui corrige : son
 * motif doit donc lui dire quoi changer.
 */
describe('validateProgramProposal', () => {
  const valide = { goal: 'STRENGTH', weeklySessions: 3, sessionMinutes: 45 };

  it('rend les trois réglages tels qu’ils seront écrits', () => {
    expect(validateProgramProposal(valide)).toEqual({
      ok: true,
      proposal: { goal: TrainingGoal.STRENGTH, weeklySessions: 3, sessionMinutes: 45 },
    });
  });

  it('refuse un objectif inconnu, en nommant les objectifs permis', () => {
    const result = validateProgramProposal({ ...valide, goal: 'BODYBUILDING' });
    expect(result.ok).toBe(false);
    expect(!result.ok && result.reason).toContain('MUSCLE_GAIN');
  });

  it.each([
    ['séances sous le minimum', { weeklySessions: TRAINING_WEEKLY_SESSIONS_MIN - 1 }],
    ['séances au-delà du maximum', { weeklySessions: TRAINING_WEEKLY_SESSIONS_MAX + 1 }],
    ['séances non entières', { weeklySessions: 3.5 }],
    ['durée sous le minimum', { sessionMinutes: TRAINING_SESSION_MINUTES_MIN - 1 }],
    ['durée au-delà du maximum', { sessionMinutes: TRAINING_SESSION_MINUTES_MAX + 1 }],
    ['durée en texte', { sessionMinutes: '45' }],
  ])('refuse %s', (_cas, override) => {
    expect(validateProgramProposal({ ...valide, ...override }).ok).toBe(false);
  });

  it('accepte les bornes elles-mêmes', () => {
    expect(
      validateProgramProposal({
        goal: 'MARATHON',
        weeklySessions: TRAINING_WEEKLY_SESSIONS_MAX,
        sessionMinutes: TRAINING_SESSION_MINUTES_MIN,
      }).ok,
    ).toBe(true);
  });
});
