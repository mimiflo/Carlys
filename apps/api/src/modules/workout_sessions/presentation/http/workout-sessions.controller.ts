import {
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
  type WorkoutSessionDetail,
  type WorkoutSessionSummary,
  type WorkoutSet,
} from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { WorkoutsService } from '../../application/workouts.service';
import {
  CloseWorkoutSessionDto,
  CreateWorkoutSessionDto,
  CreateWorkoutSetDto,
  ListWorkoutSessionsQuery,
  SkipWorkoutSessionPlanItemsDto,
  UpdateWorkoutSessionDto,
} from './dto/workout.dto';

@ApiTags('workout-sessions')
@ApiBearerAuth()
@Controller('workout-sessions')
export class WorkoutSessionsController {
  constructor(private readonly workouts: WorkoutsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Créer une séance (idempotent — id généré sur l’appareil)' })
  create(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: CreateWorkoutSessionDto,
  ): Promise<WorkoutSessionDetail> {
    return this.workouts.createSession(user.userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Historique des séances (pagination par curseur)' })
  async list(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Query() query: ListWorkoutSessionsQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<WorkoutSessionSummary[], CursorPaginationMeta>> {
    const page = await this.workouts.listSessions(user.userId, query.limit, query.cursor);
    return enveloped(page.items, { nextCursor: page.nextCursor, hasMore: page.hasMore }, request);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Détail d’une séance' })
  detail(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) sessionId: string,
  ): Promise<WorkoutSessionDetail> {
    return this.workouts.sessionDetail(user.userId, sessionId);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Modifier nom/notes d’une séance' })
  update(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) sessionId: string,
    @Body() dto: UpdateWorkoutSessionDto,
  ): Promise<WorkoutSessionDetail> {
    return this.workouts.updateSession(user.userId, sessionId, dto);
  }

  @Post(':id/complete')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Terminer une séance (idempotent)' })
  complete(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) sessionId: string,
    @Body() dto: CloseWorkoutSessionDto,
  ): Promise<WorkoutSessionDetail> {
    return this.workouts.completeSession(user.userId, sessionId, dto);
  }

  @Post(':id/abandon')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Abandonner une séance (idempotent)' })
  abandon(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) sessionId: string,
    @Body() dto: CloseWorkoutSessionDto,
  ): Promise<WorkoutSessionDetail> {
    return this.workouts.abandonSession(user.userId, sessionId, dto);
  }

  @Post(':id/plan/skip')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Passer des séries prévues (idempotent)' })
  skipPlanItems(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) sessionId: string,
    @Body() dto: SkipWorkoutSessionPlanItemsDto,
  ): Promise<WorkoutSessionDetail> {
    return this.workouts.skipPlanItems(user.userId, sessionId, dto.planItemIds);
  }

  @Post(':id/sets')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Ajouter une série (upsert idempotent)' })
  addSet(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) sessionId: string,
    @Body() dto: CreateWorkoutSetDto,
  ): Promise<WorkoutSet> {
    return this.workouts.addSet(user.userId, sessionId, dto);
  }
}
