import { type PersonalRecordType } from '@carlys/api-contracts';
import { type WorkoutSet } from '@prisma/client';

/** Un record BATTU : le jour où une valeur a dépassé tout ce qui précédait. */
export interface RecordBreak {
  exerciseName: string;
  recordType: PersonalRecordType;
  value: number;
  occurredAt: Date;
  /** Clé stable du franchissement, unique par personne. */
  key: string;
}

/** La clé d'un franchissement de record. Gelée : elle sert d'identité en base. */
export function recordBreakKey(
  exerciseName: string,
  recordType: PersonalRecordType,
  value: number,
): string {
  return `record:${exerciseName}|${recordType}|${value}`;
}

/**
 * TOUS les franchissements de record de cet historique, dans l'ordre.
 *
 * `computeBests` rend le maximum COURANT — trois lignes par exercice, datées
 * de la dernière amélioration. Un 80 kg en mars puis un 85 en avril, et il ne
 * reste que le 85 d'avril : `PersonalRecord` est un mur de trophées, pas une
 * chronologie. Cette fonction-ci rejoue le maximum au fil du temps et rend
 * les DEUX franchissements, qui sont ce qu'une frise raconte.
 *
 * Fonction PURE, dérivée des séries et de rien d'autre — même philosophie que
 * `recomputeRecords` : « le record cesse d'être un état à maintenir pour
 * devenir une FONCTION des séries stockées ». Corriger une charge saisie 100
 * au lieu de 10 fait donc disparaître le franchissement qu'elle avait
 * inventé, au lieu de le laisser derrière elle.
 *
 * Les ex æquo ne franchissent pas : égaler son record n'est pas le battre, et
 * la première fois garde la date. `>` et non `>=`, comme `computeBests`.
 */
export function computeRecordBreaks(sets: WorkoutSet[]): RecordBreak[] {
  const chronologiques = sets
    .filter((set) => set.deletedAt === null)
    // À l'instant près, l'ordre des séries d'une même seconde est
    // arbitraire ; leur position dans la séance le tranche, comme partout
    // ailleurs dans le dépôt.
    .sort((a, b) => a.completedAt.getTime() - b.completedAt.getTime() || a.position - b.position);

  const maxima = new Map<string, number>();
  const franchissements: RecordBreak[] = [];

  const considerer = (set: WorkoutSet, recordType: PersonalRecordType, value: number): void => {
    const cle = `${set.exerciseName}|${recordType}`;
    const courant = maxima.get(cle);
    if (courant !== undefined && value <= courant) {
      return;
    }
    maxima.set(cle, value);
    franchissements.push({
      exerciseName: set.exerciseName,
      recordType,
      value,
      occurredAt: set.completedAt,
      key: recordBreakKey(set.exerciseName, recordType, value),
    });
  };

  for (const set of chronologiques) {
    const weight = set.weightKg === null ? null : Number(set.weightKg);
    if (weight !== null && weight > 0) {
      considerer(set, 'MAX_WEIGHT', weight);
    }
    if (set.reps !== null && set.reps > 0) {
      considerer(set, 'MAX_REPS', set.reps);
    }
    if (weight !== null && set.reps !== null && weight > 0 && set.reps > 0) {
      considerer(set, 'MAX_SET_VOLUME', weight * set.reps);
    }
  }

  return franchissements;
}
