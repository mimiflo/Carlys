import { Module } from '@nestjs/common';
import { AppConfigService } from '../../config/app-config.service';
import { ExercisesModule } from '../exercises/exercises.module';
import { NutritionModule } from '../nutrition/nutrition.module';
import { ProgramsModule } from '../programs/programs.module';
import { ProgressModule } from '../progress/progress.module';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { UsersModule } from '../users/users.module';
import { WorkoutsModule } from '../workout_sessions/workouts.module';
import { WorkoutTemplatesModule } from '../workout_templates/workout-templates.module';
import { CoachQuota } from './application/coach.quota';
import { CoachAvailability } from './application/coach.availability';
import { CoachService } from './application/coach.service';
import { CoachTools } from './application/coach.tools';
import { COACH_MODEL_PORT, type CoachModelPort } from './domain/coach-model.port';
import { AnthropicCoachClient } from './infrastructure/anthropic.client';
import { CoachRepository } from './infrastructure/coach.repository';
import { OpenAiCompatibleCoachClient } from './infrastructure/openai-compatible.client';
import { CoachController } from './presentation/http/coach.controller';

/**
 * Le fournisseur est un RÉGLAGE, pas du code : `COACH_API_BASE_URL` posée,
 * le client compatible OpenAI (Mistral, Ollama, Cloudflare) ; absente,
 * Anthropic. Voir docs/decisions/0010-coach-fournisseur-compatible-openai.md.
 */
export function coachModelFor(config: AppConfigService): CoachModelPort {
  return config.coachProvider.baseUrl === undefined
    ? new AnthropicCoachClient(config)
    : new OpenAiCompatibleCoachClient(config);
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
  ],
  controllers: [CoachController],
  providers: [
    CoachAvailability,
    CoachService,
    CoachTools,
    CoachQuota,
    CoachRepository,
    { provide: COACH_MODEL_PORT, inject: [AppConfigService], useFactory: coachModelFor },
  ],
})
export class CoachModule {}
