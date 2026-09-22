import {
  type ApiSuccessEnvelope,
  type CursorPaginationMeta,
  type GeneratedProgram,
  type ProgramCalendarWeek,
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
import { ProgramCalendarService } from '../../application/program-calendar.service';
import { ProgramGenerationService } from '../../application/program-generation.service';
import { ProgramsService } from '../../application/programs.service';
import { GenerateProgramDto } from './dto/generate-program.dto';
import {
  CalendarWeekQuery,
  LinkCalendarSessionDto,
  ListProgramsQuery,
  SaveProgramDto,
} from './dto/program.dto';

@ApiTags('programs')
@ApiBearerAuth()
@Controller('programs')
export class ProgramsController {
  constructor(
    private readonly programs: ProgramsService,
    private readonly generation: ProgramGenerationService,
    private readonly calendar: ProgramCalendarService,
  ) {}

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

  @Get(':id/calendar')
  @ApiOperation({
    summary: 'Une semaine DATÉE du programme',
    description:
      'Les sept jours de la semaine, avec leur date civile et leur état — ' +
      'fait, manqué, hors période, à venir, repos ou libre. Rien n’est ' +
      'stocké : « fait » découle du lien séance → jour, « manqué » de la ' +
      'date dans le fuseau de la personne. Sans semaine demandée, celle qui ' +
      'contient aujourd’hui.',
  })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Inconnu, supprimé, ou à autrui' })
  @ApiResponse({
    status: HttpStatus.BAD_REQUEST,
    description: 'Programme sans date de début, ou semaine hors du plan',
  })
  calendarWeek(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Query() query: CalendarWeekQuery,
  ): Promise<ProgramCalendarWeek> {
    return this.calendar.week(id, user.userId, query.week);
  }

  @Put(':id/calendar/days/:dayId/session')
  @ApiOperation({
    summary: 'La case reconnaît une séance, ou n’en reconnaît plus aucune',
    description:
      'Répare le cas de la séance faite HORS calendrier : elle ne portait ' +
      'l’identifiant d’aucune case, et la case restait rouge. Le JOUR CIVIL ' +
      'décide — une séance n’honore une case que si elle a eu lieu ce ' +
      'jour-là dans le fuseau de la personne. `null` détache. Rend la ' +
      'semaine entière, réaffichable telle quelle.',
  })
  @ApiResponse({ status: HttpStatus.OK, description: 'Semaine mise à jour' })
  @ApiResponse({ status: HttpStatus.NOT_FOUND, description: 'Case ou séance introuvable' })
  @ApiResponse({
    status: HttpStatus.BAD_REQUEST,
    description: 'Jour de repos, programme sans date de début, ou séance d’un autre jour',
  })
  linkCalendarSession(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Param('dayId', new ParseUUIDPipe()) dayId: string,
    @Body() dto: LinkCalendarSessionDto,
  ): Promise<ProgramCalendarWeek> {
    return this.calendar.linkSession(id, dayId, user.userId, dto.sessionId);
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

  @Put(':id/generate')
  @ApiOperation({
    summary: 'Engendre un programme depuis le profil d’entraînement',
    description:
      'Compose le plan à partir de l’objectif, du niveau, du rythme, de la ' +
      'durée de séance et du matériel déjà enregistrés. Le programme naît ' +
      'INACTIF : générer ne désactive jamais le plan en cours. Rejouer le ' +
      'même identifiant rend le programme tel quel, sans régénérer — pour en ' +
      'obtenir un autre, envoyer un nouvel identifiant.',
  })
  @ApiResponse({ status: HttpStatus.CREATED, description: 'Programme engendré' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Déjà engendré : rendu tel quel' })
  @ApiResponse({ status: HttpStatus.BAD_REQUEST, description: 'Profil d’entraînement incomplet' })
  @ApiResponse({ status: HttpStatus.FORBIDDEN, description: 'Plafond du plan gratuit atteint' })
  @ApiResponse({
    status: HttpStatus.CONFLICT,
    description: 'Identifiant pris, ou objectif impossible avec ce matériel',
  })
  async generate(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: GenerateProgramDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<GeneratedProgram> {
    const generated = await this.generation.generate(user.userId, id, dto);
    response.status(generated.created ? HttpStatus.CREATED : HttpStatus.OK);
    return generated.result;
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
