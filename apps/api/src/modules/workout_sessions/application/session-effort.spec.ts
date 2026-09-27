import { type WorkoutsRepository } from '../infrastructure/workouts.repository';
import { creditedSessionEffort, declaredEffort } from './session-effort';

type Closed = Parameters<typeof creditedSessionEffort>[2];

const DEBUT = new Date('2026-09-23T10:00:00Z');

function seance(sets: Array<{ durationSeconds?: number; distanceMeters?: number }>): Closed {
  return {
    startedAt: DEBUT,
    sets: sets.map((set) => ({
      durationSeconds: set.durationSeconds ?? null,
      distanceMeters: set.distanceMeters ?? null,
    })),
  } as unknown as Closed;
}

function depot(completedThatDay: number): { repo: WorkoutsRepository; count: jest.Mock } {
  const count = jest.fn().mockResolvedValue(completedThatDay);
  return {
    repo: { countCompletedEndedBetween: count } as unknown as WorkoutsRepository,
    count,
  };
}

describe('declaredEffort', () => {
  it('additionne ce que les séries déclarent, zéro pour la fonte', () => {
    expect(
      declaredEffort(seance([{ durationSeconds: 600, distanceMeters: 2_000 }, {}]).sets),
    ).toEqual({ activeSeconds: 600, distanceMeters: 2_000 });
  });
});

describe('creditedSessionEffort', () => {
  it('compte les séances du JOUR UTC de la fin, et borne l’effort au créneau', async () => {
    const { repo, count } = depot(1);
    const fin = new Date(DEBUT.getTime() + 60_000);

    const effort = await creditedSessionEffort(
      repo,
      'user-1',
      seance([{ durationSeconds: 86_400, distanceMeters: 1_000_000 }]),
      fin,
    );

    expect(count).toHaveBeenCalledWith(
      'user-1',
      new Date('2026-09-23T00:00:00Z'),
      new Date('2026-09-24T00:00:00Z'),
    );
    expect(effort).toEqual({ countsAsWorkout: true, activeSeconds: 60, distanceMeters: 1_200 });
  });

  it('une séance vide ne compte pas comme une séance', async () => {
    const { repo } = depot(1);

    const effort = await creditedSessionEffort(
      repo,
      'user-1',
      seance([]),
      new Date(DEBUT.getTime() + 60_000),
    );

    expect(effort.countsAsWorkout).toBe(false);
  });
});
