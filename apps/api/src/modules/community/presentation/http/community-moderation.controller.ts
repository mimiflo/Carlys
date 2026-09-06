import { type BlockedUser, type CommunityReport } from '@carlys/api-contracts';
import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { CommunityModerationService } from '../../application/community-moderation.service';
import { CreateCommunityReportDto } from './dto/community-moderation.dto';

/** Ce qu'un membre peut faire pour se protéger : bloquer, retirer, signaler. */
@ApiTags('community')
@ApiBearerAuth()
@Controller('community')
export class CommunityModerationController {
  constructor(private readonly moderation: CommunityModerationService) {}

  // ── Blocages ────────────────────────────────────────────────────────────

  @Post('blocks/:userId')
  @HttpCode(204)
  @ApiOperation({
    summary:
      'Bloquer quelqu’un (idempotent). Retire l’amitié et les demandes en ' +
      'attente dans les deux sens ; l’autre n’est jamais prévenu et ne voit ' +
      'plus qu’un compte inexistant.',
  })
  block(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('userId', new ParseUUIDPipe()) targetId: string,
  ): Promise<void> {
    return this.moderation.block(user.userId, targetId);
  }

  @Delete('blocks/:userId')
  @HttpCode(204)
  @ApiOperation({ summary: 'Débloquer (idempotent) — ne rétablit ni amitié ni demande' })
  unblock(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('userId', new ParseUUIDPipe()) targetId: string,
  ): Promise<void> {
    return this.moderation.unblock(user.userId, targetId);
  }

  @Get('blocks')
  @ApiOperation({ summary: 'Personnes que j’ai bloquées' })
  blocks(@CurrentUser() user: AuthenticatedPrincipal): Promise<BlockedUser[]> {
    return this.moderation.listBlocks(user.userId);
  }

  // ── Encouragements ──────────────────────────────────────────────────────

  @Delete('encouragements/:id')
  @HttpCode(204)
  @ApiOperation({
    summary:
      'Retirer un encouragement (auteur OU destinataire). Rejouable et ' +
      'opaque : un identifiant inconnu ou étranger aboutit pareil, sans effet.',
  })
  deleteEncouragement(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<void> {
    return this.moderation.deleteEncouragement(user.userId, id);
  }

  // ── Signalements ────────────────────────────────────────────────────────

  @Post('reports')
  @HttpCode(201)
  @ApiOperation({
    summary:
      'Signaler une personne, ou un encouragement précis qu’elle m’a envoyé. ' +
      'Un signalement ouvert identique n’est pas dupliqué (même accusé de réception).',
  })
  report(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: CreateCommunityReportDto,
  ): Promise<CommunityReport> {
    return this.moderation.report(user.userId, dto);
  }
}
