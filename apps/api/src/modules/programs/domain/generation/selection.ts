import { ExerciseDifficulty, ExerciseType, TrainingExperience } from '@prisma/client';
import {
  EXERCISE_WEEKLY_REPEAT_MAX,
  EXERCISE_WEEKLY_REPEAT_RELAXED,
  ISOMETRIC_TAG,
  SCORE_BEGINNER_TAG,
  SCORE_ISOLATION_PENALTY,
  SCORE_POLYARTICULAR,
} from './constants';
import { rotationOffset } from './hash';
import { type PoolExercise } from './types';

/**
 * LE CHOIX DES EXERCICES.
 *
 * Deux principes, et un seul est négociable :
 *
 * - Le générateur n'écrit JAMAIS un exercice sans `exerciseId`. Un exercice
 *   au nom libre ne nourrit ni `PersonalRecord`, ni la courbe de progression
 *   par exercice, ni la fiche d'exercice, et il rend le programme
 *   inauditable. Le contrat des modèles l'autorise pour ce que la personne
 *   saisit elle-même ; le serveur, lui, s'y refuse.
 * - La variété vient d'un DÉCALAGE, pas d'un tirage. Voir `hash.ts`.
 */

/** Les exercices d'un groupe, triés une fois pour toutes. */
export type PoolByGroup = Map<string, PoolExercise[]>;

/** Par quel échelon de dégradation un exercice a été trouvé. */
export type PickStep = 'principal' | 'secondaire' | 'voisin';

export interface Pick {
  exercise: PoolExercise;
  step: PickStep;
  /** Le groupe réellement servi — il diffère du groupe visé en `voisin`. */
  servedGroup: string;
}

function isPolyarticular(exercise: PoolExercise): boolean {
  return exercise.tags.includes('polyarticulaire');
}

/** Un maintien ou un bloc de cardio : la série se compte en secondes. */
export function isTimed(exercise: PoolExercise): boolean {
  return exercise.tags.includes(ISOMETRIC_TAG) || exercise.type === ExerciseType.CARDIO;
}

/**
 * Le score d'un exercice pour une expérience donnée.
 *
 * Un débutant a besoin de peu de mouvements, polyarticulaires, dont il
 * apprendra la technique ; un avancé remplit son volume supplémentaire avec
 * des exercices d'isolation, qui ne lui coûtent presque rien en fatigue.
 * Le score ne départage jamais tout seul : le slug tranche les ex æquo, ce
 * qui rend le tri stable quelle que soit l'implémentation de `sort`.
 */
export function scoreOf(exercise: PoolExercise, experience: TrainingExperience): number {
  let score = 0;
  if (isPolyarticular(exercise)) score += SCORE_POLYARTICULAR;
  if (experience === TrainingExperience.BEGINNER) {
    if (exercise.tags.includes('debutant')) score += SCORE_BEGINNER_TAG;
    if (exercise.tags.includes('isolation')) score -= SCORE_ISOLATION_PENALTY;
    if (exercise.difficulty === ExerciseDifficulty.BEGINNER) score += 1;
  }
  if (
    experience === TrainingExperience.ADVANCED &&
    exercise.difficulty !== ExerciseDifficulty.BEGINNER
  ) {
    score += 1;
  }
  // Les étirements et la mobilité ne remplissent pas un créneau de
  // renforcement : ils sollicitent, ils n'entraînent pas.
  if (exercise.type === ExerciseType.MOBILITY || exercise.type === ExerciseType.STRETCHING) {
    score -= 10;
  }
  return score;
}

function sortPool(list: PoolExercise[], experience: TrainingExperience): PoolExercise[] {
  return [...list].sort(
    (a, b) => scoreOf(b, experience) - scoreOf(a, experience) || (a.slug < b.slug ? -1 : 1),
  );
}

/** Range le pool par groupe PRINCIPAL, chaque liste triée (score, puis slug). */
export function groupPool(pool: PoolExercise[], experience: TrainingExperience): PoolByGroup {
  const byGroup: PoolByGroup = new Map();
  for (const exercise of pool) {
    const list = byGroup.get(exercise.primary) ?? [];
    list.push(exercise);
    byGroup.set(exercise.primary, list);
  }
  for (const [group, list] of byGroup) byGroup.set(group, sortPool(list, experience));
  return byGroup;
}

