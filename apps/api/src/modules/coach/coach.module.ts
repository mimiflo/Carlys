import { Module } from '@nestjs/common';
import { AppConfigService } from '../../config/app-config.service';
import { ExercisesModule } from '../exercises/exercises.module';
import { MetricsModule } from '../metrics/metrics.module';
import { NutritionModule } from '../nutrition/nutrition.module';
import { ProgramsModule } from '../programs/programs.module';
import { ProgressModule } from '../progress/progress.module';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { UsersModule } from '../users/users.module';
import { WorkoutsModule } from '../workout_sessions/workouts.module';
import { WorkoutTemplatesModule } from '../workout_templates/workout-templates.module';
import { CoachAdmissions } from './application/coach-admissions';
import { CoachContextBuilder } from './application/coach-context.builder';
import { CoachGateway } from './application/coach-gateway';
import { CoachHealth } from './application/coach-health';
import { CoachMemory } from './application/coach-memory';
import { CoachTurnRunner } from './application/coach-turn.runner';
import { CoachQuota } from './application/coach.quota';
import { CoachAvailability } from './application/coach.availability';
import { CoachService } from './application/coach.service';
import { CoachTools } from './application/coach.tools';
import { COACH_MODEL_PORT, type CoachModelPort } from './domain/coach-model.port';
import { ANTHROPIC_DEFAULT_MODEL, AnthropicCoachClient } from './infrastructure/anthropic.client';
import { CoachGate } from './infrastructure/coach-gate';
import { CoachGenerationRepository } from './infrastructure/coach-generation.repository';
import { CoachMetrics } from './infrastructure/coach-metrics';
import { CoachRepository } from './infrastructure/coach.repository';
import { CoachWorkerPool } from './infrastructure/coach-worker-pool';
import { FallbackCoachModel } from './infrastructure/fallback-coach-model';
import { OpenAiCompatibleCoachClient } from './infrastructure/openai-compatible.client';
import { CoachController } from './presentation/http/coach.controller';
import { CoachInternalController } from './presentation/http/coach-internal.controller';

/**
 * Le fournisseur est un RÉGLAGE, pas du code : un worker au moins
 * (`COACH_WORKER_URLS` ou `COACH_API_BASE_URL`), nos Ollama par le client
 * compatible OpenAI ; aucun, Anthropic. Le repli cloud n'existe que si on
 * l'allume ET qu'une clé est posée (ADR 0010, 0013).
 */
export function coachModelFor(config: AppConfigService, pool: CoachWorkerPool): CoachModelPort {
  if (pool.size === 0) {
    return new AnthropicCoachClient(config);
  }
  const local = new OpenAiCompatibleCoachClient(config, pool);
  return config.coachGateway.cloudFallback && config.anthropicApiKey !== undefined
    ? new FallbackCoachModel(local, new AnthropicCoachClient(config, ANTHROPIC_DEFAULT_MODEL))
    : local;
}

/**
 * Coach IA — l'IA propose, l'application exécute.
 *
 * Le module importe les domaines voisins pour leurs SERVICES : le coach lit
 * les séances, les modèles, les records et les cibles par la même porte que
 * les écrans, jamais par un accès Prisma privilégié.
 *
 * Le fournisseur de modèle n'est branché qu'ici, derrière `COACH_MODEL_PORT` :
 * les tests substituent un faux et ne sortent jamais sur le réseau.
 */
@Module({
  imports: [
    ExercisesModule,
    WorkoutTemplatesModule,
    WorkoutsModule,
    ProgressModule,
    NutritionModule,
    ProgramsModule,
    SubscriptionsModule,
    UsersModule,
    MetricsModule,
  ],
  controllers: [CoachController, CoachInternalController],
  providers: [
    CoachAvailability,
    CoachService,
    CoachTools,
    CoachQuota,
    CoachRepository,
    // La passerelle et ce qui l'entoure (ADR 0013).
    CoachAdmissions,
    CoachGateway,
    CoachGate,
    CoachGenerationRepository,
    CoachMetrics,
    CoachContextBuilder,
    CoachTurnRunner,
    CoachMemory,
    CoachHealth,
    {
      // UN pool par exemplaire de l'API : le client et l'état de santé le partagent.
      provide: CoachWorkerPool,
      inject: [AppConfigService],
      useFactory: (config: AppConfigService) =>
        new CoachWorkerPool(config.coachGateway.workerUrls, config.coachGateway.workerCooldownMs),
    },
    {
      provide: COACH_MODEL_PORT,
      inject: [AppConfigService, CoachWorkerPool],
      useFactory: coachModelFor,
    },
  ],
})
export class CoachModule {}
