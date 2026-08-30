import {
  type CommunityChallenge,
  type CommunityFriend,
  type CommunityProfile,
  type Encouragement,
  type FriendCodePreview,
  type FriendRequest,
} from '@carlys/api-contracts';
import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { CommunityService } from '../../application/community.service';
import {
  EncourageDto,
  FriendRequestDto,
  QuizAnswerDto,
  UpdateCommunityProfileDto,
} from './dto/community.dto';

@ApiTags('community')
@ApiBearerAuth()
@Controller('community')
export class CommunityController {
  constructor(private readonly community: CommunityService) {}

  // ── Fil ─────────────────────────────────────────────────────────────────

  @Get('feed')
  @ApiOperation({ summary: 'Encouragements reçus, du plus récent au plus ancien' })
  feed(@CurrentUser() user: AuthenticatedPrincipal): Promise<Encouragement[]> {
    return this.community.feed(user.userId);
  }

  @Post('encouragements')
  @HttpCode(201)
  @ApiOperation({ summary: 'Encourager un ami (amitié acceptée obligatoire)' })
  async encourage(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: EncourageDto,
  ): Promise<void> {
    await this.community.encourage(user.userId, dto.recipientUserId, dto.message);
  }

  // ── Amis ────────────────────────────────────────────────────────────────

  @Get('friends')
  @ApiOperation({
    summary: 'Amis acceptés — la progression n’apparaît que si elle est partagée',
  })
  friends(@CurrentUser() user: AuthenticatedPrincipal): Promise<CommunityFriend[]> {
    return this.community.listFriends(user.userId);
  }

  @Delete('friends/:userId')
  @HttpCode(204)
  @ApiOperation({ summary: 'Retirer un ami (idempotent)' })
  removeFriend(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('userId', new ParseUUIDPipe()) friendUserId: string,
  ): Promise<void> {
    return this.community.removeFriend(user.userId, friendUserId);
  }

  @Get('requests')
  @ApiOperation({ summary: 'Demandes d’ami REÇUES en attente' })
  requests(@CurrentUser() user: AuthenticatedPrincipal): Promise<FriendRequest[]> {
    return this.community.listReceivedRequests(user.userId);
  }

  @Post('requests')
  @HttpCode(202)
  @ApiOperation({
    summary:
      'Demander un ami par e-mail exact OU par code ami (tapé ou scanné). ' +
      'Réponse opaque : 202 dans tous les cas, qu’un compte existe ou non ' +
      '(pas d’énumération d’adresses).',
  })
  async request(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: FriendRequestDto,
  ): Promise<void> {
    if ((dto.email === undefined) === (dto.friendCode === undefined)) {
      throw new BadRequestException('Fournir email OU friendCode, exactement un des deux.');
    }
    if (dto.friendCode !== undefined) {
      await this.community.requestFriendByCode(user.userId, dto.friendCode);
      return;
    }
    await this.community.requestFriend(user.userId, dto.email as string);
  }

  @Get('friend-codes/:code')
  @ApiOperation({
    summary:
      'Résoudre un code ami vers son porteur — juste le nom, pour confirmer ' +
      'avant d’envoyer la demande. 404 si aucun compte actif ne le porte.',
  })
  lookupFriendCode(@Param('code') code: string): Promise<FriendCodePreview> {
    return this.community.lookupFriendCode(code);
  }

  @Post('requests/:id/accept')
  @HttpCode(204)
  @ApiOperation({ summary: 'Accepter une demande reçue' })
  async accept(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<void> {
    await this.community.respondToRequest(user.userId, id, true);
  }

  @Post('requests/:id/decline')
  @HttpCode(204)
  @ApiOperation({ summary: 'Refuser une demande reçue' })
  async decline(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<void> {
    await this.community.respondToRequest(user.userId, id, false);
  }

  // ── Défis collectifs ────────────────────────────────────────────────────

  @Get('challenges')
  @ApiOperation({ summary: 'Défis ouverts, progression collective incluse' })
  challenges(@CurrentUser() user: AuthenticatedPrincipal): Promise<CommunityChallenge[]> {
    return this.community.listChallenges(user.userId);
  }

  @Post('challenges/:id/join')
  @ApiOperation({ summary: 'Rejoindre un défi (idempotent)' })
  join(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<CommunityChallenge> {
    return this.community.joinChallenge(user.userId, id);
  }

  @Delete('challenges/:id/join')
  @ApiOperation({ summary: 'Quitter un défi (idempotent)' })
  leave(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<CommunityChallenge> {
    return this.community.leaveChallenge(user.userId, id);
  }

  @Post('quiz-answers')
  @HttpCode(204)
  @ApiOperation({
    summary:
      'Réponse à un quiz de l’Academy. Idempotent par (leçon, jour local) ; ' +
      'une première réponse juste contribue aux défis CULTURE rejoints.',
  })
  async quizAnswer(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: QuizAnswerDto,
  ): Promise<void> {
    await this.community.recordQuizAnswer(user.userId, dto);
  }

  // ── Préférence de partage ───────────────────────────────────────────────

  @Get('profile')
  @ApiOperation({ summary: 'Ma préférence communautaire' })
  profile(@CurrentUser() user: AuthenticatedPrincipal): Promise<CommunityProfile> {
    return this.community.profile(user.userId);
  }

  @Patch('profile')
  @ApiOperation({ summary: 'Partager (ou non) ma progression avec mes amis' })
  updateProfile(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: UpdateCommunityProfileDto,
  ): Promise<CommunityProfile> {
    return this.community.updateProfile(user.userId, dto.sharesProgress);
  }
}
