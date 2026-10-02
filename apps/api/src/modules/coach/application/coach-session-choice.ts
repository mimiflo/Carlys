import { type CoachComposition, type CoachSessionCandidate } from '../domain/coach-model.port';
import { alias, exerciseRange, MIN_EXERCISES, parsed, record } from './coach-session';

/**
 * Ce que devient la réponse du modèle — ou, sans réponse utilisable, la
 * séance que le serveur compose seul : une séance tenue dans le temps
 * annoncé, chargée d'après ses records, au format de `propose_session`.
 */

export interface SessionChoice {
  message: string;
  name: string;
  estimatedMinutes: number;
  exercises: { exerciseId: string; sets: number; reps: number; restSeconds: number }[];
}

/** Le plafond du validateur (proposal.validator.ts) : au-delà, la carte serait rejetée. */
const MAX_MINUTES = 240;

/** Sa durée : chaque série, ≈ 4 s par répétition et son repos. */
const secondsOf = (exercises: SessionChoice['exercises']) =>
  exercises.reduce((sum, item) => sum + item.sets * (item.reps * 4 + item.restSeconds), 0);

const minutesOf = (exercises: SessionChoice['exercises']) =>
  Math.min(MAX_MINUTES, Math.max(10, Math.round(secondsOf(exercises) / 60)));

/**
 * La séance tenue dans `minutes` : une série de moins à l'exercice qui en a
 * le plus (deux au moins), puis des repos plus courts (45 s au moins), puis
 * un exercice de moins (deux au moins). « J'ai 20 minutes » veut dire 20.
 */
export function fitTo(
  exercises: SessionChoice['exercises'],
  minutes: number | null,
): SessionChoice['exercises'] {
  if (minutes === null) return exercises;
  const fitted = exercises.map((item) => ({ ...item }));
  while (secondsOf(fitted) > minutes * 60) {
    const most = fitted.reduce((a, b) => (b.sets > a.sets ? b : a));
    const slowest = fitted.reduce((a, b) => (b.restSeconds > a.restSeconds ? b : a));
    if (most.sets > 2) most.sets -= 1;
    else if (slowest.restSeconds > 45) slowest.restSeconds = Math.max(45, slowest.restSeconds - 15);
    else if (fitted.length > 2) fitted.pop();
    else break;
  }
  return fitted;
}

const bounded = (value: unknown, min: number, max: number): number | null =>
  typeof value === 'number' && Number.isInteger(value) && value >= min && value <= max
    ? value
    : null;

/**
 * La réponse du modèle, si elle tient : JSON lisible, alias de la liste
 * (une seule fois chacun), assez d'exercices, un message — tenue dans le
 * temps annoncé. `null` sinon : un fournisseur qui ignore le format, une
 * réponse coupée.
 */
export function parseChoice(content: string, composition: CoachComposition): SessionChoice | null {
  const data = record(parsed(content));
  const byAlias = new Map(composition.candidates.map((item, i) => [alias(i), item.id]));
  const seen = new Set<string>();
  const exercises: SessionChoice['exercises'] = [];
  for (const raw of Array.isArray(data?.exercises) ? data.exercises : []) {
    const item = record(raw);
    const exerciseId = byAlias.get(typeof item?.id === 'string' ? item.id : '') ?? '';
    const sets = bounded(item?.sets, 1, 6);
    const reps = bounded(item?.reps, 1, 30);
    const restSeconds = bounded(item?.rest, 15, 300);
    if (exerciseId === '' || seen.has(exerciseId) || !sets || !reps || !restSeconds) continue;
    seen.add(exerciseId);
    exercises.push({ exerciseId, sets, reps, restSeconds });
  }
  const said = typeof data?.message === 'string' ? data.message.trim() : '';
  // « j'ai choisi… » : la majuscule que le modèle oublie souvent.
  const message = said.charAt(0).toUpperCase() + said.slice(1);
  const name = typeof data?.name === 'string' ? data.name.trim() : '';
  if (exercises.length < MIN_EXERCISES - 1 || message === '' || name === '') return null;
  const kept = fitTo(
    exercises.slice(0, exerciseRange(composition.minutes).max),
    composition.minutes,
  );
  return { message, name: name.slice(0, 80), estimatedMinutes: minutesOf(kept), exercises: kept };
}

/**
 * La séance composée par le serveur seul, quand le modèle n'a rien rendu
 * d'utilisable : la séance à modifier d'abord s'il y en a une, puis un
 * exercice de chaque muscle à tour de rôle, 3 × 12, tenue dans le temps.
 */
export function fallbackChoice(composition: CoachComposition): SessionChoice {
  const byMuscle = new Map<string, CoachSessionCandidate[]>();
  for (const item of composition.candidates) {
    const key = item.muscle ?? '';
    byMuscle.set(key, [...(byMuscle.get(key) ?? []), item]);
  }
  const { max } = exerciseRange(composition.minutes);
  const wanted = Math.min(max, 5);
  const picked: CoachSessionCandidate[] = [];
  for (let rank = 0; picked.length < wanted; rank++) {
    const row = [...byMuscle.values()].flatMap((items) => items[rank] ?? []);
    if (row.length === 0) break;
    picked.push(...row.slice(0, wanted - picked.length));
  }
  const exercises = fitTo(
    picked.map((item) => ({ exerciseId: item.id, sets: 3, reps: 12, restSeconds: 60 })),
    composition.minutes,
  );
  const names = exercises.map(
    (item) =>
      composition.candidates.find((c) => c.id === item.exerciseId)?.name.toLowerCase() ?? '',
  );
  return {
    message:
      `J’ai composé ta séance avec ${names.slice(0, -1).join(', ')} et ${names.at(-1) ?? ''}, ` +
      'en alternant les groupes musculaires.',
    name: 'Séance du coach',
    estimatedMinutes: minutesOf(exercises),
    exercises,
  };
}

/**
 * La charge d'une série : tirée de son record (1RM estimé, Epley), à 90 %,
 * arrondie au 2,5 kg inférieur. Sans record, aucune : jamais inventée.
 */
function loadFor(candidate: CoachSessionCandidate | undefined, reps: number): number | undefined {
  const best = candidate?.record;
  if (best === undefined) return undefined;
  const oneRepMax = best.weightKg * (1 + best.reps / 30);
  const load = Math.floor(((oneRepMax / (1 + reps / 30)) * 0.9) / 2.5) * 2.5;
  return load > 0 ? load : undefined;
}

/** La proposition au format de `propose_session` : une entrée PAR SÉRIE. */
export function sessionProposal(
  choice: SessionChoice,
  composition: CoachComposition,
): Record<string, unknown> {
  return {
    name: choice.name,
    estimatedMinutes: choice.estimatedMinutes,
    items: choice.exercises.flatMap((exercise, exercisePosition) => {
      const targetWeightKg = loadFor(
        composition.candidates.find((item) => item.id === exercise.exerciseId),
        exercise.reps,
      );
      return Array.from({ length: exercise.sets }, (_, setPosition) => ({
        exercisePosition,
        exerciseId: exercise.exerciseId,
        setPosition,
        kind: 'NORMAL',
        targetReps: exercise.reps,
        ...(targetWeightKg === undefined ? {} : { targetWeightKg }),
        restSeconds: exercise.restSeconds,
      }));
    }),
  };
}
