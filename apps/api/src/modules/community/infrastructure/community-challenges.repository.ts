import { Injectable } from '@nestjs/common';
import { type ChallengeParticipation, type CommunityChallenge, Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export interface ChallengeWithStats extends CommunityChallenge {
  participations: Pick<ChallengeParticipation, 'userId' | 'contribution'>[];
}

/** Défis collectifs et réponses de quiz (la source des défis CULTURE). */
@Injectable()
export class CommunityChallengesRepository {
  constructor(private readonly prisma: PrismaService) {}

  // ── Défis collectifs ────────────────────────────────────────────────────

  /** Défis dont la fenêtre n'est pas terminée, avec toutes les contributions. */
  listOpenChallenges(now: Date): Promise<ChallengeWithStats[]> {
    return this.prisma.communityChallenge.findMany({
      where: { endsAt: { gte: now } },
      orderBy: { endsAt: 'asc' },
      include: { participations: { select: { userId: true, contribution: true } } },
    });
  }

  findChallengeById(id: string): Promise<CommunityChallenge | null> {
    return this.prisma.communityChallenge.findUnique({ where: { id } });
  }

  /** Rejoindre est idempotent : rejouer la requête ne crée pas de doublon. */
  async joinChallenge(challengeId: string, userId: string): Promise<void> {
    await this.prisma.challengeParticipation.upsert({
      where: { challengeId_userId: { challengeId, userId } },
      create: { challengeId, userId },
      update: {},
    });
  }

  async leaveChallenge(challengeId: string, userId: string): Promise<void> {
    await this.prisma.challengeParticipation.deleteMany({
      where: { challengeId, userId },
    });
  }

  challengeStats(challengeId: string): Promise<ChallengeWithStats | null> {
    return this.prisma.communityChallenge.findUnique({
      where: { id: challengeId },
      include: { participations: { select: { userId: true, contribution: true } } },
    });
  }

  /** +1 sur tous les défis SPORT rejoints dont la fenêtre couvre `at`. */
  async incrementSportContributions(userId: string, at: Date): Promise<void> {
    await this.prisma.challengeParticipation.updateMany({
      where: {
        userId,
        challenge: { kind: 'SPORT', startsAt: { lte: at }, endsAt: { gte: at } },
      },
      data: { contribution: { increment: 1 } },
    });
  }

  // ── Réponses de quiz (défis CULTURE) ────────────────────────────────────

  /** Création idempotente : `false` si cette réponse existait déjà. */
  async createQuizAnswer(input: {
    userId: string;
    lessonId: string;
    answeredOn: string;
    correct: boolean;
  }): Promise<boolean> {
    try {
      await this.prisma.quizAnswer.create({ data: input });
      return true;
    } catch (error) {
      // P2002 : réponse déjà comptée (utilisateur, leçon, jour local).
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return false;
      }
      throw error;
    }
  }

  /** +1 sur tous les défis CULTURE rejoints dont la fenêtre couvre `at`. */
  async incrementCultureContributions(userId: string, at: Date): Promise<void> {
    await this.prisma.challengeParticipation.updateMany({
      where: {
        userId,
        challenge: { kind: 'CULTURE', startsAt: { lte: at }, endsAt: { gte: at } },
      },
      data: { contribution: { increment: 1 } },
    });
  }
}
