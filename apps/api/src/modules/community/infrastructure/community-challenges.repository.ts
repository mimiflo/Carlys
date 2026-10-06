import { Injectable } from '@nestjs/common';
import { type ChallengeMetric, type CommunityChallenge, Prisma } from '@prisma/client';
import { lockNamed } from '../../../database/prisma/advisory-lock';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { CacheService } from '../../../infrastructure/cache/cache.service';
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

/** Ce que tout le monde voit d'un défi : sa somme, et qui y est encore. */
type SharedStats = Record<string, { total: number; present: number }>;

/**
 * Les agrégats PARTAGÉS des défis, en cache. Ils parcourent toutes les
 * participations — tout le monde participe aux défis du mois — à CHAQUE
 * ouverture de l'onglet : la base saturait à quelques dizaines de lectures
 * par seconde. La clé embarque une VERSION, montée APRÈS chaque
 * participation et chaque contribution validées en base : on voit aussitôt
 * l'effet de son propre geste. La durée de vie borne le reste — l'écart
 * d'un autre exemplaire qui aurait relu juste avant la montée.
 */
const STATS_VERSION = 'community:challenge-stats:version';
const STATS_TTL_SECONDS = 30;

/** Défis collectifs et réponses de quiz (la source des défis CULTURE). */
@Injectable()
export class CommunityChallengesRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
  ) {}

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
        metric: seed.metric,
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

  /**
   * Rejoindre est idempotent : rejouer la requête ne crée pas de doublon.
   * Revenir après un départ REPREND la même ligne — la contribution déjà
   * versée n'est ni perdue ni comptée deux fois.
   */
  async joinChallenge(challengeId: string, userId: string): Promise<void> {
    await this.prisma.challengeParticipation.upsert({
      where: { challengeId_userId: { challengeId, userId } },
      create: { challengeId, userId },
      update: { leftAt: null },
    });
    await this.cache.increment(STATS_VERSION);
  }

  /**
   * Quitter DATE le départ, sans effacer la ligne.
   *
   * La supprimer retirait la contribution déjà versée de la somme collective :
   * la barre du mois, que tout le monde voit, redescendait d'autant — un
   * compteur collectif ne peut que monter. Ce qui a été fait pendant qu'on
   * participait reste acquis au défi ; seule la participation s'arrête.
   */
  async leaveChallenge(challengeId: string, userId: string): Promise<void> {
    await this.prisma.challengeParticipation.updateMany({
      where: { challengeId, userId, leftAt: null },
      data: { leftAt: new Date() },
    });
    await this.cache.increment(STATS_VERSION);
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
   * Agrège en BASE, en trois requêtes de taille fixe, quel que soit le nombre
   * de participants — les deux agrégats partagés passant par le cache.
   *
   * La SOMME porte sur toutes les lignes, parties comprises : une
   * contribution versée appartient à l'objectif collectif. Le COMPTE, lui,
   * ne retient que les participants encore présents — c'est « combien sommes-
   * nous », pas « combien sommes-nous passés ». Deux questions différentes,
   * donc deux agrégats.
   */
  private async withStats(
    challenges: CommunityChallenge[],
    userId: string,
  ): Promise<ChallengeWithStats[]> {
    if (challenges.length === 0) {
      return [];
    }
    const ids = challenges.map((challenge) => challenge.id);
    const [partagees, miennes] = await Promise.all([
      this.sharedStats(ids),
      this.prisma.challengeParticipation.findMany({
        where: { challengeId: { in: ids }, userId, leftAt: null },
        select: { challengeId: true },
      }),
    ]);
    const rejoints = new Set(miennes.map((ligne) => ligne.challengeId));

    return challenges.map((challenge) => ({
      ...challenge,
      totalContribution: partagees[challenge.id]?.total ?? 0,
      participants: partagees[challenge.id]?.present ?? 0,
      joined: rejoints.has(challenge.id),
    }));
  }

  /** Les deux agrégats partagés, lus en cache, sinon en base puis gardés. */
  private async sharedStats(ids: string[]): Promise<SharedStats> {
    const version = (await this.cache.getJson<number>(STATS_VERSION)) ?? 0;
    const key = `community:challenge-stats:${version}:${[...ids].sort().join(',')}`;
    const cached = await this.cache.getJson<SharedStats>(key);
    if (cached !== null) {
      return cached;
    }
    const [totaux, presents] = await Promise.all([
      this.prisma.challengeParticipation.groupBy({
        by: ['challengeId'],
        where: { challengeId: { in: ids } },
        _sum: { contribution: true },
      }),
      this.prisma.challengeParticipation.groupBy({
        by: ['challengeId'],
        where: { challengeId: { in: ids }, leftAt: null },
        _count: { _all: true },
      }),
    ]);
    const parDefiPresents = new Map(presents.map((ligne) => [ligne.challengeId, ligne]));
    const stats: SharedStats = Object.fromEntries(
      totaux.map((ligne) => [
        ligne.challengeId,
        {
          total: ligne._sum.contribution ?? 0,
          present: parDefiPresents.get(ligne.challengeId)?._count._all ?? 0,
        },
      ]),
    );
    await this.cache.setJson(key, stats, STATS_TTL_SECONDS);
    return stats;
  }

  /**
   * `amount` sur tous les défis de cette MÉTRIQUE encore rejoints dont la
   * fenêtre couvre `at`.
   *
   * Une seule méthode pour toutes les unités, là où il y en avait deux, une
   * par famille, avec `+1` écrit en dur dans chacune. Compter des mètres
   * demandait donc une troisième copie — et trois copies d'une même règle,
   * c'est deux occasions de la corriger à moitié.
   *
   * `leftAt: null` : la ligne d'un défi quitté survit pour garder sa
   * contribution acquise, elle ne doit plus en recevoir de nouvelles.
   *
   * `amount <= 0` ne fait RIEN et ne lève pas : une séance sans distance
   * parcourue n'est pas une erreur, c'est le cas ordinaire. Une écriture
   * inutile par séance et par métrique absente, en revanche, en serait une.
   */
  async contribute(
    userId: string,
    metric: ChallengeMetric,
    amount: number,
    at: Date,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<void> {
    if (amount <= 0) {
      return;
    }
    const { count } = await client.challengeParticipation.updateMany({
      where: {
        userId,
        leftAt: null,
        challenge: { metric, startsAt: { lte: at }, endsAt: { gte: at } },
      },
      data: { contribution: { increment: amount } },
    });
    // Aucun défi rejoint pour cette métrique : rien de partagé n'a bougé.
    // Dans une transaction, c'est son appelant qui monte la version APRÈS le
    // COMMIT : avant, une lecture concurrente rangerait l'état d'avant sous
    // la nouvelle version, et un Redis lent retiendrait la transaction.
    if (count > 0 && client === this.prisma) {
      await this.cache.increment(STATS_VERSION);
    }
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
    /** Index du choix retenu — absent des clients d'avant sa lecture. */
    choiceIndex?: number;
    /** Instant de référence pour la fenêtre des défis. */
    at: Date;
    /**
     * Ce qu'il faut écrire DANS la même transaction — la contribution aux
     * défis entre amis, que ce dépôt ne connaît pas.
     *
     * Passée en fonction plutôt qu'appelée après coup pour la raison
     * ci-dessus : hors transaction, son échec laisserait la réponse écrite,
     * et l'unicité rendrait la perte définitive au rejeu.
     */
    alsoInTransaction?: (tx: Prisma.TransactionClient) => Promise<void>;
    /**
     * Bonnes réponses qui rapportent, par jour déclaré. Au-delà, la réponse
     * s'écrit (la progression la garde) mais ne verse plus rien : sans ce
     * plafond, vingt réponses « justes » valaient vingt fois dix points.
     */
    creditedPerDay: number;
  }): Promise<boolean> {
    const { at, alsoInTransaction, creditedPerDay, ...answer } = input;
    try {
      let credited = false;
      await this.prisma.$transaction(async (tx) => {
        // Compter puis verser sous un verrou par compte : des réponses
        // parallèles liraient toutes le même décompte.
        await lockNamed(tx, `quiz-answer:${answer.userId}`);
        await tx.quizAnswer.create({ data: answer });
        if (answer.correct && (await this.correctOnDay(tx, answer)) <= creditedPerDay) {
          await this.contribute(answer.userId, 'QUIZ_CORRECT', 1, at, tx);
          await alsoInTransaction?.(tx);
          credited = true;
        }
      });
      if (credited) {
        await this.cache.increment(STATS_VERSION);
      }
      return true;
    } catch (error) {
      // P2002 : réponse déjà comptée (utilisateur, leçon, jour local).
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return false;
      }
      throw error;
    }
  }

  /** Bonnes réponses de ce compte ce jour-là, celle qu'on vient d'écrire comprise. */
  private correctOnDay(
    tx: Prisma.TransactionClient,
    answer: { userId: string; answeredOn: string },
  ): Promise<number> {
    return tx.quizAnswer.count({
      where: { userId: answer.userId, answeredOn: answer.answeredOn, correct: true },
    });
  }

  /**
   * Les réponses de quiz relues pour reconstruire la progression sur un
   * nouvel appareil : UNE entrée par leçon, la PREMIÈRE réponse fait foi —
   * la même règle que le magasin local (« la première gagne »), sinon les
   * deux sources divergeraient sur le choix affiché.
   */
  async listQuizAnswers(userId: string): Promise<
    Array<{
      lessonId: string;
      choiceIndex: number | null;
      correct: boolean;
      answeredOn: string;
    }>
  > {
    // `distinct` retient la première ligne rencontrée par leçon dans
    // l'ordre demandé : trier par date de création rend donc la première
    // réponse, pas une au hasard.
    return this.prisma.quizAnswer.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
      distinct: ['lessonId'],
      select: {
        lessonId: true,
        choiceIndex: true,
        correct: true,
        answeredOn: true,
      },
    });
  }
}
