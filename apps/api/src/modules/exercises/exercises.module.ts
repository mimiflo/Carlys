import { Module } from '@nestjs/common';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { ExercisesService } from './application/exercises.service';
import { ExercisesRepository } from './infrastructure/exercises.repository';
import { ExercisesController } from './presentation/http/exercises.controller';
import { ReferenceController } from './presentation/http/reference.controller';

@Module({
  imports: [SubscriptionsModule],
  controllers: [ExercisesController, ReferenceController],
  providers: [ExercisesService, ExercisesRepository],
  exports: [ExercisesService],
})
export class ExercisesModule {}
