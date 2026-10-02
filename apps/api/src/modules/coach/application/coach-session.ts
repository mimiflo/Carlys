import {
  type CoachComposition,
  type CoachSessionCandidate,
  type CoachToolCall,
  type CoachToolResult,
} from '../domain/coach-model.port';
import { BODYWEIGHT_SLUG } from '../../programs/domain/generation/constants';
import { type CoachIntent } from './coach-intent';

/**
 * Une SÉANCE demandée se compose à coup sûr (ADR 0014).
 *
 * Laissé libre, Qwen3-4B décrivait la séance en texte au lieu d'appeler
 * `propose_session` — cinq fois signalé, encore le 2 octobre 2026 malgré
 * l'ordre de la proposer, et avec des choix absurdes (« développé couché à
 * fessiers »). Ici, le modèle ne choisit plus QUE parmi les exercices lus
 * d'avance pour les muscles demandés, compatibles avec son matériel, et sa
 * réponse est CONTRAINTE à un schéma (`response_format`) : un message et une
 * séance, d'un seul jet, donc cohérents. S'il échoue quand même, le serveur
 * compose seul (coach-session-choice.ts) : la carte arrive toujours.
 */

export const MIN_EXERCISES = 3;
const MAX_EXERCISES = 6;

/** Les intentions qui DOIVENT finir par une carte : proposer, modifier, créer. */
export type WorkoutIntent = Extract<
  CoachIntent,
  {
    kind:
      'WORKOUT_PROPOSAL_REQUIRED' | 'WORKOUT_MODIFICATION_REQUIRED' | 'WORKOUT_CREATION_REQUIRED';
  }
>;

/** La séance à modifier : son nom et ses séries (« fais-la plus courte »). */
export interface BaseWorkout {
  name: string;
  items: { exerciseId: string; exerciseName: string }[];
}

/** Combien d'exercices tiennent dans le temps annoncé (≈ 8 min chacun). */
export function exerciseRange(minutes: number | null): { min: number; max: number } {
  const max =
    minutes === null
      ? MAX_EXERCISES
      : Math.min(MAX_EXERCISES, Math.max(2, Math.round(minutes / 8)));
  return { min: Math.min(MIN_EXERCISES, max), max };
}

export const alias = (index: number) => `e${index + 1}`;

export const record = (value: unknown): Record<string, unknown> | null =>
  typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;

export function parsed(content: string): unknown {
  try {
    return JSON.parse(content) as unknown;
  } catch {
    // Une lecture illisible ne compte pas : les autres suffisent.
    return null;
  }
}

/** Ni étirement ni mobilité : des séries de 3 × 12 n'en sont pas. */
const NOT_WORKOUT = new Set(['MOBILITY', 'STRETCHING']);

type Found = CoachSessionCandidate & { difficulty?: unknown };
type Best = { weightKg: number; reps: number };

function candidate(value: unknown): Found | null {
  const item = record(value);
  if (typeof item?.id !== 'string' || typeof item.name !== 'string') return null;
  if (NOT_WORKOUT.has(String(item.type))) return null;
  return {
    id: item.id,
    name: item.name,
    difficulty: item.difficulty,
    muscle: typeof item.muscle === 'string' ? item.muscle : null,
    equipment: Array.isArray(item.equipment)
      ? item.equipment.filter((slug): slug is string => typeof slug === 'string')
      : [],
  };
}

const strength = (best: Best) => best.weightKg * (1 + best.reps / 30);

/** Le meilleur record en charge de chaque exercice (1RM estimé, Epley). */
function recordsOf(data: unknown): Map<string, Best> {
  const best = new Map<string, Best>();
  for (const row of Array.isArray(data) ? data.map(record) : []) {
    const exerciseId = row?.exerciseId;
    const weightKg = row?.weightKg;
    const reps = row?.reps;
    if (typeof exerciseId !== 'string' || typeof weightKg !== 'number') continue;
    if (typeof reps !== 'number' || weightKg <= 0) continue;
    const current = best.get(exerciseId);
    if (current === undefined || strength({ weightKg, reps }) > strength(current)) {
      best.set(exerciseId, { weightKg, reps });
    }
  }
  return best;
}

/** « Jambes (2026-09-28) » : ce qu'il a fait récemment, pour ne pas le refaire demain. */
function recentOf(data: unknown): string | null {
  const names = (Array.isArray(data) ? data.map(record) : []).flatMap((row) =>
    typeof row?.name === 'string'
      ? [`${row.name} (${typeof row.startedAt === 'string' ? row.startedAt.slice(0, 10) : '?'})`]
      : [],
  );
  return names.length === 0 ? null : `Ses dernières séances : ${names.join(', ')}.`;
}

/** Ce que les lectures d'avance disent de lui. */
function readAll(prefetched: readonly { call: CoachToolCall; result: CoachToolResult }[]) {
  const found = new Map<string, Found>();
  const read = {
    owned: [] as string[],
    beginner: false,
    records: new Map<string, Best>(),
    recent: null as string | null,
  };
  for (const { call, result } of prefetched) {
    if (result.isError === true) continue;
    const data = parsed(result.content);
    if (call.name === 'get_training_profile') {
      const slugs = record(data)?.equipmentSlugs;
      read.owned = Array.isArray(slugs)
        ? slugs.filter((s): s is string => typeof s === 'string')
        : [];
      read.beginner = record(data)?.trainingExperience === 'BEGINNER';
    }
    if (call.name === 'get_personal_records') read.records = recordsOf(data);
    if (call.name === 'get_recent_sessions') read.recent = recentOf(data);
    if (call.name !== 'search_exercises' || !Array.isArray(data)) continue;
    for (const item of data.map(candidate)) if (item !== null) found.set(item.id, item);
  }
  return { ...read, found };
}

