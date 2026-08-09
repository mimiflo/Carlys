import { type ProgressPeriod } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { BodyMetricType } from '@prisma/client';
import { ExercisesService } from '../../exercises/application/exercises.service';
import { NutritionService } from '../../nutrition/application/nutrition.service';
import { ProgressService } from '../../progress/application/progress.service';
import { WorkoutsService } from '../../workout_sessions/application/workouts.service';
import { WorkoutTemplatesService } from '../../workout_templates/application/workout-templates.service';
import {
  type CoachToolCall,
  type CoachToolDefinition,
  type CoachToolResult,
} from '../domain/coach-model.port';

/**
 * Outils du coach — **tous en lecture**, tous branchés sur les services des
 * domaines voisins. Aucun accès Prisma direct : le coach n'a pas de vue
 * privilégiée sur les données des autres modules, il passe par la même porte
 * que les écrans.
 *
 * Chaque description dit QUAND appeler l'outil, pas seulement ce qu'il fait :
 * c'est ce qui pèse le plus sur la justesse du déclenchement.
 */

export const PROPOSE_SESSION_TOOL = 'propose_session';

const DEFAULT_LIMIT = 10;

export const COACH_TOOLS: CoachToolDefinition[] = [
  {
    name: 'search_exercises',
    description:
      'Cherche des exercices dans le catalogue. Appelle-le dès que tu dois nommer ' +
      'un exercice ou obtenir son identifiant — tu ne peux en proposer aucun sans ' +
      'être passé par ici.',
    inputSchema: {
      type: 'object',
      properties: {
        search: { type: 'string', description: 'Mots du nom recherché.' },
        muscleGroupSlug: { type: 'string', description: 'Ex. pectoraux, dos, jambes.' },
        equipmentSlug: { type: 'string', description: 'Ex. barre, halteres, poids-du-corps.' },
      },
    },
  },
  {
    name: 'list_workout_templates',
    description:
      'Liste les modèles de séance de l’utilisateur. Appelle-le AVANT toute ' +
      'adaptation de séance : partir de ce qu’il a prévu vaut mieux que composer ' +
      'de zéro.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'get_workout_template',
    description:
      'Détaille un modèle : exercices, séries prévues, charges cibles, repos. ' +
      'Appelle-le quand tu adaptes une séance à partir d’un modèle.',
    inputSchema: {
      type: 'object',
      properties: { templateId: { type: 'string' } },
      required: ['templateId'],
    },
  },
  {
    name: 'get_recent_sessions',
    description:
      'Les dernières séances terminées. Appelle-le pour savoir ce qui a été fait ' +
      'récemment, à quelle charge, et à quelle fréquence.',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'integer', description: 'Nombre de séances (défaut 10).' },
      },
    },
  },
  {
    name: 'get_personal_records',
    description:
      'Les records de l’utilisateur, recalculés à la clôture de chaque séance. ' +
      'Appelle-le pour situer une performance ou proposer une charge.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'get_progress_overview',
    description:
      'Volume, assiduité et tendances sur une période. Appelle-le quand la ' +
      'question porte sur la progression d’ensemble plutôt que sur une séance.',
    inputSchema: {
      type: 'object',
      properties: {
        period: { type: 'string', enum: ['week', 'month', 'year'] },
      },
    },
  },
  {
    name: 'get_body_weight_trend',
    description:
      'Les dernières pesées, de la plus ancienne à la plus récente. Appelle-le ' +
      'quand la question touche au poids ou à une évolution corporelle.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'get_nutrition_targets',
    description:
      'Les cibles caloriques et de macros calculées par l’application. ATTENTION : ' +
      'ce sont des OBJECTIFS, pas ce qui a été mangé — l’application n’a pas de ' +
      'journal alimentaire, ne prétends jamais connaître les apports réels.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: PROPOSE_SESSION_TOOL,
    description:
      'Propose une séance adaptée. N’écrit RIEN : produit un document que ' +
      'l’utilisateur acceptera ou non. Chaque exerciseId doit venir d’un outil de ' +
      'lecture ; un identifiant inventé fait rejeter toute la proposition. Les ' +
      'positions commencent à 0 et se suivent sans trou.',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Nom court de la séance.' },
        estimatedMinutes: { type: 'integer' },
        items: {
          type: 'array',
          description: 'Une entrée PAR SÉRIE, pas par exercice.',
          items: {
            type: 'object',
            properties: {
              exercisePosition: { type: 'integer' },
              exerciseId: { type: 'string' },
              setPosition: { type: 'integer' },
              kind: { type: 'string', enum: ['WARMUP', 'NORMAL', 'DROP'] },
              targetReps: { type: 'integer' },
              targetWeightKg: { type: 'number' },
              restSeconds: { type: 'integer' },
            },
            required: ['exercisePosition', 'exerciseId', 'setPosition'],
          },
        },
      },
      required: ['name', 'estimatedMinutes', 'items'],
    },
  },
];

/** Exécution des outils de lecture, pour un utilisateur donné. */
@Injectable()
export class CoachTools {
  constructor(
    private readonly exercises: ExercisesService,
    private readonly templates: WorkoutTemplatesService,
    private readonly workouts: WorkoutsService,
    private readonly progress: ProgressService,
    private readonly nutrition: NutritionService,
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
        return this.exercises.list(
          {
            search: asString(input.search),
            muscleGroupSlug: asString(input.muscleGroupSlug),
            equipmentSlug: asString(input.equipmentSlug),
          },
          DEFAULT_LIMIT,
        );

      case 'list_workout_templates':
        return this.templates.listTemplates(userId, DEFAULT_LIMIT);

      case 'get_workout_template':
        return this.templates.templateDetail(userId, asString(input.templateId) ?? '');

      case 'get_recent_sessions':
        return this.workouts.listSessions(userId, asLimit(input.limit));

      case 'get_personal_records':
        return this.progress.records(userId);

      case 'get_progress_overview':
        return this.progress.overview(userId, asPeriod(input.period));

      case 'get_body_weight_trend':
        return this.progress.listBodyMetrics(userId, BodyMetricType.WEIGHT_KG, DEFAULT_LIMIT);

      case 'get_nutrition_targets':
        return this.nutrition.metabolismReport(userId);

      default:
        throw new Error(`Outil inconnu : ${call.name}`);
    }
  }
}

function asString(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
}

function asLimit(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    return DEFAULT_LIMIT;
  }
  return Math.min(Math.max(value, 1), 30);
}

const PERIODS = ['week', 'month', 'year'] as const;

function asPeriod(value: unknown): ProgressPeriod {
  return typeof value === 'string' && (PERIODS as readonly string[]).includes(value)
    ? (value as ProgressPeriod)
    : 'month';
}
