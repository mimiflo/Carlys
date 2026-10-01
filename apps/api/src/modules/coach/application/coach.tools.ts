import { type ProgressPeriod } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { BodyMetricType } from '@prisma/client';
import { ExercisesService } from '../../exercises/application/exercises.service';
import { MealsService } from '../../nutrition/application/meals.service';
import { NutritionService } from '../../nutrition/application/nutrition.service';
import { BodyMetricsService } from '../../progress/application/body-metrics.service';
import { ProgramsService } from '../../programs/application/programs.service';
import { ProgressService } from '../../progress/application/progress.service';
import { UsersService } from '../../users/application/users.service';
import { WorkoutsService } from '../../workout_sessions/application/workouts.service';
import { WorkoutTemplatesService } from '../../workout_templates/application/workout-templates.service';
import { exerciseSearchFilters, filtersFromSearch } from './coach-exercise-search';
import { coachMealView } from './coach-meal-view';
import {
  coachBodyMetricView,
  coachExerciseView,
  coachRecordView,
  coachSessionView,
  coachTemplateSummaryView,
  coachTemplateView,
} from './coach-views';
import { type CoachToolCall, type CoachToolResult } from '../domain/coach-model.port';

/**
 * Outils du coach — **tous en lecture**, tous branchés sur les services des
 * domaines voisins. Aucun accès Prisma direct : le coach n'a pas de vue
 * privilégiée sur les données des autres modules, il passe par la même porte
 * que les écrans.
 *
 * Ce que le modèle voit de ces outils (noms, descriptions, schémas) vit dans
 * `coach.tool-definitions.ts`.
 */

const DEFAULT_LIMIT = 10;
const MAX_LIMIT = 30;
/** Fenêtre du journal alimentaire : la veille par défaut, une semaine au plus. */
const DEFAULT_MEAL_DAYS = 1;
const MAX_MEAL_DAYS = 7;
const DAY_MS = 86_400_000;

/** Exécution des outils de lecture, pour un utilisateur donné. */
@Injectable()
export class CoachTools {
  constructor(
    private readonly exercises: ExercisesService,
    private readonly templates: WorkoutTemplatesService,
    private readonly workouts: WorkoutsService,
    private readonly progress: ProgressService,
    private readonly metrics: BodyMetricsService,
    private readonly nutrition: NutritionService,
    private readonly meals: MealsService,
    private readonly users: UsersService,
    private readonly programs: ProgramsService,
  ) {}

  async run(userId: string, calls: CoachToolCall[]): Promise<CoachToolResult[]> {
    return Promise.all(calls.map((call) => this.runOne(userId, call)));
  }

  private async runOne(userId: string, call: CoachToolCall): Promise<CoachToolResult> {
    try {
      const payload = await this.dispatch(userId, call);
      return { id: call.id, content: JSON.stringify(payload) };
    } catch (error) {
      // Un outil qui échoue n'interrompt pas le tour : le modèle en est
      // informé et peut se rabattre sur autre chose.
      const message = error instanceof Error ? error.message : 'Outil indisponible.';
      return { id: call.id, content: message, isError: true };
    }
  }

  private async dispatch(userId: string, call: CoachToolCall): Promise<unknown> {
    const input = call.input;

    switch (call.name) {
      case 'search_exercises':
        return this.searchExercises(input);

      // Les lectures passent par les vues du coach (coach-views.ts) : les
      // contrats d'écran, relus tels quels à chaque tour, coûtaient des
      // secondes de réponse en identifiants que le modèle n'utilise pas.
      case 'list_workout_templates':
        return (await this.templates.listTemplates(userId, DEFAULT_LIMIT)).items.map(
          coachTemplateSummaryView,
        );

      case 'get_workout_template':
        return coachTemplateView(
          await this.templates.templateDetail(userId, asString(input.templateId) ?? ''),
        );

      case 'get_recent_sessions': {
        const limit = asBoundedInteger(input.limit, DEFAULT_LIMIT, MAX_LIMIT);
        return (await this.workouts.listSessions(userId, limit)).items.map(coachSessionView);
      }

      case 'get_personal_records':
        return (await this.progress.records(userId)).map(coachRecordView);

      case 'get_progress_overview':
        return this.progress.overview(userId, asPeriod(input.period));

      case 'get_body_weight_trend':
        return (
          await this.metrics.listBodyMetrics(userId, BodyMetricType.WEIGHT_KG, DEFAULT_LIMIT)
        ).map(coachBodyMetricView);

      case 'get_nutrition_targets':
        return this.nutrition.metabolismReport(userId);

      case 'get_recent_meals': {
        // Des INSTANTS UTC : le découpage en journées appartient au client,
        // le coach reçoit une fenêtre glissante qui se termine maintenant.
        const to = new Date();
        const days = asBoundedInteger(input.days, DEFAULT_MEAL_DAYS, MAX_MEAL_DAYS);
        const meals = await this.meals.list(userId, new Date(to.getTime() - days * DAY_MS), to);
        return meals.map(coachMealView);
      }

      case 'get_training_profile': {
        const [profile, active] = await Promise.all([
          this.users.training(userId),
          this.programs.activeProgramName(userId),
        ]);
        return { ...profile, activeProgram: active === null ? null : { name: active } };
      }

      default:
        throw new Error(`Outil inconnu : ${call.name}`);
    }
  }

  /**
   * Ce que le modèle écrit, traduit vers le catalogue
   * (`coach-exercise-search.ts`). Des mots du nom qui ne figurent dans aucun
   * exercice (« exercices de », « muscler ») ne doivent pas vider un filtre
   * de groupe ou de matériel valable : sans résultat, on les relâche.
   */
  private async searchExercises(input: Record<string, unknown>) {
    const [muscleGroups, equipment] = await Promise.all([
      this.exercises.muscleGroups(),
      this.exercises.equipment(),
    ]);
    const catalog = { muscleGroups, equipment };
    const exact = exerciseSearchFilters(input, catalog);
    // Le nom tel quel, puis le muscle ou le matériel tirés des mots, puis le
    // filtre seul : on s'arrête au premier essai qui trouve.
    const pulled = filtersFromSearch(exact, catalog);
    const last = pulled ?? exact;
    const tries = [exact, ...(pulled === null ? [] : [pulled])];
    if (last.search !== undefined && (last.muscleGroupSlug ?? last.equipmentSlug) !== undefined) {
      tries.push({ ...last, search: undefined });
    }
    for (const filters of tries) {
      const page = await this.exercises.list(filters, DEFAULT_LIMIT);
      if (page.items.length > 0) return page.items.map(coachExerciseView);
    }
    return [];
  }
}

function asString(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
}

/** Entier borné à [1, max] ; tout ce qui n'en est pas un retombe sur le défaut. */
function asBoundedInteger(value: unknown, fallback: number, max: number): number {
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    return fallback;
  }
  return Math.min(Math.max(value, 1), max);
}

const PERIODS = ['week', 'month', 'year'] as const;

function asPeriod(value: unknown): ProgressPeriod {
  return typeof value === 'string' && (PERIODS as readonly string[]).includes(value)
    ? (value as ProgressPeriod)
    : 'month';
}
