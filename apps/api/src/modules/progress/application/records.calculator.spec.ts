import { Prisma, type PersonalRecord, type WorkoutSet } from '@prisma/client';
import { changedBests, computeBests, type RecordCandidate } from './records.calculator';

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

describe('computeBests', () => {
  it('retient la meilleure valeur par exercice et par type de record', () => {
    const bests = computeBests([
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
    const bests = computeBests([
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
    const bests = computeBests([
      set({ weightKg: 60, reps: 10 }),
      set({ id: 'b', weightKg: 200, reps: 20, deletedAt: new Date() }),
    ]);

    expect(bests.find((best) => best.recordType === 'MAX_WEIGHT')?.value).toBe(60);
  });

  it('une série au poids du corps ne produit qu’un record de répétitions', () => {
    const bests = computeBests([set({ exerciseName: 'Tractions', weightKg: null, reps: 15 })]);

    expect(bests).toHaveLength(1);
    expect(bests[0]?.recordType).toBe('MAX_REPS');
    expect(bests[0]?.value).toBe(15);
  });

  it('renvoie une liste vide sans série exploitable', () => {
    expect(computeBests([])).toEqual([]);
    expect(computeBests([set({ reps: null, weightKg: null })])).toEqual([]);
  });
});

describe('changedBests', () => {
  const best: RecordCandidate = {
    exerciseId: 'exercise-1',
    exerciseName: 'Développé couché',
    recordType: 'MAX_SET_VOLUME',
    value: 66.3,
    reps: 3,
    weightKg: 22.1,
    achievedAt: new Date('2026-08-07T10:05:00Z'),
    sessionId: 'session-1',
  };

  /** Le record tel que Prisma le rend : `Decimal` pour les colonnes chiffrées. */
  function stored(overrides: Partial<PersonalRecord> = {}): PersonalRecord {
    return {
      id: 'record-1',
      userId: 'user-1',
      exerciseId: 'exercise-1',
      exerciseName: 'Développé couché',
      recordType: 'MAX_SET_VOLUME',
      value: new Prisma.Decimal('66.30'),
      reps: 3,
      weightKg: new Prisma.Decimal('22.10'),
      achievedAt: new Date('2026-08-07T10:05:00Z'),
      sessionId: 'session-1',
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    };
  }

  it('un record que l’historique confirme à l’identique ne se réécrit pas', () => {
    // 22,1 × 3 vaut 66,300000000000001 en flottant : la base, elle, garde
    // 66,30. Ce n'est pas un record qui a bougé.
    expect(changedBests([{ ...best, value: 22.1 * 3 }], [stored()])).toEqual([]);
  });

  it('un record absent, ou qui a bougé d’un seul de ses faits, se réécrit', () => {
    expect(changedBests([best], [])).toEqual([best]);
    for (const change of [
      { value: new Prisma.Decimal('70.00') },
      { weightKg: null },
      { reps: 4 },
      { achievedAt: new Date('2026-08-08T10:05:00Z') },
      { sessionId: 'session-0' },
      { exerciseId: null },
    ]) {
      expect(changedBests([best], [stored(change)])).toEqual([best]);
    }
  });

  it('compare chaque record à SON homologue, exercice et type compris', () => {
    const autreType = stored({ recordType: 'MAX_WEIGHT' });
    const autreExercice = stored({ exerciseName: 'Squat' });
    expect(changedBests([best], [autreType, autreExercice])).toEqual([best]);
  });
});
