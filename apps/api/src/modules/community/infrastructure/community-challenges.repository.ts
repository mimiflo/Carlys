import { Injectable } from '@nestjs/common';
import { type CommunityChallenge, Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { type MonthlyChallengeSeed } from '../domain/challenge-catalog';

/**
 * Un défi et les TROIS scalaires que l'écran en tire — pas la liste de ses
 * participants.
 *
 * Le dépôt rapatriait toutes les participations de tous les défis ouverts
 * (`include: { participations: … }`), pour n'en calculer qu'une somme, un
 * compte et un booléen. Un défi collectif est fait pour rassembler tout le
 * monde : la liste grossit avec la base d'utilisateurs, alors que ce qu'on
 * en fait ne change pas de taille. L'agrégation se fait donc en base, où
 * elle coûte un parcours d'index plutôt qu'un transfert.
 */
export interface ChallengeWithStats extends CommunityChallenge {
  /** Somme des contributions, tous participants confondus. */
  totalContribution: number;
  participants: number;
  /** L'appelant a-t-il rejoint ce défi ? */
  joined: boolean;
}

/** Défis collectifs et réponses de quiz (la source des défis CULTURE). */
@Injectable()
export class CommunityChallengesRepository {
  constructor(private readonly prisma: PrismaService) {}

  // ── Défis collectifs ────────────────────────────────────────────────────

  /**
   * Nombre de défis du CATALOGUE déjà matérialisés pour un mois (`YYYY-MM`).
   * Filtré par slug : un défi posé à la main dans le même mois ne doit pas
   * faire croire que le jeu du mois est là.
   */
  countForMonth(month: string, slugs: string[]): Promise<number> {
    return this.prisma.communityChallenge.count({ where: { month, slug: { in: slugs } } });
  }

  /**
   * Écrit le jeu du mois. `skipDuplicates` s'appuie sur l'unicité
   * (slug, mois) : deux lectures concurrentes d'un mois vierge écrivent
   * chacune ce qui manque, jamais deux fois la même ligne.
   */
  async createMonthlyChallenges(seeds: MonthlyChallengeSeed[]): Promise<void> {
    await this.prisma.communityChallenge.createMany({
      data: seeds.map((seed) => ({
        slug: seed.slug,
        month: seed.month,
        kind: seed.kind,
        title: seed.title,
        description: seed.description,
        target: seed.target,
        startsAt: seed.startsAt,
        endsAt: seed.endsAt,
      })),
      skipDuplicates: true,
    });
  }

  /** Défis dont la fenêtre n'est pas terminée, avec leurs totaux agrégés. */
  async listOpenChallenges(now: Date, userId: string): Promise<ChallengeWithStats[]> {
    const challenges = await this.prisma.communityChallenge.findMany({
      where: { endsAt: { gte: now } },
      orderBy: { endsAt: 'asc' },
    });
    return this.withStats(challenges, userId);
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

  async challengeStats(challengeId: string, userId: string): Promise<ChallengeWithStats | null> {
    const challenge = await this.prisma.communityChallenge.findUnique({
      where: { id: challengeId },
    });
    if (challenge === null) {
      return null;
    }
    const [avecStats] = await this.withStats([challenge], userId);
    return avecStats ?? null;
  }

  /**
   * Agrège en BASE, en deux requêtes de taille fixe, quel que soit le nombre
   * de participants : un `groupBy` pour la somme et le compte, une lecture
   * ciblée pour savoir si l'appelant a rejoint.
   */
  private async withStats(
    challenges: CommunityChallenge[],
    userId: string,
  ): Promise<ChallengeWithStats[]> {
    if (challenges.length === 0) {
      return [];
    }
    const ids = challenges.map((challenge) => challenge.id);
    const [totaux, miennes] = await Promise.all([
      this.prisma.challengeParticipation.groupBy({
        by: ['challengeId'],
        where: { challengeId: { in: ids } },
        _sum: { contribution: true },
        _count: { _all: true },
      }),
      this.prisma.challengeParticipation.findMany({
        where: { challengeId: { in: ids }, userId },
        select: { challengeId: true },
      }),
    ]);

    const parDefi = new Map(totaux.map((ligne) => [ligne.challengeId, ligne]));
    const rejoints = new Set(miennes.map((ligne) => ligne.challengeId));

    return challenges.map((challenge) => {
      const ligne = parDefi.get(challenge.id);
      return {
        ...challenge,
        totalContribution: ligne?._sum.contribution ?? 0,
        participants: ligne?._count._all ?? 0,
        joined: rejoints.has(challenge.id),
      };
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

  /**
   * Réponse de quiz ET contribution aux défis CULTURE, dans UNE transaction.
   *
   * Rend `false` si cette réponse existait déjà — l'idempotence est portée
   * par `@@unique([userId, lessonId, answeredOn])`.
   *
   * POURQUOI LES DEUX ÉCRITURES SONT LIÉES. Elles étaient séparées, et
   * l'idempotence rendait la perte DÉFINITIVE : la réponse écrite d'abord,
   * puis l'incrément — si l'incrément échouait (contention, coupure), la
   * ligne de réponse restait. Au rejeu, la contrainte d'unicité rendait
   * `false`, l'incrément n'était jamais retenté, et la contribution était
   * perdue pour de bon. La voie jumelle (`recordWorkoutCompleted`) n'a pas ce
   * problème : elle n'écrit qu'une chose, et se rattrape à la séance
   * suivante. Ici il n'y a pas de « suivante » — une leçon ne se répond
   * qu'une fois par jour.
   *
   * Tout ou rien, donc : l'échec de l'incrément annule la réponse, et le
   * rejeu refait les deux.
   */
  async recordQuizAnswer(input: {
    userId: string;
    lessonId: string;
    answeredOn: string;
    correct: boolean;
    /** Instant de référence pour la fenêtre des défis. */
    at: Date;
  }): Promise<boolean> {
    const { at, ...answer } = input;
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.quizAnswer.create({ data: answer });
        if (answer.correct) {
          await this.incrementCultureContributions(answer.userId, at, tx);
        }
      });
      return true;
    } catch (error) {
      // P2002 : réponse déjà comptée (utilisateur, leçon, jour local).
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return false;
      }
      throw error;
    }
  }

  /**
   * +1 sur tous les défis CULTURE rejoints dont la fenêtre couvre `at`.
   *
   * `client` permet de l'exécuter DANS la transaction de `recordQuizAnswer`
   * plutôt qu'à côté ; sans argument, il travaille hors transaction, comme
   * avant.
   */
  async incrementCultureContributions(
    userId: string,
    at: Date,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<void> {
    await client.challengeParticipation.updateMany({
      where: {
        userId,
        challenge: { kind: 'CULTURE', startsAt: { lte: at }, endsAt: { gte: at } },
      },
      data: { contribution: { increment: 1 } },
    });
  }
}
