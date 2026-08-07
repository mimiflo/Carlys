import { type WorkoutSet } from '@prisma/client';
import { computeSessionBests } from './records.calculator';

function set(overrides: Partial<Record<keyof WorkoutSet, unknown>> = {}): WorkoutSet {
  return {
    id: 'set-1',
    sessionId: 'session-1',
    exerciseId: 'exercise-1',
    exerciseName: 'Développé couché',
    position: 0,
    kind: 'NORMAL',
    reps: 10,
    weightKg: 60,
    durationSeconds: null,
    distanceMeters: null,
    rpe: null,
    restSeconds: null,
    completedAt: new Date('2026-08-07T10:05:00Z'),
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
    ...overrides,
  } as unknown as WorkoutSet;
}

describe('computeSessionBests', () => {
  it('retient la meilleure valeur par exercice et par type de record', () => {
    const bests = computeSessionBests([
      set({ id: 'a', reps: 10, weightKg: 60 }),
      set({ id: 'b', reps: 5, weightKg: 80 }),
      set({ id: 'c', reps: 12, weightKg: 40 }),
    ]);

    const byType = new Map(bests.map((best) => [best.recordType, best]));
    expect(byType.get('MAX_WEIGHT')?.value).toBe(80);
    expect(byType.get('MAX_REPS')?.value).toBe(12);
    // 10 × 60 = 600 bat 5 × 80 = 400 et 12 × 40 = 480.
    expect(byType.get('MAX_SET_VOLUME')?.value).toBe(600);
  });

  it('sépare les candidats par nom d’exercice', () => {
    const bests = computeSessionBests([
      set({ exerciseName: 'Développé couché', weightKg: 80, reps: 5 }),
      set({ id: 'b', exerciseName: 'Squat', weightKg: 100, reps: 8 }),
    ]);

    const squat = bests.filter((best) => best.exerciseName === 'Squat');
    expect(squat.map((best) => best.recordType).sort()).toEqual([
      'MAX_REPS',
      'MAX_SET_VOLUME',
      'MAX_WEIGHT',
    ]);
    expect(squat.find((best) => best.recordType === 'MAX_WEIGHT')?.value).toBe(100);
  });

  it('ignore les séries supprimées', () => {
    const bests = computeSessionBests([
      set({ weightKg: 60, reps: 10 }),
      set({ id: 'b', weightKg: 200, reps: 20, deletedAt: new Date() }),
    ]);

    expect(bests.find((best) => best.recordType === 'MAX_WEIGHT')?.value).toBe(60);
  });

  it('une série au poids du corps ne produit qu’un record de répétitions', () => {
    const bests = computeSessionBests([
      set({ exerciseName: 'Tractions', weightKg: null, reps: 15 }),
    ]);

    expect(bests).toHaveLength(1);
    expect(bests[0]?.recordType).toBe('MAX_REPS');
    expect(bests[0]?.value).toBe(15);
  });

  it('renvoie une liste vide sans série exploitable', () => {
    expect(computeSessionBests([])).toEqual([]);
    expect(computeSessionBests([set({ reps: null, weightKg: null })])).toEqual([]);
  });
});