/**
 * De quoi composer la séance qu'exige `intent` : les exercices faisables
 * (son matériel, rien d'avancé pour un débutant, ni étirement — tant qu'il
 * en reste assez), leurs records, le temps annoncé, et le contexte. `null`
 * s'il n'y a pas de quoi composer : la raison métier se dit alors.
 */
export function compositionFor(
  intent: WorkoutIntent,
  prefetched: readonly { call: CoachToolCall; result: CoachToolResult }[],
  base: BaseWorkout | null,
  message: string,
): CoachComposition | null {
  const { owned, beginner, records, recent, found } = readAll(prefetched);
  // La séance à modifier d'abord : ses exercices restent possibles.
  const kept = (base?.items ?? []).map(
    (item): Found =>
      found.get(item.exerciseId) ?? {
        id: item.exerciseId,
        name: item.exerciseName,
        muscle: null,
        equipment: [],
      },
  );
  const all = [...new Map([...kept, ...found.values()].map((item) => [item.id, item])).values()];
  const usable = all.filter(
    (item) =>
      (owned.length === 0 ||
        item.equipment.every((slug) => slug === BODYWEIGHT_SLUG || owned.includes(slug))) &&
      !(beginner && item.difficulty === 'ADVANCED'),
  );
  const pool = (usable.length >= MIN_EXERCISES ? usable : all).map(({ difficulty: _, ...item }) => {
    const best = records.get(item.id);
    return best === undefined ? item : { ...item, record: best };
  });
  if (pool.length < 2) return null;
  const request = intent.request;
  const context = [
    request !== null && request !== message ? `Sa demande, plus haut : « ${request} ».` : null,
    base === null ? null : `La séance à modifier, « ${base.name} » : ${describe(base)}.`,
    intent.minutes === null ? null : `Temps disponible : ${intent.minutes} minutes, pas plus.`,
    recent,
  ].filter((line): line is string => line !== null);
  return { candidates: pool, minutes: intent.minutes, context };
}

function describe(base: BaseWorkout): string {
  const counts = new Map<string, number>();
  for (const item of base.items) {
    counts.set(item.exerciseName, (counts.get(item.exerciseName) ?? 0) + 1);
  }
  return [...counts].map(([name, sets]) => `${name} ${sets} séries`).join(', ');
}

/**
 * Ce que le modèle reçoit pour composer : les exercices, le contexte, et le
 * format. Sans « réponds directement par l'objet JSON », sur un long
 * contexte, Qwen3-4B réfléchissait d'abord en texte libre (Ollama le range
 * en `reasoning`, hors grammaire) et épuisait 700 jetons avant le JSON —
 * deux fois sur quatre, mesuré le 2 octobre 2026 ; avec, plus jamais.
 */
export function compositionPrompt(composition: CoachComposition): string {
  const { min, max } = exerciseRange(composition.minutes);
  const list = composition.candidates.map((item, i) => {
    const best = item.record;
    const known = best === undefined ? '' : `, record ${best.weightKg} kg × ${best.reps}`;
    return `- ${alias(i)} : ${item.name} (${item.muscle ?? '?'}, ${item.equipment.join(', ')}${known})`;
  });
  return [
    "(Message automatique, pas de l'utilisateur.) Compose la séance qu'il demande, avec ces " +
      'exercices seulement :',
    ...list,
    ...composition.context,
    `Choisis-en ${min} à ${max}, en couvrant CHAQUE muscle qu'il a nommé, les polyarticulaires ` +
      'd’abord, adaptés à son niveau et à son profil. Séries, répétitions et repos (en ' +
      'secondes) adaptés à son objectif. Dans « message », dis-lui en deux phrases, à la ' +
      'première personne (« j’ai choisi »), pourquoi ces exercices, sans identifiant ni liste : ' +
      'la carte de la séance s’affiche sous ton message. Réponds directement par l’objet JSON, ' +
      'sans aucun texte ni réflexion avant.',
  ].join('\n');
}

/**
 * Le format imposé à la réponse : les exercices, PRIS dans la liste. Par
 * leur alias (`e1`) plutôt que leur UUID, et des clés courtes : mesuré le
 * 2 octobre 2026, les UUID imposés par la grammaire faisaient écrire 350 à
 * 550 jetons, à 3 par seconde sur le processeur du serveur.
 */
export function compositionSchema(composition: CoachComposition) {
  const { min, max } = exerciseRange(composition.minutes);
  return {
    type: 'object',
    properties: {
      message: { type: 'string' },
      name: { type: 'string' },
      exercises: {
        type: 'array',
        minItems: min,
        maxItems: max,
        items: {
          type: 'object',
          properties: {
            id: { type: 'string', enum: composition.candidates.map((_, i) => alias(i)) },
            sets: { type: 'integer', minimum: 1, maximum: 6 },
            reps: { type: 'integer', minimum: 1, maximum: 30 },
            rest: { type: 'integer', minimum: 15, maximum: 300 },
          },
          required: ['id', 'sets', 'reps', 'rest'],
          additionalProperties: false,
        },
      },
    },
    required: ['message', 'name', 'exercises'],
    additionalProperties: false,
  };
}
