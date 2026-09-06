import { type CommunityChallenge } from '@carlys/api-contracts';
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
import { QuizAnswerDto } from './dto/community.dto';

/** Défis collectifs et réponses de quiz (préfixe /community, comme le reste). */
@ApiTags('community')
@ApiBearerAuth()
@Controller('community')
export class CommunityChallengesController {
  constructor(private readonly challenges: CommunityChallengesService) {}

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
}
