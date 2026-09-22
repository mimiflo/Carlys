import {
  type ExerciseProgression,
  type LifetimeStats,
  type ProgressTimeline,
  type PersonalRecord,
  type ProgressOverview,
} from '@carlys/api-contracts';
import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { ProgressService } from '../../application/progress.service';
import { TimelineService } from '../../application/timeline.service';
import { ImportMilestonesDto, OverviewQuery, TimelineQuery } from './dto/progress.dto';

@ApiTags('progress')
@ApiBearerAuth()
@Controller('progress')
export class ProgressController {
  constructor(
    private readonly progress: ProgressService,
    private readonly timelines: TimelineService,
  ) {}

  @Get('overview')
  @ApiOperation({ summary: 'Statistiques par période (semaine, mois, année)' })
  overview(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Query() query: OverviewQuery,
  ): Promise<ProgressOverview> {
    return this.progress.overview(user.userId, query.period);
  }

  @Get('lifetime')
  @ApiOperation({
    summary: 'Ce que la VIE ENTIÈRE compte, pour les récompenses',
    description:
      'Des FAITS (séances terminées, semaines actives et leur compte), ' +
      'jamais une règle : le moteur de récompenses du mobile reste seul à ' +
      'décider ce qu’est une meilleure série ou une semaine équilibrée. ' +
      'Sans cette lecture, un téléphone neuf ne voyait que les 60 dernières ' +
      'séances rapatriées et une récompense gagnée disparaissait.',
  })
  lifetime(@CurrentUser() user: AuthenticatedPrincipal): Promise<LifetimeStats> {
    return this.progress.lifetime(user.userId);
  }

  @Get('timeline')
  @ApiOperation({
    summary: 'La frise : ce qui s’est passé, dans l’ordre',
    description:
      'Quatre sources fusionnées — séances, mesures, leçons groupées par ' +
      'jour, et franchissements. Le curseur encode le couple (date, id) : ' +
      'un flux fusionné a des ex æquo, et un curseur sur l’id seul ' +
      'sauterait des lignes. Les en-têtes de mois se posent côté client.',
  })
  timeline(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Query() query: TimelineQuery,
  ): Promise<ProgressTimeline> {
    return this.timelines.timeline(user.userId, query);
  }

  @Post('milestones')
  @HttpCode(204)
  @ApiOperation({
    summary: 'Reprendre le journal de récompenses d’un appareil',
    description:
      'La plus ANCIENNE date gagne : le journal local date une récompense ' +
      'du jour où l’application a regardé, et deux appareils n’ont pas ' +
      'regardé le même jour. Le serveur COMBLE les trous, il ne réécrit ' +
      'jamais. Les records ne s’importent pas — ils se dérivent des séries.',
  })
  async importMilestones(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: ImportMilestonesDto,
  ): Promise<void> {
    await this.timelines.importMilestones(user.userId, dto.milestones);
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
