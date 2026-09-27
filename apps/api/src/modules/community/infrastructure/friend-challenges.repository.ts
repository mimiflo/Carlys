import { Injectable } from '@nestjs/common';
import {
  type ChallengeMetric,
  type FriendChallenge,
  type FriendChallengeMember,
  Prisma,
} from '@prisma/client';
import { lockNamed } from '../../../database/prisma/advisory-lock';
import { PrismaService } from '../../../database/prisma/prisma.service';

/** Un défi, ses membres, et le nom d'affichage de chacun. */
export type FriendChallengeWithMembers = FriendChallenge & {
  members: Array<FriendChallengeMember & { user: { profile: { displayName: string } | null } }>;
  creator: { profile: { displayName: string } | null };
};

const AVEC_MEMBRES = {
  members: {
    include: { user: { select: { profile: { select: { displayName: true } } } } },
    orderBy: [{ contribution: 'desc' }, { userId: 'asc' }],
  },
  creator: { select: { profile: { select: { displayName: true } } } },
} satisfies Prisma.FriendChallengeInclude;

/** Accès Prisma des défis entre amis — et de lui seul. */
@Injectable()
export class FriendChallengesRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Crée le défi ET ses membres dans UNE transaction, si le créateur a
   * encore de la place sous `maxOpen` défis ouverts.
   *
   * Le décompte et l'écriture se font sous un verrou par créateur : sans lui,
   * quinze créations parallèles lisaient toutes « 0 défi ouvert » avant
   * qu'aucune n'écrive, et onze passaient pour un plafond de cinq — onze
   * notifications par invité, alors que le plafond borne justement ce
   * canal-là.
   *
   * `REPLAY` : l'identifiant existait déjà (création rejouée en même temps
   * que l'originale) — ce n'est pas une erreur, l'identifiant vient de
   * l'appareil. `LIMIT` : plafond atteint, rien n'est écrit.
   */
  async createWithinLimit(
    challenge: Prisma.FriendChallengeUncheckedCreateInput & { startsAt: Date },
    invitedUserIds: string[],
    maxOpen: number,
  ): Promise<'CREATED' | 'REPLAY' | 'LIMIT'> {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await lockNamed(tx, `friend-challenge-create:${challenge.creatorId}`);
        const ouverts = await tx.friendChallenge.count({
          where: {
            creatorId: challenge.creatorId,
            status: 'OPEN',
            endsAt: { gte: challenge.startsAt },
          },
        });
        if (ouverts >= maxOpen) {
          return 'LIMIT';
        }
        await tx.friendChallenge.create({ data: challenge });
        await tx.friendChallengeMember.createMany({
          data: [
            // Le créateur est membre ACCEPTÉ d'office : il n'a pas à
            // s'inviter lui-même, et un défi sans lui n'aurait aucun sens.
            {
              challengeId: challenge.id,
              userId: challenge.creatorId,
              invitedById: challenge.creatorId,
              status: 'ACCEPTED',
              joinedAt: new Date(),
            },
            ...invitedUserIds.map((userId) => ({
              challengeId: challenge.id,
              userId,
              invitedById: challenge.creatorId,
            })),
          ],
        });
        return 'CREATED';
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return 'REPLAY';
      }
      throw error;
    }
  }

  findById(id: string): Promise<FriendChallengeWithMembers | null> {
    return this.prisma.friendChallenge.findUnique({
      where: { id },
      include: AVEC_MEMBRES,
    });
  }

  /**
   * Les défis où l'appelant est membre à un titre ou à un autre — invité
   * compris, puisque c'est là qu'il voit ce qu'on lui propose.
   *
   * Les refusés et les quittés en sortent : ce sont des décisions prises,
   * pas des choses à revoir.
   *
   * DEUX LECTURES BORNÉES, les défis EN COURS d'abord (fin la plus proche en
   * tête), puis les plus récents des TERMINÉS. La clôture ne change pas le
   * statut d'un membre, donc l'historique s'accumule : une lecture unique,
   * triée par fin croissante et coupée à 50, servait les 50 défis les plus
   * ANCIENS dès le cinquante et unième. Mesuré sur un compte à 123 défis :
   * 50 servis, tous terminés, et les 4 en cours (invitations comprises)
   * absents de l'écran.
   *
   * Un défi échu mais pas encore réglé tombe dans les terminés : c'est la
   * lecture qui le règle (`settleIfDue`). Un défi ANNULÉ aussi, même avant
   * sa date de fin : il est terminé.
   */
  async listMine(
    userId: string,
    now: Date,
    limits: { ongoing: number; finished: number },
  ): Promise<FriendChallengeWithMembers[]> {
    const membre: Prisma.FriendChallengeWhereInput = {
      members: { some: { userId, status: { in: ['INVITED', 'ACCEPTED'] } } },
    };
    const enCoursSeulement: Prisma.FriendChallengeWhereInput = {
      status: 'OPEN',
      endsAt: { gte: now },
    };
    const [enCours, termines] = await Promise.all([
      this.prisma.friendChallenge.findMany({
        where: { ...membre, ...enCoursSeulement },
        include: AVEC_MEMBRES,
        orderBy: [{ endsAt: 'asc' }, { id: 'asc' }],
        take: limits.ongoing,
      }),
      this.prisma.friendChallenge.findMany({
        where: { ...membre, NOT: enCoursSeulement },
        include: AVEC_MEMBRES,
        orderBy: [{ endsAt: 'desc' }, { id: 'desc' }],
        take: limits.finished,
      }),
    ]);
    return [...enCours, ...termines];
  }

  /** Change l'état d'un membre. Rend `false` si la ligne n'existe pas. */
  async setMemberStatus(
    challengeId: string,
    userId: string,
    status: FriendChallengeMember['status'],
    dates: { joinedAt?: Date | null; leftAt?: Date | null } = {},
  ): Promise<boolean> {
    const result = await this.prisma.friendChallengeMember.updateMany({
      where: { challengeId, userId },
      data: { status, ...dates },
    });
    return result.count > 0;
  }

  /**
   * `amount` sur tous les défis entre amis ACCEPTÉS, ouverts, de cette
   * métrique, dont la fenêtre couvre `at`.
   *
   * Ce qui est partagé avec les défis collectifs, c'est l'APPELANT : un
   * seul, `CommunityChallengesService.verser`, écrit les trois compteurs
   * ensemble, et c'est lui qui les empêche de dériver.
   *
   * La RÈGLE est celle de la contribution collective
   * (`CommunityChallengesRepository.contribute`) : un membre encore dans le
   * défi, la bonne métrique, une fenêtre qui couvre `at`. S'y ajoutent deux
   * filtres propres aux défis entre amis : l'appartenance ACCEPTÉE (une
   * invitation ne compte pas) et le défi OUVERT (un défi réglé est figé).
   * Ces filtres, un par défi témoin, sont épinglés par l'e2e « une
   * contribution ne va QU'aux défis acceptés… » de
   * `test/friend-challenges.e2e-spec.ts`.
   *
   * La FORME, elle, diffère exprès : du SQL écrit à la main là où le
   * collectif garde un `updateMany`, pour la raison donnée dans le corps.
   * Ne pas « réaligner » l'une sur l'autre : `friend-challenges.repository
   * .spec.ts` garde cette forme, qui décide du coût.
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
    // En SQL, pour choisir le point de départ : les APPARTENANCES de cette
    // personne (index `userId, status`), puis, pour chacune, son défi par sa
    // clé. L'`updateMany` de Prisma rendait une semi-jointure que PostgreSQL
    // attaquait par l'autre bout, `FriendChallenge(status, endsAt)` : TOUS
    // les défis ouverts de TOUS les comptes (estimés 10, trouvés 999 —
    // statut et fin sont corrélés), une sonde de membre pour chacun. 8 ms
    // et 3 890 tampons, à chaque séance close et chaque bonne réponse de
    // quiz, pour un coût qui suivait la communauté et non la personne.
    // L'`OFFSET 0` interdit au planificateur de remettre la semi-jointure à
    // plat : 1,2 ms et 512 tampons, bornés par l'historique de la personne.
    // Les bornes sont des `timestamp` SANS fuseau, écrits en UTC par Prisma :
    // l'instant lié arrive en `timestamptz`, d'où le `AT TIME ZONE 'UTC'`,
    // sans lequel la comparaison dépendrait du fuseau de la session.
    await client.$executeRaw`
      UPDATE "FriendChallengeMember" m
      SET "contribution" = m."contribution" + ${amount}::int
      WHERE m."userId" = ${userId}::uuid
        AND m."status" = 'ACCEPTED'
        AND EXISTS (
          SELECT 1 FROM "FriendChallenge" c
          WHERE c."id" = m."challengeId"
            AND c."metric" = ${metric}::"ChallengeMetric"
            AND c."status" = 'OPEN'
            AND c."startsAt" <= (${at}::timestamptz AT TIME ZONE 'UTC')
            AND c."endsAt" >= (${at}::timestamptz AT TIME ZONE 'UTC')
          OFFSET 0
        )
    `;
  }

  /**
   * Suppression du compte, DANS sa transaction : la personne quitte tous les
   * défis entre amis, tout de suite.
   *
   *  - Les défis qu'elle a LANCÉS partent entiers. Leur titre et leur mot
   *    sont les siens, et la purge les emporterait de toute façon avec elle
   *    (cascade du créateur) : les garder trente jours laisserait aux autres
   *    un défi sans créateur, au nom vide. Un signalement qui en visait un
   *    garde ses clichés (`SetNull`).
   *  - Dans les défis des autres, sa ligne de membre part : elle n'est plus
   *    au classement. Un rang déjà FIGÉ (défi clos) ne bouge pas.
   *  - Un défi en cours où plus personne n'attend ni ne joue face au
   *    créateur est ANNULÉ : un défi contre personne n'en est pas un — la
   *    création le refuse déjà. `closedAt` est posé avec : la clôture
   *    paresseuse, conditionnée à sa nullité, ne le rouvrira pas en `CLOSED`.
   *
   * Un défi ÉCHU doit donc être RÉGLÉ avant l'appel, avec elle
   * (`CommunityWithdrawalService`, via [dueUnsettledOf] et [settle]) : son
   * `closedAt` posé, il n'est ni annulé ici ni réglé plus tard sans elle.
   */
  async withdrawAccount(userId: string, now: Date, tx: Prisma.TransactionClient): Promise<void> {
    await tx.friendChallenge.deleteMany({ where: { creatorId: userId } });
    const quittes = await tx.friendChallengeMember.findMany({
      where: { userId },
      select: { challengeId: true },
    });
    if (quittes.length === 0) {
      return;
    }
    await tx.friendChallengeMember.deleteMany({ where: { userId } });
    const maintenant = Prisma.sql`(${now}::timestamptz AT TIME ZONE 'UTC')`;
    await tx.$executeRaw`
      UPDATE "FriendChallenge" c
      SET "status" = 'CANCELLED', "closedAt" = ${maintenant}, "updatedAt" = ${maintenant}
      WHERE c."id" = ANY(${quittes.map((ligne) => ligne.challengeId)}::uuid[])
        AND c."status" = 'OPEN'
        AND c."closedAt" IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM "FriendChallengeMember" m
          WHERE m."challengeId" = c."id"
            AND m."userId" <> c."creatorId"
            AND m."status" IN ('INVITED', 'ACCEPTED')
        )
    `;
  }

  /**
   * Les défis ÉCHUS pas encore réglés dont `userId` est membre, hors ceux
   * qu'il a lancés : ce qu'une suppression de compte doit régler avant d'en
   * retirer sa ligne.
   */
  dueUnsettledOf(
    userId: string,
    now: Date,
    tx: Prisma.TransactionClient,
  ): Promise<FriendChallengeWithMembers[]> {
    return tx.friendChallenge.findMany({
      where: {
        members: { some: { userId } },
        creatorId: { not: userId },
        closedAt: null,
        endsAt: { lt: now },
      },
      include: AVEC_MEMBRES,
    });
  }

  /**
   * RÈGLE un défi échu : fige les rangs, ferme le défi. Idempotent.
   *
   * L'écriture est conditionnée à `closedAt: null`, et c'est toute
   * l'idempotence : deux lectures simultanées d'un défi échu tentent chacune
   * le règlement, une seule le gagne. Sans cron — comme le jeu du mois, qui
   * se matérialise à la première lecture — mais avec une écriture, parce
   * qu'un classement doit rester stable même si plus personne ne regarde.
   *
   * `tx` : dans la transaction de l'appelant (suppression de compte) ;
   * sinon, dans la sienne.
   */
  async settle(
    challengeId: string,
    ranks: Array<{ userId: string; rank: number }>,
    tx?: Prisma.TransactionClient,
  ): Promise<void> {
    if (tx === undefined) {
      return this.prisma.$transaction((client) => this.settle(challengeId, ranks, client));
    }
    const ferme = await tx.friendChallenge.updateMany({
      where: { id: challengeId, closedAt: null },
      data: { status: 'CLOSED', closedAt: new Date() },
    });
    if (ferme.count === 0) {
      return; // Déjà réglé par une lecture concurrente.
    }
    for (const { userId, rank } of ranks) {
      await tx.friendChallengeMember.updateMany({
        where: { challengeId, userId },
        data: { finalRank: rank },
      });
    }
  }
}
