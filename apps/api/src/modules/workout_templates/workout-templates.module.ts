import { Module } from '@nestjs/common';
import { WorkoutTemplatesService } from './application/workout-templates.service';
import { WorkoutTemplatesRepository } from './infrastructure/workout-templates.repository';
import { WorkoutTemplatesController } from './presentation/http/workout-templates.controller';

/**
 * Modèles de séance — la source de PRESCRIPTION. Exporte son service pour que
 * le module des séances résolve la provenance d'une séance lancée.
 */
@Module({
  controllers: [WorkoutTemplatesController],
  providers: [WorkoutTemplatesService, WorkoutTemplatesRepository],
  exports: [WorkoutTemplatesService],
})
export class WorkoutTemplatesModule {}
