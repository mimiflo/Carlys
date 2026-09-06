import {
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
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../../../common/decorators/current-user.decorator';
import { type AuthenticatedPrincipal } from '../../../../common/types/authenticated-request';
import { CommunityService } from '../../application/community.service';
import { EncourageDto, FriendRequestDto, UpdateCommunityProfileDto } from './dto/community.dto';

/**
 * Limite dédiée aux demandes d'ami, calquée sur celle des routes
 * d'authentification : connaître une adresse ou un code ami ne doit pas
 * permettre de rejouer la demande à volonté.
 */
const FRIEND_REQUEST_THROTTLE = { default: { limit: 10, ttl: 60_000 } };

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
  @Throttle(FRIEND_REQUEST_THROTTLE)
  @ApiOperation({
    summary:
      'Demander un ami par e-mail exact OU par code ami (tapé ou scanné). ' +
      'Réponse opaque : 202 dans tous les cas, qu’un compte existe ou non ' +
      '(pas d’énumération d’adresses). Un refus est opposable 30 jours. ' +
      'Limite dédiée : 10 demandes par minute et par adresse (429 au-delà).',
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
