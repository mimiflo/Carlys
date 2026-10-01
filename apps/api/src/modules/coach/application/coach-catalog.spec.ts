import { type ExerciseSummary } from '@carlys/api-contracts';
import { type PinoLogger } from 'nestjs-pino';
import { type ListExercisesFilters } from '../../exercises/infrastructure/exercises.repository';
import {
  EQUIPMENT,
  EXERCISES,
  MUSCLE_GROUPS,
  type SeedExercise,
} from '../../exercises/application/catalog-data';
import { type ExercisesService } from '../../exercises/application/exercises.service';
import { CoachTools } from './coach.tools';

/**
 * TOUT le catalogue, cherché comme un modèle l'écrit, par le vrai code de
 * l'outil du coach (`search_exercises`).
 *
 * Né d'un constat du 1er octobre 2026 : « j'aimerais travailler les pecs »
 * ne trouvait aucun exercice, et un balayage du catalogue réel montrait 93
 * noms sur 190 introuvables sans leurs accents. Le faux service ci-dessous
 * reproduit la requête du dépôt (`ExercisesRepository.whereOf` : nom
 * contenu, casse ignorée mais PAS les accents, ou mot-clé exact ; groupe et
 * matériel par n'importe quel rôle ; tri par nom).
 */
const catalogue: ExercisesService = (() => {
  const summary = (exercise: SeedExercise): ExerciseSummary => ({
    id: exercise.slug,
    slug: exercise.slug,
    name: exercise.name,
    difficulty: exercise.difficulty,
    type: exercise.type,
    isPremium: exercise.isPremium ?? false,
    primaryMuscleGroup: {
      id: exercise.primary,
      slug: exercise.primary,
      name: MUSCLE_GROUPS.find((group) => group.slug === exercise.primary)?.name ?? '',
    },
    equipment: exercise.equipment.map((slug) => ({
      id: slug,
      slug,
      name: EQUIPMENT.find((item) => item.slug === slug)?.name ?? '',
    })),
    imageUrl: null,
  });
  const matches = (exercise: SeedExercise, filters: ListExercisesFilters) =>
    (filters.search === undefined ||
      exercise.name.toLowerCase().includes(filters.search.toLowerCase()) ||
      exercise.tags.includes(filters.search.toLowerCase())) &&
    (filters.muscleGroupSlug === undefined ||
      exercise.primary === filters.muscleGroupSlug ||
      exercise.secondary.includes(filters.muscleGroupSlug)) &&
    (filters.equipmentSlug === undefined || exercise.equipment.includes(filters.equipmentSlug));
  return {
    muscleGroups: () => Promise.resolve(MUSCLE_GROUPS),
    equipment: () => Promise.resolve(EQUIPMENT),
    list: (filters: ListExercisesFilters, limit: number) => {
      const items = EXERCISES.filter((exercise) => matches(exercise, filters))
        .sort((a, b) => a.name.localeCompare(b.name, 'fr'))
        .slice(0, limit)
        .map(summary);
      return Promise.resolve({ items, hasMore: false, total: items.length, nextCursor: null });
    },
  } as unknown as ExercisesService;
})();

// Les autres domaines ne servent pas ici ; le journal, si : il ne doit
// jamais signaler un catalogue trop grand pour la recherche.
const logger = { warn: jest.fn() };
const tools = new CoachTools(
  catalogue,
  ...(Array.from({ length: 8 }, () => ({})) as [
    never,
    never,
    never,
    never,
    never,
    never,
    never,
    never,
  ]),
  logger as unknown as PinoLogger,
);

interface Found {
  id: string;
  muscle: string | null;
  equipment: string[];
}

async function search(input: Record<string, unknown>): Promise<Found[]> {
  const [result] = await tools.run('balayage', [{ id: 'c', name: 'search_exercises', input }]);
  if (result === undefined || result.isError === true) {
    throw new Error(`Recherche refusée ${JSON.stringify(input)} : ${result?.content}`);
  }
  return JSON.parse(result.content) as Found[];
}

const fold = (text: string) => text.normalize('NFD').replace(/\p{Diacritic}/gu, '');

describe('le coach trouve tout le catalogue', () => {
  it('chaque exercice, par son nom tel qu’un modèle l’écrit', async () => {
    const missed: string[] = [];
    for (const exercise of EXERCISES) {
      const words = exercise.name.split(/\s+/);
      const variants = [
        exercise.name,
        exercise.name.toLowerCase(),
        fold(exercise.name).toLowerCase(),
        words.slice(0, 2).join(' '),
        [...words].reverse().join(' '),
      ];
      for (const variant of variants) {
        const found = await search({ search: variant });
        if (!found.some((item) => item.id === exercise.slug))
          missed.push(`${exercise.name} ← « ${variant} »`);
      }
    }
    expect(missed).toEqual([]);
  });

  it('chaque exercice, par son groupe PRINCIPAL et chacun de ses matériels', async () => {
    const missed: string[] = [];
    for (const exercise of EXERCISES) {
      for (const equipmentSlug of exercise.equipment) {
        const found = await search({ muscleGroupSlug: exercise.primary, equipmentSlug });
        if (!found.some((item) => item.id === exercise.slug)) {
          missed.push(`${exercise.name} ← ${exercise.primary} + ${equipmentSlug}`);
        }
      }
    }
    expect(missed).toEqual([]);
  });

  it('chaque groupe, nommé comme on le dit : nom, accents, phrase, mot de salle', async () => {
    const primaries = new Set(EXERCISES.map((exercise) => exercise.primary));
    const asked: [Record<string, unknown>, string][] = [
      ...MUSCLE_GROUPS.flatMap((group): [Record<string, unknown>, string][] => [
        [{ muscleGroupSlug: group.name }, group.slug],
        [{ search: group.name }, group.slug],
        [{ search: `exercices ${group.name.toLowerCase()}` }, group.slug],
      ]),
      [{ search: 'pecs' }, 'pectoraux'],
      [{ search: 'abdos' }, 'abdominaux'],
      [{ search: 'ischios' }, 'ischio-jambiers'],
    ];
    const missed: string[] = [];
    for (const [input, slug] of asked) {
      const found = await search(input);
      // Un groupe qui n'est le muscle principal d'aucun exercice (avant-bras)
      // se trouve par ses exercices, où il est secondaire.
      const ok = primaries.has(slug) ? found[0]?.muscle === slug : found.length > 0;
      if (!ok) missed.push(`${JSON.stringify(input)} → ${found[0]?.muscle ?? 'rien'}`);
    }
    expect(missed).toEqual([]);
  });

  it('chaque matériel utilisé, nommé comme on le dit', async () => {
    const used = new Set(EXERCISES.flatMap((exercise) => exercise.equipment));
    const missed: string[] = [];
    for (const item of EQUIPMENT.filter((entry) => used.has(entry.slug))) {
      const found = await search({ equipmentSlug: item.name });
      if (found.length === 0 || !found.every((entry) => entry.equipment.includes(item.slug))) {
        missed.push(item.name);
      }
    }
    expect(missed).toEqual([]);
  });

  it('le catalogue entier tient dans une lecture de la recherche', () => {
    expect(logger.warn).not.toHaveBeenCalled();
  });
});
