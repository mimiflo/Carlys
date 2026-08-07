import { type PersonalRecordType } from '@carlys/api-contracts';
import { type WorkoutSet } from '@prisma/client';

export interface RecordCandidate {
  exerciseId: string | null;
  exerciseName: string;
  recordType: PersonalRecordType;
  value: number;
  reps: number | null;
  weightKg: number | null;
  achievedAt: Date;
}

/**
 * Meilleures performances d'une séance, par exercice et par type de record.
 * Fonction pure : l'entrée est la liste des séries (non supprimées) de la
 * séance, la sortie les candidats à comparer aux records stockés.
 */
export function computeSessionBests(sets: WorkoutSet[]): RecordCandidate[] {
  const candidates = new Map<string, RecordCandidate>();

  const consider = (set: WorkoutSet, recordType: PersonalRecordType, value: number): void => {
    const key = `${set.exerciseName}|${recordType}`;
    const current = candidates.get(key);
    if (current === undefined || value > current.value) {
      candidates.set(key, {
        exerciseId: set.exerciseId,
        exerciseName: set.exerciseName,
        recordType,
        value,
        reps: set.reps,
        weightKg: set.weightKg === null ? null : Number(set.weightKg),
        achievedAt: set.completedAt,
      });
    }
  };

  for (const set of sets) {
    if (set.deletedAt !== null) {
      continue;
    }
    const weight = set.weightKg === null ? null : Number(set.weightKg);
    if (weight !== null && weight > 0) {
      consider(set, 'MAX_WEIGHT', weight);
    }
    if (set.reps !== null && set.reps > 0) {
      consider(set, 'MAX_REPS', set.reps);
    }
    if (weight !== null && set.reps !== null && weight > 0 && set.reps > 0) {
      consider(set, 'MAX_SET_VOLUME', weight * set.reps);
    }
  }

  return [...candidates.values()];
}
