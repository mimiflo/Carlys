import { type ExercisesService } from '../../exercises/application/exercises.service';
import { type MealsService } from '../../nutrition/application/meals.service';
import { type NutritionService } from '../../nutrition/application/nutrition.service';
import { type ProgressService } from '../../progress/application/progress.service';
import { type WorkoutsService } from '../../workout_sessions/application/workouts.service';
import { type WorkoutTemplatesService } from '../../workout_templates/application/workout-templates.service';
import { COACH_TOOLS, CoachTools } from './coach.tools';

const USER = 'utilisateur-1';
const NOW = new Date('2026-08-09T10:00:00.000Z');
const DAY_MS = 86_400_000;

interface Stubs {
  meals: { list: jest.Mock };
  nutrition: { metabolismReport: jest.Mock };
}

function buildStubs(): Stubs {
  return {
    meals: {
      list: jest.fn().mockResolvedValue([
        {
          id: 'repas-1',
          name: 'Poulet riz',
          kcal: 650,
          proteinG: 45,
          eatenAt: NOW.toISOString(),
        },
      ]),
    },
    nutrition: { metabolismReport: jest.fn().mockResolvedValue({ missing: [] }) },
  };
}

function buildTools(stubs: Stubs): CoachTools {
  return new CoachTools(
    {} as unknown as ExercisesService,
    {} as unknown as WorkoutTemplatesService,
    {} as unknown as WorkoutsService,
    {} as unknown as ProgressService,
    stubs.nutrition as unknown as NutritionService,
    stubs.meals as unknown as MealsService,
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
