import { WorkoutSetKind } from '@prisma/client';

/**
 * Validation d'une séance proposée par le modèle.
 *
 * C'est ici que se joue la promesse la plus importante du coach : **il ne peut
 * pas inventer**. Une proposition n'est acceptée que si chaque exercice existe
 * réellement au catalogue, si les positions se suivent, et si les cibles sont
 * physiquement plausibles. Un rejet n'est pas une erreur utilisateur — le tour
 * repart une fois avec le motif, puis dégrade en réponse purement textuelle.
 *
 * Fonction pure : aucune base, aucun réseau, entièrement testable.
 */

/** Séance proposée, telle qu'elle sera écrite. */
export interface ValidatedProposal {
  name: string;
  estimatedMinutes: number;
  items: ValidatedProposalItem[];
}

export interface ValidatedProposalItem {
  exercisePosition: number;
  exerciseId: string;
  exerciseName: string;
  setPosition: number;
  kind: WorkoutSetKind;
  targetReps: number | null;
  targetWeightKg: number | null;
  restSeconds: number | null;
}

export type ProposalValidation =
  { ok: true; proposal: ValidatedProposal } | { ok: false; reason: string };

/** Bornes de plausibilité — larges à dessein : on écarte l'absurde, pas l'audace. */
const MAX_WEIGHT_KG = 500;
const MAX_REPS = 100;
const MAX_REST_SECONDS = 900;
const MAX_MINUTES = 240;
const MAX_ITEMS = 60;

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function asFiniteNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function optionalInteger(value: unknown, max: number, label: string): number | null | string {
  if (value === undefined || value === null) {
    return null;
  }
  const parsed = asFiniteNumber(value);
  if (parsed === null || !Number.isInteger(parsed) || parsed < 0 || parsed > max) {
    return `${label} hors bornes`;
  }
  return parsed;
}

/**
 * @param raw          Entrée de l'outil `propose_session`, non fiable.
 * @param catalogue    Exercices RÉELS, par identifiant. La clé de la garantie :
 *                     un identifiant absent de cette table fait échouer la
 *                     proposition entière plutôt que d'être corrigé en silence.
 */
export function validateProposal(
  raw: unknown,
  catalogue: ReadonlyMap<string, string>,
): ProposalValidation {
  const root = asRecord(raw);
  if (root === null) {
    return { ok: false, reason: 'La proposition n’est pas un objet.' };
  }

  const name = typeof root.name === 'string' ? root.name.trim() : '';
  if (name.length === 0 || name.length > 120) {
    return { ok: false, reason: 'Le nom de la séance est vide ou trop long.' };
  }

  const minutes = asFiniteNumber(root.estimatedMinutes);
  if (minutes === null || !Number.isInteger(minutes) || minutes < 1 || minutes > MAX_MINUTES) {
    return { ok: false, reason: 'La durée estimée est absente ou hors bornes.' };
  }

  if (!Array.isArray(root.items) || root.items.length === 0) {
    return { ok: false, reason: 'La proposition ne contient aucune série.' };
  }
  if (root.items.length > MAX_ITEMS) {
    return { ok: false, reason: 'La proposition contient trop de séries.' };
  }

  const items: ValidatedProposalItem[] = [];
  for (const entry of root.items) {
    const item = asRecord(entry);
    if (item === null) {
      return { ok: false, reason: 'Une série n’est pas un objet.' };
    }

    const exerciseId = typeof item.exerciseId === 'string' ? item.exerciseId : '';
    const exerciseName = catalogue.get(exerciseId);
    if (exerciseName === undefined) {
      // Le cœur de la garantie : aucun exercice inventé ne franchit cette ligne.
      return { ok: false, reason: `L’exercice « ${exerciseId} » n’existe pas au catalogue.` };
    }

    const exercisePosition = asFiniteNumber(item.exercisePosition);
    const setPosition = asFiniteNumber(item.setPosition);
    if (
      exercisePosition === null ||
      setPosition === null ||
      !Number.isInteger(exercisePosition) ||
      !Number.isInteger(setPosition) ||
      exercisePosition < 0 ||
      setPosition < 0
    ) {
      return { ok: false, reason: 'Les positions doivent être des entiers positifs.' };
    }

    const kind =
      typeof item.kind === 'string' && item.kind in WorkoutSetKind
        ? (item.kind as WorkoutSetKind)
        : WorkoutSetKind.NORMAL;

    const reps = optionalInteger(item.targetReps, MAX_REPS, 'Répétitions');
    if (typeof reps === 'string') {
      return { ok: false, reason: reps };
    }
    const rest = optionalInteger(item.restSeconds, MAX_REST_SECONDS, 'Repos');
    if (typeof rest === 'string') {
      return { ok: false, reason: rest };
    }

    let weight: number | null = null;
    if (item.targetWeightKg !== undefined && item.targetWeightKg !== null) {
      const parsed = asFiniteNumber(item.targetWeightKg);
      if (parsed === null || parsed < 0 || parsed > MAX_WEIGHT_KG) {
        return { ok: false, reason: 'Charge hors bornes' };
      }
      // Deux décimales : la colonne est un DECIMAL(6,2).
      weight = Math.round(parsed * 100) / 100;
    }

    items.push({
      exercisePosition,
      exerciseId,
      // Le nom vient du CATALOGUE, jamais du modèle : il ne peut pas renommer
      // un exercice en le proposant.
      exerciseName,
      setPosition,
      kind,
      targetReps: reps,
      targetWeightKg: weight,
      restSeconds: rest,
    });
  }

  const contiguity = checkContiguity(items);
  if (contiguity !== null) {
    return { ok: false, reason: contiguity };
  }

  return { ok: true, proposal: { name, estimatedMinutes: minutes, items } };
}

/**
 * Les exercices doivent occuper 0..n-1 et, dans chacun, les séries 0..m-1.
 * Sans ça, l'écran afficherait des trous et l'unicité en base sauterait.
 */
function checkContiguity(items: ValidatedProposalItem[]): string | null {
  const setsByExercise = new Map<number, Set<number>>();
  for (const item of items) {
    const sets = setsByExercise.get(item.exercisePosition) ?? new Set<number>();
    if (sets.has(item.setPosition)) {
      return 'Deux séries occupent la même position.';
    }
    sets.add(item.setPosition);
    setsByExercise.set(item.exercisePosition, sets);
  }

  const positions = [...setsByExercise.keys()].sort((a, b) => a - b);
  for (const [index, position] of positions.entries()) {
    if (position !== index) {
      return 'Les positions d’exercice ne se suivent pas.';
    }
    const sets = [...(setsByExercise.get(position) ?? [])].sort((a, b) => a - b);
    for (const [setIndex, setPosition] of sets.entries()) {
      if (setPosition !== setIndex) {
        return 'Les positions de série ne se suivent pas.';
      }
    }
  }

  return null;
}