/**
 * Le même rangement, mais par groupe SECONDAIRE.
 *
 * C'est le premier échelon de dégradation, et le plus rentable : sur un kit
 * sans matériel, les épaules passent d'une poignée de candidats en principal à
 * beaucoup plus dès qu'on accepte les exercices où elles travaillent en
 * second. Un groupe servi en secondaire est SOLLICITÉ, pas entraîné — d'où
 * la mention au rapport, et d'où le fait que cet échelon ne serve jamais à
 * remplir un groupe obligatoire vide.
 */
export function secondaryPool(pool: PoolExercise[], experience: TrainingExperience): PoolByGroup {
  const byGroup: PoolByGroup = new Map();
  for (const exercise of pool) {
    for (const group of exercise.secondary) {
      const list = byGroup.get(group) ?? [];
      list.push(exercise);
      byGroup.set(group, list);
    }
  }
  for (const [group, list] of byGroup) byGroup.set(group, sortPool(list, experience));
  return byGroup;
}

export interface PickContext {
  /** Graine de rotation : profil complet, kit trié. Voir `generator.ts`. */
  seed: string;
  slotIndex: number;
  week: number;
  /** Déjà retenus dans CETTE séance : un exercice n'y revient jamais deux fois. */
  usedInSession: Set<string>;
  /** Comptage sur la SEMAINE : H8, deux passages au plus, trois si R2 joue. */
  usedInWeek: Map<string, number>;
  /** R2 a été consenti : le plafond hebdomadaire passe de 2 à 3. */
  repeatRelaxed: boolean;
}

/**
 * Le prochain exercice d'un groupe, ou `null` si le groupe est épuisé.
 *
 * On entre dans la liste au décalage de rotation puis on avance
 * circulairement : d'une semaine à l'autre et d'un créneau à l'autre, le
 * premier candidat change, donc la sélection tourne sans jamais tirer au sort.
 */
export function pickForGroup(
  byGroup: PoolByGroup,
  group: string,
  context: PickContext,
): PoolExercise | null {
  const candidates = byGroup.get(group);
  if (candidates === undefined || candidates.length === 0) return null;

  const cap = context.repeatRelaxed ? EXERCISE_WEEKLY_REPEAT_RELAXED : EXERCISE_WEEKLY_REPEAT_MAX;
  const start = rotationOffset(context.seed, context.slotIndex, context.week, candidates.length);

  for (let step = 0; step < candidates.length; step += 1) {
    const exercise = candidates[(start + step) % candidates.length]!;
    if (context.usedInSession.has(exercise.id)) continue;
    if ((context.usedInWeek.get(exercise.id) ?? 0) >= cap) continue;
    return exercise;
  }
  return null;
}

/**
 * L'ÉCHELLE DE DÉGRADATION, dans son ordre FIGÉ.
 *
 * 1. le groupe en PRINCIPAL — ce qu'on voulait ;
 * 2. le groupe en SECONDAIRE — il travaille, moins ;
 * 3. un groupe VOISIN — on entraîne autre chose, et on le dit.
 *
 * Ce qui n'est JAMAIS fait, à aucun échelon : relâcher la difficulté,
 * inventer un exercice, écrire une ligne sans `exerciseId`. Le plafond de
 * difficulté est la seule contrainte dont le relâchement serait un DANGER et
 * non une déception — servir des dips buste penché à quelqu'un qui n'a jamais
 * fait une pompe correcte parce qu'il ne restait rien d'autre.
 */
export function pickWithLadder(
  primary: PoolByGroup,
  secondary: PoolByGroup,
  neighbours: Record<string, string[]>,
  group: string,
  context: PickContext,
): Pick | null {
  const direct = pickForGroup(primary, group, context);
  if (direct !== null) return { exercise: direct, step: 'principal', servedGroup: group };

  const second = pickForGroup(secondary, group, context);
  if (second !== null) return { exercise: second, step: 'secondaire', servedGroup: group };

  for (const neighbour of neighbours[group] ?? []) {
    const fallback = pickForGroup(primary, neighbour, context);
    if (fallback !== null) {
      return { exercise: fallback, step: 'voisin', servedGroup: neighbour };
    }
  }
  return null;
}

/** Marque un exercice retenu, pour la séance et pour la semaine. */
export function markUsed(exercise: PoolExercise, context: PickContext): void {
  context.usedInSession.add(exercise.id);
  context.usedInWeek.set(exercise.id, (context.usedInWeek.get(exercise.id) ?? 0) + 1);
}

/** Un exercice polyarticulaire reçoit le repos long de la ligne d'objectif. */
export function needsLongRest(exercise: PoolExercise): boolean {
  return isPolyarticular(exercise);
}
