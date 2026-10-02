import { type MealEntry } from '@carlys/api-contracts';
import { type PinoLogger } from 'nestjs-pino';
import { type ExercisesService } from '../../exercises/application/exercises.service';
import { type MealsService } from '../../nutrition/application/meals.service';
import { type NutritionService } from '../../nutrition/application/nutrition.service';
import { type BodyMetricsService } from '../../progress/application/body-metrics.service';
import { type ProgramsService } from '../../programs/application/programs.service';
import { type ProgressService } from '../../progress/application/progress.service';
import { type UsersService } from '../../users/application/users.service';
import { type WorkoutsService } from '../../workout_sessions/application/workouts.service';
import { type WorkoutTemplatesService } from '../../workout_templates/application/workout-templates.service';
import { COACH_TOOLS } from './coach.tool-definitions';
import { CoachTools } from './coach.tools';

const USER = 'utilisateur-1';
const NOW = new Date('2026-08-09T10:00:00.000Z');
const DAY_MS = 86_400_000;

interface Stubs {
  meals: { list: jest.Mock };
  nutrition: { metabolismReport: jest.Mock };
  users: { training: jest.Mock };
  programs: { activeProgramName: jest.Mock };
}

function buildStubs(): Stubs {
  return {
    meals: {
      list: jest.fn().mockResolvedValue([
        {
          id: 'repas-1',
          name: 'Poulet riz',
          moment: 'DINNER',
          kcal: 650,
          quantity: 270,
          quantityUnit: 'GRAM',
          proteinG: 45,
          carbsG: 80,
          fatG: null,
          eatenAt: NOW.toISOString(),
          components: [
            {
              id: 'composant-1',
              foodCode: 990001,
              name: 'Poulet, filet, sans peau, cuit',
              shortName: 'Poulet',
              group: 'viandes, œufs, poissons et assimilés',
              sourceVersion: '2020-07-07',
              quantityG: 120,
              kcal: 180,
              proteinG: 34.8,
              carbsG: 0,
              fatG: null,
            },
          ],
          computed: true,
          // Un repas AVEC photo : la vue du coach doit la laisser de côté
          // (docs/legal/privacy.md : jamais transmise à un prestataire).
          photo: { updatedAt: '2026-09-25T08:00:00.000Z' },
        } satisfies MealEntry,
      ]),
    },
    nutrition: { metabolismReport: jest.fn().mockResolvedValue({ missing: [] }) },
    users: {
      training: jest.fn().mockResolvedValue({
        trainingGoal: 'STRENGTH',
        trainingExperience: 'INTERMEDIATE',
        weeklySessionsTarget: 3,
        sessionMinutesTarget: 45,
        equipmentSlugs: ['halteres'],
      }),
    },
    programs: { activeProgramName: jest.fn().mockResolvedValue('Force 3 jours') },
  };
}

function buildTools(stubs: Stubs, exercises: object = {}): CoachTools {
  return new CoachTools(
    exercises as unknown as ExercisesService,
    {} as unknown as WorkoutTemplatesService,
    {} as unknown as WorkoutsService,
    {} as unknown as ProgressService,
    {} as unknown as BodyMetricsService,
    stubs.nutrition as unknown as NutritionService,
    stubs.meals as unknown as MealsService,
    stubs.users as unknown as UsersService,
    stubs.programs as unknown as ProgramsService,
    { warn: jest.fn() } as unknown as PinoLogger,
  );
}

/**
 * Le journal alimentaire existe (module nutrition) : le coach doit pouvoir le
 * lire par la même porte que l'écran, et aucune description ne doit plus
 * affirmer le contraire au modèle.
 */
