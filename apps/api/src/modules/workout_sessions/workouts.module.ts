import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { ProgramsModule } from '../programs/programs.module';
import { ProgressModule } from '../progress/progress.module';
import { WorkoutTemplatesModule } from '../workout_templates/workout-templates.module';
import { WorkoutSetsService } from './application/workout-sets.service';
import { WorkoutsService } from './application/workouts.service';
import { WorkoutsRepository } from './infrastructure/workouts.repository';
import { WorkoutSessionsController } from './presentation/http/workout-sessions.controller';
import { WorkoutSetsController } from './presentation/http/workout-sets.controller';

/**
 * `ProgramsModule` n'est importé que pour UNE lecture : vérifier qu'un jour
 * de programme existe et appartient bien à la personne, avant de l'inscrire
 * sur la séance. Aucun cycle — les programmes ne connaissent pas les séances.
 */
@Module({
  imports: [CommunityModule, ProgramsModule, ProgressModule, WorkoutTemplatesModule],
  controllers: [WorkoutSessionsController, WorkoutSetsController],
  providers: [WorkoutsService, WorkoutSetsService, WorkoutsRepository],
  exports: [WorkoutsService],
})
export class WorkoutsModule {}
