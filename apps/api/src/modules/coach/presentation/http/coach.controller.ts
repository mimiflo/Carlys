import {
  type CoachConversation,
  type CoachConversationSummary,
  type CoachReply,
} from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProduces, ApiTags } from '@nestjs/swagger';
import { type Response } from 'express';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { sseEmitter } from '../../../../common/http/sse';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { type RequestWithId } from '../../../../common/types/request-with-id';
import { enveloped } from '../../../../common/utilities/enveloped';
import { CoachService } from '../../application/coach.service';
import {
  AcceptCoachProgramProposalDto,
  AcceptCoachProposalDto,
  CreateCoachConversationDto,
  SendCoachMessageDto,
} from './dto/coach.dto';

/** Contrôleur mince : aucune logique, aucune décision. */
@ApiTags('coach')
@ApiBearerAuth()
@Controller('coach')
export class CoachController {
  constructor(private readonly coach: CoachService) {}

  @Get('conversations')
  @ApiOperation({ summary: 'Fils de discussion, du plus récemment actif au plus ancien' })
  list(@CurrentUser() user: AuthenticatedPrincipal): Promise<CoachConversationSummary[]> {
    return this.coach.listConversations(user.userId);
  }

  @Post('conversations')
  @ApiOperation({ summary: 'Ouvre un fil (identifiant fourni par l’appareil, rejouable)' })
  create(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() body: CreateCoachConversationDto,
  ): Promise<CoachConversationSummary> {
    return this.coach.createConversation(user.userId, body.id);
  }

  @Get('conversations/:id')
  @ApiOperation({ summary: 'Un fil avec ses messages et les séances proposées' })
  detail(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<CoachConversation> {
    return this.coach.conversation(user.userId, id);
  }

  @Post('conversations/:id/messages')
  @ApiOperation({
    summary: 'Envoie un message et renvoie la réponse du coach',
    description:
      'Identifiant de message fourni par l’appareil, rejouable dans SON fil : ' +
      'un message déjà répondu rend la même réponse, sans tour de quota ni ' +
      'appel au modèle. Le même identifiant avec un autre contenu → 409 ; ' +
      'un identifiant déjà porté par un autre fil, ou un fil d’autrui → 404.',
  })
  send(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: SendCoachMessageDto,
  ): Promise<CoachReply> {
    return this.coach.sendMessage(user.userId, id, body.id, body.content);
  }

  @Post('conversations/:id/messages/stream')
  @ApiProduces('text/event-stream')
  @ApiOperation({
    summary: 'Envoie un message ; la réponse du coach arrive AU FIL de son écriture',
    description:
      'Mêmes règles que la route sans flux (rejeu, 409, 404). Un refus AVANT ' +
      'le premier mot garde son statut HTTP. Ensuite, flux SSE : `delta` ' +
      '({ text }) à chaque morceau, puis `done` (enveloppe de succès, même ' +
      '`CoachReply`), ou `error` (enveloppe d’erreur). Le texte archivé est ' +
      'celui de `done`.',
  })
  async stream(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: SendCoachMessageDto,
    @Req() request: RequestWithId,
    @Res() response: Response,
  ): Promise<void> {
    const emit = sseEmitter(response);
    const reply = await this.coach.sendMessage(user.userId, id, body.id, body.content, (text) =>
      emit('delta', { text }),
    );
    emit('done', enveloped(reply, {}, request));
    response.end();
  }

  @Post('proposals/:id/accepted')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary: 'Signale qu’une proposition a été lancée',
    description:
      'N’écrit AUCUNE séance : la séance est créée par la route de séance ' +
      'existante, déjà idempotente. Cette route ne fait que noter l’acceptation.',
  })
  accept(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: AcceptCoachProposalDto,
  ): Promise<void> {
    return this.coach.acceptProposal(user.userId, id, body.sessionId);
  }

  @Post('program-proposals/:id/accepted')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary: 'Signale qu’un programme proposé a été créé',
    description:
      'N’écrit AUCUN programme : il est engendré par la route de génération ' +
      'existante. Cette route ne fait que noter l’acceptation.',
  })
  acceptProgram(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: AcceptCoachProgramProposalDto,
  ): Promise<void> {
    return this.coach.acceptProgramProposal(user.userId, id, body.programId);
  }
}