describe('CoachTools', () => {
  beforeEach(() => {
    jest.useFakeTimers({ now: NOW });
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('search_exercises : le muscle glissé dans les mots du nom trouve quand même', async () => {
    // Constaté sur Qwen3-4B : « pectoraux » en mots du nom, et des mots
    // qu'aucun nom ne contient. La liste vide faisait conclure au coach
    // qu'il n'existait aucun exercice pour les pectoraux.
    const pushUp = {
      id: 'ex-pompes',
      slug: 'pompes',
      name: 'Pompes',
      difficulty: 'BEGINNER',
      type: 'STRENGTH',
      isPremium: false,
      primaryMuscleGroup: { id: 'g-1', slug: 'pectoraux', name: 'Pectoraux' },
      equipment: [{ id: 'e-1', slug: 'poids-du-corps', name: 'Poids du corps' }],
      imageUrl: 'https://cdn.example/pompes.webp',
    };
    const exercises = {
      muscleGroups: jest.fn().mockResolvedValue([{ slug: 'pectoraux', name: 'Pectoraux' }]),
      equipment: jest.fn().mockResolvedValue([{ slug: 'poids-du-corps', name: 'Poids du corps' }]),
      list: jest
        .fn()
        .mockResolvedValueOnce({ items: [], hasMore: false, total: 0, nextCursor: null })
        .mockResolvedValue({ items: [pushUp], hasMore: false, total: 1, nextCursor: null }),
    };
    const tools = buildTools(buildStubs(), exercises);

    const [result] = await tools.run(USER, [
      { id: 'c1', name: 'search_exercises', input: { search: 'exercices pectoraux' } },
    ]);

    // D'abord le nom tel quel : un nom exact se trouve d'un seul tenant.
    expect(exercises.list).toHaveBeenNthCalledWith(
      1,
      { search: 'exercices pectoraux' },
      expect.any(Number),
    );
    // Puis le catalogue entier, nom comparé sans accents ; puis le catalogue
    // du groupe tiré des mots : « exercices » n'est dans aucun nom, le
    // filtre de groupe seul répond.
    expect(exercises.list).toHaveBeenNthCalledWith(2, {}, expect.any(Number));
    expect(exercises.list).toHaveBeenNthCalledWith(
      3,
      { muscleGroupSlug: 'pectoraux' },
      expect.any(Number),
    );
    expect(exercises.list).toHaveBeenCalledTimes(3);
    // La vue du coach : de quoi citer et proposer, sans image ni slug.
    expect(JSON.parse(result?.content ?? '')).toEqual([
      {
        id: 'ex-pompes',
        name: 'Pompes',
        difficulty: 'BEGINNER',
        muscle: 'pectoraux',
        equipment: ['poids-du-corps'],
      },
    ]);
  });

  it('search_exercises : `limit` borne la liste (lectures d’avance d’une séance)', async () => {
    const exercise = (id: string) => ({
      id,
      slug: id,
      name: id,
      difficulty: 'BEGINNER',
      type: 'STRENGTH',
      isPremium: false,
      primaryMuscleGroup: { id: 'g-1', slug: 'pectoraux', name: 'Pectoraux' },
      equipment: [],
      imageUrl: null,
    });
    const exercises = {
      muscleGroups: jest.fn().mockResolvedValue([{ slug: 'pectoraux', name: 'Pectoraux' }]),
      equipment: jest.fn().mockResolvedValue([]),
      list: jest.fn().mockResolvedValue({
        items: ['a', 'b', 'c'].map(exercise),
        hasMore: false,
        total: 3,
        nextCursor: null,
      }),
    };
    const tools = buildTools(buildStubs(), exercises);

    const [bounded, unbounded] = await tools.run(USER, [
      { id: 'c1', name: 'search_exercises', input: { muscleGroupSlug: 'pectoraux', limit: 2 } },
      { id: 'c2', name: 'search_exercises', input: { muscleGroupSlug: 'pectoraux', limit: 999 } },
    ]);

    expect(JSON.parse(bounded?.content ?? '')).toHaveLength(2);
    // Jamais au-delà du plafond ordinaire.
    expect(JSON.parse(unbounded?.content ?? '')).toHaveLength(3);
  });

  it('search_exercises : un groupe inconnu revient au modèle avec les valeurs possibles', async () => {
    const exercises = {
      muscleGroups: jest.fn().mockResolvedValue([{ slug: 'pectoraux', name: 'Pectoraux' }]),
      equipment: jest.fn().mockResolvedValue([]),
      list: jest.fn(),
    };
    const [result] = await buildTools(buildStubs(), exercises).run(USER, [
      { id: 'c1', name: 'search_exercises', input: { muscleGroupSlug: 'jambes' } },
    ]);

    expect(result?.isError).toBe(true);
    expect(result?.content).toContain('Valeurs possibles : pectoraux');
    expect(exercises.list).not.toHaveBeenCalled();
  });

  it('get_training_profile rend le profil et le programme en cours', async () => {
    const stubs = buildStubs();

    const [result] = await buildTools(stubs).run(USER, [
      { id: 'appel-1', name: 'get_training_profile', input: {} },
    ]);

    expect(stubs.users.training).toHaveBeenCalledWith(USER);
    expect(JSON.parse(result?.content ?? '{}')).toMatchObject({
      trainingGoal: 'STRENGTH',
      weeklySessionsTarget: 3,
      activeProgram: { name: 'Force 3 jours' },
    });
  });

  it('get_recent_meals lit le journal sur une fenêtre de N jours qui se termine maintenant', async () => {
    const stubs = buildStubs();
    const tools = buildTools(stubs);

    const [result] = await tools.run(USER, [
      { id: 'appel-1', name: 'get_recent_meals', input: { days: 3 } },
    ]);

    expect(stubs.meals.list).toHaveBeenCalledWith(USER, new Date(NOW.getTime() - 3 * DAY_MS), NOW);
    expect(result?.isError).toBeUndefined();
    expect(result?.content).toContain('Poulet riz');
  });

  it('get_recent_meals transmet le moment et la composition en clair, sans le détail d’écran ni la photo', async () => {
    const stubs = buildStubs();
    const tools = buildTools(stubs);

    const [result] = await tools.run(USER, [{ id: 'a', name: 'get_recent_meals', input: {} }]);
    const [meal] = JSON.parse(result?.content ?? '[]') as Record<string, unknown>[];

    expect(meal).toEqual({
      name: 'Poulet riz',
      moment: 'DINNER',
      eatenAt: NOW.toISOString(),
      kcal: 650,
      proteinG: 45,
      carbsG: 80,
      fatG: null,
      quantity: 270,
      quantityUnit: 'GRAM',
      computed: true,
      foods: ['Poulet, filet, sans peau, cuit : 120 g'],
    });
  });

  it('get_recent_meals : la veille par défaut, une semaine au plus', async () => {
    const stubs = buildStubs();
    const tools = buildTools(stubs);

    await tools.run(USER, [{ id: 'a', name: 'get_recent_meals', input: {} }]);
    expect(stubs.meals.list).toHaveBeenLastCalledWith(USER, new Date(NOW.getTime() - DAY_MS), NOW);

    await tools.run(USER, [{ id: 'b', name: 'get_recent_meals', input: { days: 30 } }]);
    expect(stubs.meals.list).toHaveBeenLastCalledWith(
      USER,
      new Date(NOW.getTime() - 7 * DAY_MS),
      NOW,
    );

    // Une valeur qui n'est pas un entier retombe sur le défaut, jamais sur une erreur.
    await tools.run(USER, [{ id: 'c', name: 'get_recent_meals', input: { days: 'hier' } }]);
    expect(stubs.meals.list).toHaveBeenLastCalledWith(USER, new Date(NOW.getTime() - DAY_MS), NOW);
  });

  it('get_nutrition_targets rend toujours les OBJECTIFS, par le service de nutrition', async () => {
    const stubs = buildStubs();
    const tools = buildTools(stubs);

    const [result] = await tools.run(USER, [
      { id: 'appel-1', name: 'get_nutrition_targets', input: {} },
    ]);

    expect(stubs.nutrition.metabolismReport).toHaveBeenCalledWith(USER);
    expect(result?.isError).toBeUndefined();
  });

  it('un outil inconnu répond en erreur sans faire tomber le tour', async () => {
    const tools = buildTools(buildStubs());

    const [result] = await tools.run(USER, [{ id: 'appel-1', name: 'inconnu', input: {} }]);

    expect(result).toEqual({ id: 'appel-1', content: 'Outil inconnu : inconnu', isError: true });
  });

  it('aucune description ne prétend plus que l’application n’a pas de journal alimentaire', () => {
    expect(COACH_TOOLS.map((tool) => tool.name)).toContain('get_recent_meals');
    for (const tool of COACH_TOOLS) {
      expect(tool.description).not.toMatch(/n’a pas de journal alimentaire/);
    }
  });
});
