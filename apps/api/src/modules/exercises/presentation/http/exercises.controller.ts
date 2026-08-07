import {
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
  type ExerciseDetail,
  type ExerciseSummary,
} from '@carlys/api-contracts';
import { Controller, Get, Param, Query, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { ExercisesService } from '../../application/exercises.service';
import { ListExercisesQuery } from './dto/list-exercises.query';

@ApiTags('exercises')
@ApiBearerAuth()
@Controller('exercises')
export class ExercisesController {
  constructor(private readonly exercises: ExercisesService) {}

  @Get()
  @ApiOperation({
    summary: "Catalogue d'exercices (recherche, filtres, pagination par curseur)",
  })
  async list(
    @Query() query: ListExercisesQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<ExerciseSummary[], CursorPaginationMeta>> {
    const page = await this.exercises.list(
      {
        search: query.search === '' ? undefined : query.search,
        muscleGroupSlug: query.muscleGroup,
        equipmentSlug: query.equipment,
        difficulty: query.difficulty,
        type: query.type,
      },
      query.limit,
      query.cursor,
    );

    return enveloped(page.items, { nextCursor: page.nextCursor, hasMore: page.hasMore }, request);
  }

  @Get(':idOrSlug')
  @ApiOperation({ summary: "Fiche complète d'un exercice (par id ou par slug)" })
  detail(
    @Param('idOrSlug') idOrSlug: string,
    @CurrentUser() user: AuthenticatedPrincipal,
  ): Promise<ExerciseDetail> {
    return this.exercises.detail(idOrSlug, user.userId);
  }
}
