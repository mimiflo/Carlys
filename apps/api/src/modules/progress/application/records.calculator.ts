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
  /**
   * La séance où la performance a RÉELLEMENT eu lieu.
   *
   * Elle était déduite de l'appelant — la séance qu'on venait de clôturer —
   * ce qui était vrai tant que le record se calculait sur cette seule séance.
   * Depuis qu'il se recalcule sur l'historique, le meilleur candidat peut
   * venir d'une séance d'il y a six mois, et l'attribuer à celle du jour
   * serait un fait faux.
   */
  sessionId: string;
}

/**
 * Meilleures performances par exercice et par type de record.
 *
 * Fonction pure, et volontairement AGNOSTIQUE de la provenance des séries :
 * on lui donne celles d'une séance ou tout l'historique d'un exercice, elle
 * rend le maximum de ce qu'elle a reçu. C'est ce qui permet de recalculer un
 * record depuis l'historique avec le même code que celui qui le calculait
 * séance par séance.
 */
export function computeBests(sets: WorkoutSet[]): RecordCandidate[] {
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
        sessionId: set.sessionId,
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
