import { type WorkoutSet } from '@prisma/client';
import { Prisma } from '@prisma/client';
import { computeRecordBreaks, recordBreakKey } from './record-breaks.calculator';

/**
 * CE QUE CE FICHIER PROTÈGE : `PersonalRecord` est un MUR DE TROPHÉES, la
 * frise est une CHRONOLOGIE.
 *
 * L'unicité `(userId, exerciseName, recordType)` ne garde que le maximum
 * courant : un 80 kg en mars battu par un 85 en avril, et il ne reste que le
 * 85 d'avril. Une frise bâtie dessus perdrait le franchissement de mars.
 */
function set(overrides: Partial<WorkoutSet> & { completedAt: Date }): WorkoutSet {
  return {
    id: `s-${overrides.completedAt.toISOString()}-${overrides.position ?? 0}`,
    sessionId: 'session-1',
    exerciseId: null,
    exerciseName: 'Développé couché',
    position: 0,
    reps: null,
    weightKg: null,
    durationSeconds: null,
    distanceMeters: null,
    restSeconds: null,
    rpe: null,
    kind: 'NORMAL',
    notes: null,
    createdAt: overrides.completedAt,
    updatedAt: overrides.completedAt,
    deletedAt: null,
    ...overrides,
  } as WorkoutSet;
}

const kg = (value: number) => new Prisma.Decimal(value);

describe('computeRecordBreaks', () => {
  it('rend CHAQUE franchissement, pas seulement le dernier', () => {
    const breaks = computeRecordBreaks([
      set({ completedAt: new Date('2026-03-02T10:00:00Z'), weightKg: kg(80) }),
      set({ completedAt: new Date('2026-04-06T10:00:00Z'), weightKg: kg(85) }),
    ]);

    const charges = breaks.filter((entry) => entry.recordType === 'MAX_WEIGHT');
    expect(charges.map((entry) => entry.value)).toEqual([80, 85]);
    expect(charges[0]?.occurredAt.toISOString()).toBe('2026-03-02T10:00:00.000Z');
  });

  it('ne franchit pas en ÉGALANT : la première fois garde la date', () => {
    const breaks = computeRecordBreaks([
      set({ completedAt: new Date('2026-03-02T10:00:00Z'), weightKg: kg(80) }),
      set({ completedAt: new Date('2026-03-09T10:00:00Z'), weightKg: kg(80) }),
      set({ completedAt: new Date('2026-03-16T10:00:00Z'), weightKg: kg(79) }),
    ]);

    expect(breaks.filter((entry) => entry.recordType === 'MAX_WEIGHT')).toHaveLength(1);
  });

  it('rejoue dans l’ordre CHRONOLOGIQUE, quel que soit l’ordre reçu', () => {
    // Le dépôt ne trie pas `findSetsForRecords` : reçu à l'envers, un rejeu
    // naïf ne verrait qu'un seul franchissement, le plus lourd.
    const breaks = computeRecordBreaks([
      set({ completedAt: new Date('2026-04-06T10:00:00Z'), weightKg: kg(85) }),
      set({ completedAt: new Date('2026-03-02T10:00:00Z'), weightKg: kg(80) }),
    ]);

    expect(
      breaks.filter((entry) => entry.recordType === 'MAX_WEIGHT').map((entry) => entry.value),
    ).toEqual([80, 85]);
  });

  it('départage les séries de la même seconde par leur position', () => {
    const instant = new Date('2026-03-02T10:00:00Z');
    const breaks = computeRecordBreaks([
      set({ completedAt: instant, position: 1, weightKg: kg(85) }),
      set({ completedAt: instant, position: 0, weightKg: kg(80) }),
    ]);

    expect(
      breaks.filter((entry) => entry.recordType === 'MAX_WEIGHT').map((entry) => entry.value),
    ).toEqual([80, 85]);
  });

  it('suit les TROIS types, chacun avec son propre maximum', () => {
    const breaks = computeRecordBreaks([
      set({ completedAt: new Date('2026-03-02T10:00:00Z'), weightKg: kg(80), reps: 5 }),
      // Plus léger mais plus long : bat les répétitions et le volume, pas la
      // charge.
      set({ completedAt: new Date('2026-03-09T10:00:00Z'), weightKg: kg(60), reps: 12 }),
    ]);

    const parType = new Map<string, number[]>();
    for (const entry of breaks) {
      parType.set(entry.recordType, [...(parType.get(entry.recordType) ?? []), entry.value]);
    }
    expect(parType.get('MAX_WEIGHT')).toEqual([80]);
    expect(parType.get('MAX_REPS')).toEqual([5, 12]);
    expect(parType.get('MAX_SET_VOLUME')).toEqual([400, 720]);
  });

  it('ignore les séries supprimées et les valeurs nulles', () => {
    const breaks = computeRecordBreaks([
      set({
        completedAt: new Date('2026-03-02T10:00:00Z'),
        weightKg: kg(200),
        deletedAt: new Date('2026-03-03T10:00:00Z'),
      }),
      // Poids du corps : aucune charge, donc aucun record de charge.
      set({ completedAt: new Date('2026-03-09T10:00:00Z'), reps: 20 }),
    ]);

    expect(breaks.filter((entry) => entry.recordType === 'MAX_WEIGHT')).toHaveLength(0);
    expect(breaks.filter((entry) => entry.recordType === 'MAX_REPS')).toHaveLength(1);
  });

  it('sépare les exercices : chacun son maximum', () => {
    const breaks = computeRecordBreaks([
      set({ completedAt: new Date('2026-03-02T10:00:00Z'), weightKg: kg(120) }),
      set({
        completedAt: new Date('2026-03-09T10:00:00Z'),
        exerciseName: 'Squat',
        weightKg: kg(100),
      }),
    ]);

    // 100 kg au squat est un franchissement malgré les 120 du développé :
    // un record appartient à son mouvement.
    expect(breaks.filter((entry) => entry.exerciseName === 'Squat')).toHaveLength(1);
  });

  it('porte une clé STABLE, qui sert d’identité en base', () => {
    const [premier] = computeRecordBreaks([
      set({ completedAt: new Date('2026-03-02T10:00:00Z'), weightKg: kg(80) }),
    ]);

    expect(premier?.key).toBe(recordBreakKey('Développé couché', 'MAX_WEIGHT', 80));
    expect(premier?.key).toBe('record:Développé couché|MAX_WEIGHT|80');
  });
});
