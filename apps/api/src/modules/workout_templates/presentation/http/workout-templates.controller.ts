import {
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
  type WorkoutTemplateDetail,
  type WorkoutTemplateSummary,
} from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Put,
  Query,
  Req,
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Response } from 'express';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { WorkoutTemplatesService } from '../../application/workout-templates.service';
import { ListWorkoutTemplatesQuery, SaveWorkoutTemplateDto } from './dto/workout-template.dto';

@ApiTags('workout-templates')
@ApiBearerAuth()
@Controller('workout-templates')
export class WorkoutTemplatesController {
  constructor(private readonly templates: WorkoutTemplatesService) {}

  @Get()
  @ApiOperation({ summary: 'Mes modèles de séance (pagination par curseur)' })
  async list(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Query() query: ListWorkoutTemplatesQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<WorkoutTemplateSummary[], CursorPaginationMeta>> {
    const page = await this.templates.listTemplates(user.userId, query.limit, query.cursor);
    return enveloped(page.items, { nextCursor: page.nextCursor, hasMore: page.hasMore }, request);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Détail d’un modèle (exercices et séries prévues ordonnés)' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Inconnu, supprimé, ou à autrui' })
  detail(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) templateId: string,
  ): Promise<WorkoutTemplateDetail> {
    return this.templates.templateDetail(user.userId, templateId);
  }

  @Put(':id')
  @ApiOperation({
    summary: 'Créer ou remplacer un modèle (écriture unique, naturellement idempotente)',
    description:
      'Le corps décrit l’état COMPLET du modèle. Les positions ne sont pas ' +
      'transmises : l’ordre des tableaux fait foi. 201 à la création, 200 au ' +
      'remplacement ; rejouer le même corps redonne le même état.',
  })
  @ApiResponse({ status: HttpStatus.CREATED, description: 'Modèle créé' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Modèle remplacé' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Modèle supprimé — non ressuscitable' })
  @ApiResponse({ status: HttpStatus.CONFLICT, description: 'Identifiant pris par un autre compte' })
  async save(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) templateId: string,
    @Body() dto: SaveWorkoutTemplateDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<WorkoutTemplateDetail> {
    const saved = await this.templates.saveTemplate(user.userId, templateId, dto);
    response.status(saved.created ? HttpStatus.CREATED : HttpStatus.OK);
    return saved.template;
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Supprimer un modèle (suppression logique, rejouable)' })
  @ApiResponse({ status: HttpStatus.NO_CONTENT, description: 'Supprimé, ou déjà supprimé' })
  async remove(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) templateId: string,
  ): Promise<void> {
    await this.templates.deleteTemplate(user.userId, templateId);
  }
}
