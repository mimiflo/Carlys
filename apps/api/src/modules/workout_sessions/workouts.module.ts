import { Module } from '@nestjs/common';
import { ProgressModule } from '../progress/progress.module';
import { WorkoutsService } from './application/workouts.service';
import { WorkoutsRepository } from './infrastructure/workouts.repository';
import { WorkoutSessionsController } from './presentation/http/workout-sessions.controller';
import { WorkoutSetsController } from './presentation/http/workout-sets.controller';

@Module({
  imports: [ProgressModule],
  controllers: [WorkoutSessionsController, WorkoutSetsController],
  providers: [WorkoutsService, WorkoutsRepository],
  exports: [WorkoutsService],
})
export class WorkoutsModule {}
