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
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { CoachService } from '../../application/coach.service';
import {
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
}
