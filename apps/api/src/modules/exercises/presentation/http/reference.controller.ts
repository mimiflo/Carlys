import { type Equipment, type MuscleGroup } from '@carlys/api-contracts';
import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ExercisesService } from '../../application/exercises.service';

/** Référentiels du catalogue (mis en cache côté serveur). */
@ApiTags('exercises')
@ApiBearerAuth()
@Controller()
export class ReferenceController {
  constructor(private readonly exercises: ExercisesService) {}

  @Get('muscle-groups')
  @ApiOperation({ summary: 'Groupes musculaires (ordonnés)' })
  muscleGroups(): Promise<MuscleGroup[]> {
    return this.exercises.muscleGroups();
  }

  @Get('equipment')
  @ApiOperation({ summary: 'Équipements' })
  equipment(): Promise<Equipment[]> {
    return this.exercises.equipment();
  }
}
