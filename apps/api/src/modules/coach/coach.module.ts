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
import { CoachActionTurn } from './application/coach-action-turn';
import { CoachActions } from './application/coach-actions';
import { CoachTurnRunner } from './application/coach-turn.runner';
import { CoachWorkoutCreator } from './application/coach-workout-creator';
import { CoachQuota } from './application/coach.quota';
import { CoachAvailability } from './application/coach.availability';
import { CoachService } from './application/coach.service';
import { CoachTools } from './application/coach.tools';
import { COACH_MODEL_PORT, type CoachModelPort } from './domain/coach-model.port';
import { CoachCancellations } from './infrastructure/coach-cancellations';
import { CoachGate } from './infrastructure/coach-gate';
import { CoachGenerationRepository } from './infrastructure/coach-generation.repository';
import { CoachMetrics } from './infrastructure/coach-metrics';
import { CoachRepository } from './infrastructure/coach.repository';
import { MealVisionClient, VISION_TIMEOUT_MS } from './infrastructure/meal-vision.client';
import { MealScansController } from './presentation/http/meal-scans.controller';
import { MealScansService } from './application/meal-scans.service';
import { CoachWorkerLoad } from './infrastructure/coach-worker-load';
import { CoachWorkerPool } from './infrastructure/coach-worker-pool';
import { OpenAiCompatibleCoachClient } from './infrastructure/openai-compatible.client';
import { CoachController } from './presentation/http/coach.controller';
import { CoachInternalController } from './presentation/http/coach-internal.controller';

/**
 * Un seul fournisseur : NOS workers (`COACH_WORKER_URLS` ou
 * `COACH_API_BASE_URL`), par le client compatible OpenAI. Aucun repli vers un
 * prestataire : les messages ne quittent jamais le serveur (décision du
 * 3 octobre 2026, ADR 0013). Sans worker, le coach est indisponible
 * (`CoachAvailability`), il n'appelle rien.
 */
export function coachModelFor(config: AppConfigService, pool: CoachWorkerPool): CoachModelPort {
  return new OpenAiCompatibleCoachClient(config, pool);
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
  controllers: [CoachController, CoachInternalController, MealScansController],
  providers: [
    CoachAvailability,
    CoachService,
    MealScansService,
    MealVisionClient,
    CoachTools,
    CoachQuota,
    CoachRepository,
    // La passerelle et ce qui l'entoure (ADR 0013).
    CoachAdmissions,
    CoachGateway,
    CoachGate,
    CoachCancellations,
    CoachGenerationRepository,
    CoachMetrics,
    CoachContextBuilder,
    CoachTurnRunner,
    CoachMemory,
    // Les actions exigées : proposer, modifier, créer (ADR 0014).
    CoachActions,
    CoachActionTurn,
    CoachWorkoutCreator,
    CoachHealth,
    CoachWorkerLoad,
    {
      // UN pool par exemplaire de l'API : le client et l'état de santé le
      // partagent ; la charge des workers, elle, se lit sur tous (Redis).
      provide: CoachWorkerPool,
      inject: [AppConfigService, CoachWorkerLoad],
      useFactory: (config: AppConfigService, load: CoachWorkerLoad) =>
        new CoachWorkerPool(
          config.coachGateway.workerUrls,
          config.coachGateway.workerCooldownMs,
          Date.now,
          {
            load,
            // La plus longue génération (tour ou analyse de photo), plus une minute.
            leaseMs: Math.max(config.coachGateway.requestTimeoutMs, VISION_TIMEOUT_MS) + 60_000,
          },
        ),
    },
    {
      provide: COACH_MODEL_PORT,
      inject: [AppConfigService, CoachWorkerPool],
      useFactory: coachModelFor,
    },
  ],
})
export class CoachModule {}
