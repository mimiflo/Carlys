import { Module } from '@nestjs/common';
import { ExercisesModule } from '../exercises/exercises.module';
import { NutritionModule } from '../nutrition/nutrition.module';
import { ProgressModule } from '../progress/progress.module';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { WorkoutsModule } from '../workout_sessions/workouts.module';
import { WorkoutTemplatesModule } from '../workout_templates/workout-templates.module';
import { CoachQuota } from './application/coach.quota';
import { CoachService } from './application/coach.service';
import { CoachTools } from './application/coach.tools';
import { COACH_MODEL_PORT } from './domain/coach-model.port';
import { AnthropicCoachClient } from './infrastructure/anthropic.client';
import { CoachRepository } from './infrastructure/coach.repository';
import { CoachController } from './presentation/http/coach.controller';

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
    SubscriptionsModule,
  ],
  controllers: [CoachController],
  providers: [
    CoachService,
    CoachTools,
    CoachQuota,
    CoachRepository,
    { provide: COACH_MODEL_PORT, useClass: AnthropicCoachClient },
  ],
})
export class CoachModule {}
