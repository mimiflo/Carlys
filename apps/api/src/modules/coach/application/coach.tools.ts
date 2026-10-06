import {
  type ExerciseSummary,
  type ProgressPeriod,
  progressPeriodSchema,
} from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
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
import {
  exerciseSearchFilters,
  filtersFromSearch,
  matchByName,
  primaryOnly,
  text,
} from './coach-exercise-search';
import {
  coachBodyMetricView,
  coachExerciseView,
  coachMealView,
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
/**
 * Exercices rendus par une recherche : la plus grosse combinaison groupe
 * principal + matériel du catalogue en compte 15 (épaules + haltères).
 */
const SEARCH_LIMIT = 15;
/** Le catalogue entier tient dans une lecture (190 exercices, en cache). */
const CATALOG_MAX = 500;
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
    @InjectPinoLogger(CoachTools.name) private readonly logger: PinoLogger,
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
      // Les siens d'abord : toute séance proposée est gardée (`fromCoach`),
      // et les dernières du coach évinceraient sinon celles de la personne.
      case 'list_workout_templates': {
        const { items } = await this.templates.listTemplates(userId, MAX_LIMIT);
        return [...items.filter((t) => !t.fromCoach), ...items.filter((t) => t.fromCoach)]
          .slice(0, DEFAULT_LIMIT)
          .map(coachTemplateSummaryView);
      }

      case 'get_workout_template':
        return coachTemplateView(
          await this.templates.templateDetail(userId, text(input.templateId) ?? ''),
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
   * (`coach-exercise-search.ts`), puis cherché en deux temps : le nom tel
   * quel par le dépôt ; sinon, dans le catalogue filtré par groupe et
   * matériel, chaque mot sans accents et dans n'importe quel ordre ; sinon,
   * le filtre seul (des mots comme « exercices » ou « muscler » ne figurent
   * dans aucun nom). Balayé sur les 190 exercices du catalogue : chacun se
   * trouve par son nom, avec ou sans accents, et par son groupe principal
   * avec chacun de ses matériels.
   */
  private async searchExercises(input: Record<string, unknown>) {
    // Hors du schéma montré au modèle : les lectures d'avance d'une séance
    // (coach-prefetch.ts) bornent chaque groupe, pour tenir dans le contexte.
    const limit = asBoundedInteger(input.limit, SEARCH_LIMIT, SEARCH_LIMIT);
    const [muscleGroups, equipment] = await Promise.all([
      this.exercises.muscleGroups(),
      this.exercises.equipment(),
    ]);
    const catalog = { muscleGroups, equipment };
    const exact = exerciseSearchFilters(input, catalog);
    const pulled = filtersFromSearch(exact, catalog);
    // Toute la recherche nomme un groupe ou un matériel (« avant-bras ») :
    // c'est le groupe entier qu'on veut, pas les deux exercices qui portent
    // ce mot-clé.
    const onlyFilters = pulled !== null && pulled.search === undefined;
    if (exact.search !== undefined && !onlyFilters) {
      const found = (await this.exercises.list(exact, SEARCH_LIMIT)).items;
      if (found.length > 0) return this.shown(found, exact.muscleGroupSlug, limit);
    }
    // D'abord le nom ENTIER (« Face Pull à la barre » se fait à la poulie :
    // en tirer le filtre « barre » l'écarterait), puis le groupe ou le
    // matériel tirés de ses mots.
    const attempts = pulled === null ? [exact] : onlyFilters ? [pulled] : [exact, pulled];
    let pool: ExerciseSummary[] = [];
    for (const filters of attempts) {
      const { muscleGroupSlug, equipmentSlug } = filters;
      const page = await this.exercises.list({ muscleGroupSlug, equipmentSlug }, CATALOG_MAX);
      if (page.hasMore) {
        // Le catalogue a dépassé ce qu'une lecture couvre : des exercices
        // deviendraient introuvables par le nom, sans que rien ne le dise.
        this.logger.warn({ max: CATALOG_MAX }, 'Catalogue plus grand que la recherche du coach');
      }
      pool = page.items;
      const named = filters.search === undefined ? pool : matchByName(pool, filters.search);
      if (named.length > 0) return this.shown(named, muscleGroupSlug, limit);
    }
    // Ni nom ni filtre qui tienne : rien, plutôt que des exercices au hasard.
    const last = pulled ?? exact;
    const filtered = last.muscleGroupSlug !== undefined || last.equipmentSlug !== undefined;
    return filtered ? this.shown(pool, last.muscleGroupSlug, limit) : [];
  }

  /** Muscle principal seul s'il y en a, borné, dans la vue du coach. */
  private shown(items: readonly ExerciseSummary[], muscle: string | undefined, limit: number) {
    return primaryOnly(items, muscle).slice(0, limit).map(coachExerciseView);
  }
}

/** Entier borné à [1, max] ; tout ce qui n'en est pas un retombe sur le défaut. */
function asBoundedInteger(value: unknown, fallback: number, max: number): number {
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    return fallback;
  }
  return Math.min(Math.max(value, 1), max);
}

function asPeriod(value: unknown): ProgressPeriod {
  return progressPeriodSchema.catch('month').parse(value);
}
