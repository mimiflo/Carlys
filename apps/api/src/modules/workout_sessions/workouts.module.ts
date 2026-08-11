import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { ProgressModule } from '../progress/progress.module';
import { WorkoutTemplatesModule } from '../workout_templates/workout-templates.module';
import { WorkoutsService } from './application/workouts.service';
import { WorkoutsRepository } from './infrastructure/workouts.repository';
import { WorkoutSessionsController } from './presentation/http/workout-sessions.controller';
import { WorkoutSetsController } from './presentation/http/workout-sets.controller';

@Module({
  imports: [CommunityModule, ProgressModule, WorkoutTemplatesModule],
  controllers: [WorkoutSessionsController, WorkoutSetsController],
  providers: [WorkoutsService, WorkoutsRepository],
  exports: [WorkoutsService],
})
export class WorkoutsModule {}
