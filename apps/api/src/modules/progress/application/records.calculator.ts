import { type PersonalRecordType } from '@carlys/api-contracts';
import { type PersonalRecord, type WorkoutSet } from '@prisma/client';

/**
 * Ce qu'un calcul de record lit d'une série — et le dépôt n'en rapatrie pas
 * davantage (`findSetsForRecords`). Huit colonnes sur dix-huit : l'historique
 * d'un exercice fréquent compte des milliers de séries, et il se relit à
 * chaque clôture de séance.
 */
export type RecordSet = Pick<
  WorkoutSet,
  | 'sessionId'
  | 'exerciseId'
  | 'exerciseName'
  | 'position'
  | 'reps'
  | 'weightKg'
  | 'completedAt'
  | 'deletedAt'
>;

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
export function computeBests(sets: readonly RecordSet[]): RecordCandidate[] {
  const candidates = new Map<string, RecordCandidate>();

  const consider = (set: RecordSet, recordType: PersonalRecordType, value: number): void => {
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

/** Une valeur en centièmes : l'échelle des colonnes `Decimal(…, 2)` du record. */
function cents(value: number | null): number | null {
  return value === null ? null : Math.round(value * 100);
}

/**
 * Le record stocké dit-il DÉJÀ exactement ce que l'historique vient de
 * calculer ? Valeur, charge, répétitions, date et séance d'origine.
 *
 * Comparées en centièmes : la base arrondit à deux décimales, et un produit
 * flottant (22,1 × 3 = 66,300000000000001) ne doit pas passer pour un record
 * qui a bougé.
 */
function sameRecord(stored: PersonalRecord, best: RecordCandidate): boolean {
  return (
    cents(Number(stored.value)) === cents(best.value) &&
    cents(stored.weightKg === null ? null : Number(stored.weightKg)) === cents(best.weightKg) &&
    stored.reps === best.reps &&
    stored.achievedAt.getTime() === best.achievedAt.getTime() &&
    stored.sessionId === best.sessionId &&
    stored.exerciseId === best.exerciseId
  );
}

/**
 * Les meilleures performances qui DIFFÈRENT de ce qui est stocké : les seules
 * à écrire.
 *
 * Le recalcul depuis l'historique rend tous les records des exercices
 * touchés — trois par exercice, dix-huit pour une séance de six — alors
 * qu'une séance ordinaire n'en bat aucun ou presque. Les réécrire tous
 * coûtait dix-huit `INSERT … ON CONFLICT DO UPDATE` à la suite, chacun une
 * vraie écriture (nouvelle version de ligne), à chaque clôture.
 */
export function changedBests(
  bests: readonly RecordCandidate[],
  stored: readonly PersonalRecord[],
): RecordCandidate[] {
  const parCle = new Map(
    stored.map((record) => [`${record.exerciseName}|${record.recordType}`, record]),
  );
  return bests.filter((best) => {
    const existant = parCle.get(`${best.exerciseName}|${best.recordType}`);
    return existant === undefined || !sameRecord(existant, best);
  });
}
