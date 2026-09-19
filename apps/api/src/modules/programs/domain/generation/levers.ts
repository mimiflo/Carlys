import { ExerciseDifficulty, ExerciseType, type TrainingExperience } from '@prisma/client';
import { type EquipmentLever, type PoolExercise } from './types';

/**
 * LES LEVIERS — ce qu'il faudrait ajouter au kit, et ce qui n'aiderait PAS.
 *
 * Tout est CALCULÉ sur le catalogue reçu, jamais écrit en dur. C'est ce qui
 * distingue un conseil d'une devinette : quand le catalogue s'enrichit, le
 * conseil suit ; quand un matériel n'ouvre rien AU NIVEAU DE LA PERSONNE, il
 * n'est pas proposé.
 *
 * Le second point est le piège que ce fichier existe pour éviter. Compter les
 * exercices qu'un matériel débloque TOUS NIVEAUX CONFONDUS donne des conseils
 * faux : au moment où ces règles ont été écrites, une barre de traction
 * ajoutait sept exercices de dos au catalogue et ZÉRO à un débutant, parce
 * qu'aucune traction n'est classée débutant. Envoyer quelqu'un acheter du
 * matériel qui ne lui débloquera rien est pire que se taire.
 */

const DIFFICULTY_ORDER: Record<ExerciseDifficulty, number> = {
  BEGINNER: 0,
  INTERMEDIATE: 1,
  ADVANCED: 2,
};

const CEILING: Record<TrainingExperience, ExerciseDifficulty> = {
  BEGINNER: ExerciseDifficulty.BEGINNER,
  INTERMEDIATE: ExerciseDifficulty.INTERMEDIATE,
  ADVANCED: ExerciseDifficulty.ADVANCED,
};

/** Un exercice qui ENTRAÎNE : ni étirement, ni mobilité. */
function trains(exercise: PoolExercise): boolean {
  return exercise.type === ExerciseType.STRENGTH || exercise.type === ExerciseType.CARDIO;
}

export function playableAt(exercise: PoolExercise, experience: TrainingExperience): boolean {
  return DIFFICULTY_ORDER[exercise.difficulty] <= DIFFICULTY_ORDER[CEILING[experience]];
}

/** L'exercice se joue-t-il avec ce kit ? INCLUSION, jamais intersection. */
export function playableWith(exercise: PoolExercise, kit: Set<string>): boolean {
  return exercise.equipment.length > 0 && exercise.equipment.every((slug) => kit.has(slug));
}

/**
 * Les matériels qui ouvriraient les groupes manquants, du plus utile au moins.
 *
 * `catalogue` est le catalogue ENTIER (tous matériels, toutes difficultés),
 * parce qu'on veut justement mesurer ce qui n'est pas encore dans le kit.
 * Le filtre de difficulté, lui, reste appliqué : c'est le sens du conseil.
 */
export function suggestLevers(
  catalogue: PoolExercise[],
  kit: Set<string>,
  experience: TrainingExperience,
  missingGroups: string[],
  names: Record<string, string> = {},
): EquipmentLever[] {
  const wanted = new Set(missingGroups);
  const gains = new Map<string, { count: number; groups: Set<string> }>();

  for (const exercise of catalogue) {
    if (!trains(exercise) || !playableAt(exercise, experience)) continue;
    if (!wanted.has(exercise.primary)) continue;
    if (playableWith(exercise, kit)) continue;

    const missing = exercise.equipment.filter((slug) => !kit.has(slug));
    // Un exercice qui exige DEUX matériels absents n'est débloqué par aucun
    // des deux pris isolément : le compter pour chacun promettrait un gain
    // que l'achat ne rendrait pas.
    if (missing.length !== 1) continue;

    const slug = missing[0]!;
    const entry = gains.get(slug) ?? { count: 0, groups: new Set<string>() };
    entry.count += 1;
    entry.groups.add(exercise.primary);
    gains.set(slug, entry);
  }

  return (
    [...gains.entries()]
      .map(([slug, entry]) => ({
        slug,
        name: names[slug] ?? slug,
        unlocks: entry.count,
        muscleGroups: [...entry.groups].sort(),
      }))
      // Gain nul écarté : une suggestion qui n'ouvre rien est une fausse piste.
      .filter((lever) => lever.unlocks > 0)
      .sort((a, b) => b.unlocks - a.unlocks || (a.slug < b.slug ? -1 : 1))
  );
}

/**
 * Les matériels que la personne pourrait croire utiles et qui ne le sont pas.
 *
 * Rendu au rapport pour qu'elle n'achète pas à l'aveugle : un matériel
 * absent du kit dont TOUS les exercices sur les groupes manquants sont
 * au-dessus de son niveau.
 */
export function uselessLevers(
  catalogue: PoolExercise[],
  kit: Set<string>,
  experience: TrainingExperience,
  missingGroups: string[],
  names: Record<string, string> = {},
): string[] {
  const wanted = new Set(missingGroups);
  const utile = new Set(
    suggestLevers(catalogue, kit, experience, missingGroups).map((l) => l.slug),
  );
  const vus = new Set<string>();

  for (const exercise of catalogue) {
    if (!trains(exercise) || !wanted.has(exercise.primary)) continue;
    const missing = exercise.equipment.filter((slug) => !kit.has(slug));
    if (missing.length !== 1) continue;
    const slug = missing[0]!;
    if (!utile.has(slug)) vus.add(names[slug] ?? slug);
  }
  return [...vus].sort();
}
