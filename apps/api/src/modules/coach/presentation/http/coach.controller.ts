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
import { sseEmitter, sseKeepAlive } from '../../../../common/http/sse';
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

/**
 * Connexion fermée avant la fin (écran quitté, « Arrêter », réseau coupé) : la
 * génération s'arrête au lieu de tourner pour personne (ADR 0013).
 */
function cancelOnClose(response: Response): { signal: AbortSignal; dispose: () => void } {
  const controller = new AbortController();
  const onClose = () => {
    if (!response.writableFinished) controller.abort();
  };
  response.on('close', onClose);
  return { signal: controller.signal, dispose: () => response.off('close', onClose) };
}

/**
 * Un battement toutes les 15 s pendant qu'une réponse en flux se tait : bien
 * sous les 60 s de nginx et les 65 s d'attente du mobile.
 */
const SSE_KEEPALIVE_MS = 15_000;

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
  async send(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: SendCoachMessageDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<CoachReply> {
    const cancel = cancelOnClose(response);
    try {
      return await this.coach.sendMessage(user.userId, id, body.id, body.content, {
        signal: cancel.signal,
      });
    } finally {
      cancel.dispose();
    }
  }

  @Post('conversations/:id/messages/stream')
  @ApiProduces('text/event-stream')
  @ApiOperation({
    summary: 'Envoie un message ; la réponse du coach arrive AU FIL de son écriture',
    description:
      'Mêmes règles que la route sans flux (rejeu, 409, 404). Un refus AVANT ' +
      'le premier évènement garde son statut HTTP (429, 503 SERVICE_BUSY si la ' +
      'file est pleine). Ensuite, flux SSE : `queued` ({ ahead }, demandes ' +
      'devant, à chaque changement), `started` (son tour est venu), `delta` ' +
      '({ text }) à chaque morceau, ' +
      'puis `done` (enveloppe de succès, même `CoachReply`), ou `error` ' +
      '(enveloppe d’erreur). Fermer la connexion annule la génération. Le ' +
      'texte archivé est celui de `done`.',
  })
  async stream(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: SendCoachMessageDto,
    @Req() request: RequestWithId,
    @Res() response: Response,
  ): Promise<void> {
    const emit = sseEmitter(response);
    const stopKeepAlive = sseKeepAlive(response, SSE_KEEPALIVE_MS);
    const cancel = cancelOnClose(response);
    try {
      const reply = await this.coach.sendMessage(user.userId, id, body.id, body.content, {
        onText: (text) => emit('delta', { text }),
        onQueued: (ahead) => emit('queued', { ahead }),
        onStarted: () => emit('started', {}),
        signal: cancel.signal,
      });
      emit('done', enveloped(reply, {}, request));
      response.end();
    } finally {
      stopKeepAlive();
      cancel.dispose();
    }
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
