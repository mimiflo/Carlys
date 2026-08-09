import {
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
  type ProgramDetail,
  type ProgramSummary,
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
import { ProgramsService } from '../../application/programs.service';
import { ListProgramsQuery, SaveProgramDto } from './dto/program.dto';

@ApiTags('programs')
@ApiBearerAuth()
@Controller('programs')
export class ProgramsController {
  constructor(private readonly programs: ProgramsService) {}

  @Get()
  @ApiOperation({ summary: 'Mes programmes (pagination par curseur)' })
  async list(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Query() query: ListProgramsQuery,
    @Req() request: RequestWithId,
  ): Promise<ApiSuccessEnvelope<ProgramSummary[], CursorPaginationMeta>> {
    const page = await this.programs.list(user.userId, query.limit, query.cursor);
    return enveloped(page.items, { nextCursor: page.nextCursor, hasMore: page.hasMore }, request);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Détail d’un programme (jours ordonnés)' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Inconnu, supprimé, ou à autrui' })
  detail(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<ProgramDetail> {
    return this.programs.detail(id, user.userId);
  }

  @Put(':id')
  @ApiOperation({
    summary: 'Créer ou remplacer un programme (écriture unique, idempotente)',
    description:
      'Le corps décrit l’état COMPLET du programme. 201 à la création, 200 au ' +
      'remplacement ; rejouer le même corps redonne le même état. Le plafond ' +
      'du plan gratuit ne s’applique qu’à la création.',
  })
  @ApiResponse({ status: HttpStatus.CREATED, description: 'Programme créé' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Programme remplacé' })
  @ApiResponse({ status: HttpStatus.FORBIDDEN, description: 'Plafond du plan gratuit atteint' })
  @ApiResponse({ status: HttpStatus.CONFLICT, description: 'Identifiant pris par un autre compte' })
  async save(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: SaveProgramDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<ProgramDetail> {
    const saved = await this.programs.save(id, user.userId, dto);
    response.status(saved.created ? HttpStatus.CREATED : HttpStatus.OK);
    return saved.program;
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Supprimer un programme (suppression logique, rejouable)' })
  @ApiResponse({ status: HttpStatus.NO_CONTENT, description: 'Supprimé, ou déjà supprimé' })
  async remove(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<void> {
    await this.programs.remove(id, user.userId);
  }
}
