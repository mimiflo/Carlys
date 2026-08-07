import {
  type ExerciseProgression,
  type PersonalRecord,
  type ProgressOverview,
} from '@carlys/api-contracts';
import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { ProgressService } from '../../application/progress.service';
import { OverviewQuery } from './dto/progress.dto';

@ApiTags('progress')
@ApiBearerAuth()
@Controller('progress')
export class ProgressController {
  constructor(private readonly progress: ProgressService) {}

  @Get('overview')
  @ApiOperation({ summary: 'Statistiques par période (semaine, mois, année)' })
  overview(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Query() query: OverviewQuery,
  ): Promise<ProgressOverview> {
    return this.progress.overview(user.userId, query.period);
  }

  @Get('records')
  @ApiOperation({ summary: 'Records personnels' })
  records(@CurrentUser() user: AuthenticatedPrincipal): Promise<PersonalRecord[]> {
    return this.progress.records(user.userId);
  }

  @Get('exercises/:exerciseId')
  @ApiOperation({ summary: 'Progression sur un exercice du catalogue' })
  exercise(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('exerciseId', new ParseUUIDPipe()) exerciseId: string,
  ): Promise<ExerciseProgression> {
    return this.progress.exerciseProgression(user.userId, exerciseId);
  }
}
