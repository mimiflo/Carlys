import { type WorkoutSet } from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Delete,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { WorkoutsService } from '../../application/workouts.service';
import { UpdateWorkoutSetDto } from './dto/workout.dto';

@ApiTags('workout-sessions')
@ApiBearerAuth()
@Controller('workout-sets')
export class WorkoutSetsController {
  constructor(private readonly workouts: WorkoutsService) {}

  @Patch(':id')
  @ApiOperation({ summary: 'Corriger une série' })
  update(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) setId: string,
    @Body() dto: UpdateWorkoutSetDto,
  ): Promise<WorkoutSet> {
    return this.workouts.updateSet(user.userId, setId, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Supprimer une série (suppression logique, idempotent)' })
  async remove(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) setId: string,
  ): Promise<void> {
    await this.workouts.deleteSet(user.userId, setId);
  }
}
