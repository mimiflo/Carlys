import {
  type CommunityChallenge,
  type FriendChallenge,
  type QuizAnswerRecord,
} from '@carlys/api-contracts';
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
import { CommunityChallengesService } from '../../application/community-challenges.service';
import { FriendChallengesService } from '../../application/friend-challenges.service';
import { CreateFriendChallengeDto, QuizAnswerDto } from './dto/community.dto';

/** Défis collectifs et réponses de quiz (préfixe /community, comme le reste). */
@ApiTags('community')
@ApiBearerAuth()
@Controller('community')
export class CommunityChallengesController {
  constructor(
    private readonly challenges: CommunityChallengesService,
    private readonly friendChallenges: FriendChallengesService,
  ) {}

  // ── Défis ENTRE AMIS ────────────────────────────────────────────────────

  @Get('friend-challenges')
  @ApiOperation({
    summary: 'Mes défis entre amis — proposés et acceptés',
    description:
      'Les défis refusés et quittés en sortent : ce sont des décisions ' +
      'prises, et une invitation dont le créateur est séparé de moi par un ' +
      'blocage aussi. Un défi échu est RÉGLÉ à la lecture (classement ' +
      'figé), sans tâche planifiée.',
  })
  listFriendChallenges(@CurrentUser() user: AuthenticatedPrincipal): Promise<FriendChallenge[]> {
    return this.friendChallenges.list(user.userId);
  }

  @Post('friend-challenges')
  @HttpCode(201)
  @ApiOperation({
    summary: 'Défier ses amis (id appareil, création idempotente)',
    description:
      'On n’invite que des amis acceptés et non bloqués — 403 sans dire ' +
      'lequel des deux. La fin du défi est CALCULÉE depuis la durée. Le ' +
      '`title` (80) et le `message` facultatif (280) se comptent en points de ' +
      'code après découpage (`message` blanc = absent). Le message ' +
      'est rendu avec `createdAt`, son heure ; il ne part jamais dans la ' +
      'notification, et un rejeu ne le réécrit pas.',
  })
  createFriendChallenge(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Body() dto: CreateFriendChallengeDto,
  ): Promise<FriendChallenge> {
    return this.friendChallenges.create(user.userId, {
      ...dto,
      target: dto.target ?? null,
      durationDays: dto.durationDays as 3 | 7 | 30,
    });
  }

  @Get('friend-challenges/:id')
  @ApiOperation({
    summary: 'Un défi et son classement',
    description:
      'Même forme que la liste et l’acceptation : `message` (ou null), ' +
      '`createdAt` (ISO UTC, l’heure du message), `durationDays`, et ' +
      '`isCreator` sur chaque membre. 404 pour qui n’en est pas membre, et ' +
      'pour une INVITATION dont le créateur est séparé du lecteur par un ' +
      'blocage (même message). Sur un défi déjà accepté, `message` vaut null ' +
      'quand un blocage, dans un sens ou l’autre, sépare le lecteur du ' +
      'créateur : le défi reste lisible, son mot est masqué.',
  })
  friendChallenge(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<FriendChallenge> {
    return this.friendChallenges.detail(user.userId, id);
  }

  @Post('friend-challenges/:id/accept')
  @ApiOperation({
    summary: 'Accepter un défi : on entre au classement, à zéro',
    description: '404 « Défi introuvable. » pour une invitation masquée par un blocage.',
  })
  acceptFriendChallenge(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<FriendChallenge> {
    return this.friendChallenges.accept(user.userId, id);
  }

  @Delete('friend-challenges/:id/join')
  @HttpCode(204)
  @ApiOperation({
    summary: 'Refuser, ou quitter — dans les deux cas, on sort du classement',
    description:
      'Contrairement à un défi collectif, dont la contribution reste acquise ' +
      'au groupe : ici le classement est individuel. 404 pour une invitation ' +
      'masquée par un blocage, comme à la lecture.',
  })
  async declineFriendChallenge(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<void> {
    await this.friendChallenges.decline(user.userId, id);
  }

  // ── Défis COLLECTIFS ────────────────────────────────────────────────────

  @Get('challenges')
  @ApiOperation({ summary: 'Défis ouverts, progression collective incluse' })
  list(@CurrentUser() user: AuthenticatedPrincipal): Promise<CommunityChallenge[]> {
    return this.challenges.listChallenges(user.userId);
  }

  @Post('challenges/:id/join')
  @ApiOperation({ summary: 'Rejoindre un défi (idempotent)' })
  join(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<CommunityChallenge> {
    return this.challenges.joinChallenge(user.userId, id);
  }

  @Delete('challenges/:id/join')
  @ApiOperation({ summary: 'Quitter un défi (idempotent)' })
  leave(
    @CurrentUser() user: AuthenticatedPrincipal,
    @Param('id', new ParseUUIDPipe()) id: string,
  ): Promise<CommunityChallenge> {
    return this.challenges.leaveChallenge(user.userId, id);
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
    await this.challenges.recordQuizAnswer(user.userId, dto);
  }

  @Get('quiz-answers')
  @ApiOperation({
    summary:
      'Les leçons déjà répondues, une entrée par leçon (la PREMIÈRE réponse ' +
      'fait foi, comme sur l’appareil). Sert à reconstruire la progression ' +
      'de l’Academy sur un nouvel appareil.',
  })
  listQuizAnswers(@CurrentUser() user: AuthenticatedPrincipal): Promise<QuizAnswerRecord[]> {
    return this.challenges.listQuizAnswers(user.userId);
  }
}
