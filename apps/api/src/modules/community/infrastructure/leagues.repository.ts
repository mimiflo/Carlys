import { Injectable } from '@nestjs/common';
import { type LeagueDivision, type LeagueMembership, type Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { groupWithRoom, lockGroups } from './league-groups';

type Client = Prisma.TransactionClient | PrismaService;

/** Une ligne de classement, avec le nom qu'on affiche à côté du score. */
export type LeagueMemberWithName = LeagueMembership & {
  user: { profile: { displayName: string } | null };
};

/** Accès Prisma des ligues — et de lui seul. */
@Injectable()
export class LeaguesRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Vrai si cette personne a rejoint la ligue. Absence de ligne = non. */
  async hasJoined(userId: string, client: Client = this.prisma): Promise<boolean> {
    const preference = await client.communityPreference.findUnique({
      where: { userId },
      select: { joinsLeague: true },
    });
    return preference?.joinsLeague ?? false;
  }

  /** Entre dans la ligue, ou en sort. Crée la préférence si besoin. */
  async setJoined(userId: string, joined: boolean): Promise<void> {
    await this.prisma.communityPreference.upsert({
      where: { userId },
      create: { userId, joinsLeague: joined },
      update: { joinsLeague: joined },
    });
  }

  membership(userId: string, periodKey: string): Promise<LeagueMembership | null> {
    return this.prisma.leagueMembership.findUnique({
      where: { userId_periodKey: { userId, periodKey } },
    });
  }

  /**
   * La division de la période [periodKey] : celle que le dernier règlement
   * AVANT elle a décidée, à défaut celle de la dernière période connue
   * avant elle, et BRONZE si c'est la première.
   *
   * On lit la dernière période ANTÉRIEURE quelle qu'elle soit : six semaines
   * d'absence ne créent aucune ligne, donc la dernière connue EST la
   * division quittée. C'est la conséquence de la matérialisation
   * paresseuse, pas une règle ajoutée par-dessus.
   *
   * Jamais la période elle-même. Une séance du lundi peut l'ouvrir AVANT le
   * règlement de la semaine passée (qui n'a donc pas encore de division
   * suivante) : elle l'ouvre alors dans l'ancienne division. Relire cette
   * ligne-là après le règlement rendait encore l'ancienne division — la
   * montée décidée n'était appliquée nulle part. Voir [settle], qui réaligne
   * la période suivante, et [placeInPeriod].
   */
  async divisionToOpen(
    userId: string,
    periodKey: string,
    client: Client = this.prisma,
  ): Promise<LeagueDivision> {
    const derniere = await client.leagueMembership.findFirst({
      where: { userId, periodKey: { lt: periodKey } },
      orderBy: { periodKey: 'desc' },
      select: { division: true, nextDivision: true },
    });
    return derniere?.nextDivision ?? derniere?.division ?? 'BRONZE';
  }

  /**
   * Ouvre la période si elle n'existe pas, dans le premier GROUPE de
   * (période, division) qui a de la place (voir `league-groups.ts`).
   *
   * Dans la transaction de l'appelant s'il en fournit une (la réponse de
   * quiz verse sa contribution dans la sienne), sinon dans une transaction
   * à elle : le verrou du groupe ne vit que le temps d'une transaction.
   */
  async openPeriod(
    userId: string,
    periodKey: string,
    division: LeagueDivision,
    client: Client = this.prisma,
  ): Promise<void> {
    const existante = await client.leagueMembership.findUnique({
      where: { userId_periodKey: { userId, periodKey } },
      select: { userId: true },
    });
    if (existante !== null) {
      return; // Le cas courant : rien à verrouiller.
    }
    await this.inTransaction(client, async (tx) => {
      await lockGroups(tx, [{ periodKey, division }]);
      await this.createInGroup(tx, userId, periodKey, division);
    });
  }

  /**
   * La place du LECTEUR dans la période en cours : l'ouvre si elle manque,
   * la range dans la division qui lui revient si elle a été ouverte dans une
   * autre, et rend son groupe.
   *
   * Le rangement est le filet des lignes écrites avant [realignFollowing] :
   * une semaine ouverte trop tôt, dont le règlement précédent est déjà passé,
   * resterait sinon dans la mauvaise division jusqu'à sa fin. Changer de
   * division, c'est aussi changer de GROUPE : la nouvelle place se prend
   * sous le verrou de la division d'arrivée, comme une ouverture. Le score
   * reste acquis.
   */
  async placeInPeriod(
    userId: string,
    periodKey: string,
    division: LeagueDivision,
  ): Promise<number> {
    const ligne = await this.prisma.leagueMembership.findUnique({
      where: { userId_periodKey: { userId, periodKey } },
      select: { division: true, cohort: true, settledAt: true },
    });
    if (ligne !== null && (ligne.division === division || ligne.settledAt !== null)) {
      return ligne.cohort; // Le cas courant : déjà à sa place.
    }
    return this.prisma.$transaction(async (tx) => {
      await lockGroups(tx, [{ periodKey, division }]);
      const cohort = await this.createInGroup(tx, userId, periodKey, division);
      await tx.leagueMembership.updateMany({
        where: { userId, periodKey, settledAt: null, division: { not: division } },
        data: { division, cohort },
      });
      // Relue sous le verrou : une écriture concurrente a pu l'ouvrir la
      // première, et c'est SA place qui fait foi.
      const placee = await tx.leagueMembership.findUniqueOrThrow({
        where: { userId_periodKey: { userId, periodKey } },
        select: { cohort: true },
      });
      return placee.cohort;
    });
  }

  /**
   * Écrit la ligne dans le groupe qui a de la place, si elle n'existe pas
   * encore, et rend ce groupe. À appeler SOUS le verrou de (période,
   * division).
   *
   * `skipDuplicates` (ON CONFLICT DO NOTHING) plutôt qu'un P2002 attrapé :
   * deux écritures simultanées sur la même période sont normales (une
   * contribution et une lecture), et une violation d'unicité AVORTERAIT la
   * transaction englobante — celle de la réponse de quiz, par exemple.
   */
  private async createInGroup(
    tx: Prisma.TransactionClient,
    userId: string,
    periodKey: string,
    division: LeagueDivision,
  ): Promise<number> {
    const cohort = await groupWithRoom(tx, periodKey, division);
    await tx.leagueMembership.createMany({
      data: [{ userId, periodKey, division, cohort }],
      skipDuplicates: true,
    });
    return cohort;
  }

  /** `work` dans la transaction fournie, ou dans une transaction à lui. */
  private inTransaction<T>(
    client: Client,
    work: (tx: Prisma.TransactionClient) => Promise<T>,
  ): Promise<T> {
    return '$transaction' in client ? client.$transaction(work) : work(client);
  }

  /**
   * Ajoute des points à la période, si la ligne existe ET n'est pas réglée.
   * Rend le nombre de lignes touchées — 0 veut dire « à ouvrir ».
   *
   * Jamais de création ici, et jamais d'écriture sur une période RÉGLÉE :
   * un effort qui arrive en retard (une séance synchronisée après coup) ne
   * doit pas faire bouger un classement déjà annoncé.
   */
  async addPoints(
    userId: string,
    periodKey: string,
    points: number,
    client: Client = this.prisma,
  ): Promise<number> {
    if (points <= 0) {
      return 0;
    }
    const result = await client.leagueMembership.updateMany({
      where: { userId, periodKey, settledAt: null },
      data: { score: { increment: points } },
    });
    return result.count;
  }

  /**
   * Le classement d'un GROUPE de la division pour une période, du meilleur
   * au dernier. Jamais la division entière : on n'est classé qu'avec les
   * membres de son groupe.
   */
  standings(
    periodKey: string,
    division: LeagueDivision,
    cohort: number,
  ): Promise<LeagueMemberWithName[]> {
    return this.prisma.leagueMembership.findMany({
      where: { periodKey, division, cohort },
      include: { user: { select: { profile: { select: { displayName: true } } } } },
      orderBy: [{ score: 'desc' }, { userId: 'asc' }],
    });
  }

  /** Les périodes passées de cette personne qui n'ont jamais été réglées. */
  unsettledBefore(userId: string, periodKey: string): Promise<LeagueMembership[]> {
    return this.prisma.leagueMembership.findMany({
      where: { userId, settledAt: null, periodKey: { lt: periodKey } },
      orderBy: { periodKey: 'asc' },
    });
  }

  /**
   * RÈGLE un groupe entier pour une période close : rangs figés, division
   * suivante décidée, `settledAt` posé. Idempotent. Rend le nombre de
   * lignes que CE règlement a réglées.
   *
   * Chaque écriture est conditionnée à `settledAt: null`, ligne par ligne,
   * et porte le rang, la division suivante et `settledAt` ENSEMBLE : une
   * ligne déjà réglée n'est jamais réécrite. Deux lectures simultanées d'une
   * période échue n'en règlent donc qu'une, et une ligne arrivée APRÈS le
   * règlement (séance synchronisée en retard, semaine réalignée après
   * coup) se règle seule, sans décaler d'un cran les rangs déjà annoncés.
   * Seules les lignes réglées ici réalignent leur semaine suivante.
   *
   * Par identifiant croissant : deux règlements concurrents du même groupe
   * verrouillent ses lignes dans le même ordre, jamais en croix.
   *
   * C'est une lecture, quelle qu'elle soit, qui règle le groupe ENTIER :
   * sans ça, deux personnes liraient deux classements différents de la même
   * semaine. Le règlement n'OUVRE rien : la période suivante naît quand
   * quelqu'un la lit ou y verse un effort. Ouvrir ici créerait une ligne par
   * semaine d'absence, et chaque lecture d'un revenant en déclencherait la
   * cascade.
   */
  async settle(periodKey: string, results: ReadonlyArray<SettlementResult>): Promise<number> {
    const ordonnes = [...results].sort((a, b) => (a.userId < b.userId ? -1 : 1));
    return this.prisma.$transaction(async (tx) => {
      const settledAt = new Date();
      const reglees: SettlementResult[] = [];
      for (const result of ordonnes) {
        const { count } = await tx.leagueMembership.updateMany({
          where: { userId: result.userId, periodKey, settledAt: null },
          data: { settledAt, finalRank: result.rank, nextDivision: result.nextDivision },
        });
        if (count > 0) {
          reglees.push(result);
        }
      }
      await this.realignFollowing(tx, periodKey, reglees);
      return reglees.length;
    });
  }

  /**
   * Remet dans la division DÉCIDÉE la période qui suit, si une séance l'a
   * ouverte avant ce règlement (dans l'ancienne division, faute de mieux).
   *
   * Seule la période QUI SUIT celle qu'on règle — la première ligne après
   * elle —, et seulement si elle n'est pas réglée elle-même. Réglée, elle a
   * déjà décidé de la suite, et c'est SA décision que la période d'après
   * suit : la sauter pour réaligner une période plus lointaine y
   * appliquerait la décision d'une ligne tardive, plus ancienne. Une
   * période plus lointaine dépend du règlement de la précédente, qui la
   * réalignera à son tour. Son score reste acquis ; sa division change, et
   * avec elle son GROUPE, attribué sous le verrou de la division d'arrivée
   * comme une ouverture.
   */
  private async realignFollowing(
    tx: Prisma.TransactionClient,
    periodKey: string,
    results: ReadonlyArray<SettlementResult>,
  ): Promise<void> {
    const deplacements = await this.misplacedFollowing(tx, periodKey, results);
    await lockGroups(tx, deplacements);
    for (const { userId, periodKey: suivante, division } of deplacements) {
      const cohort = await groupWithRoom(tx, suivante, division);
      await tx.leagueMembership.update({
        where: { userId_periodKey: { userId, periodKey: suivante } },
        data: { division, cohort },
      });
    }
  }

  /**
   * Les périodes qui suivent `periodKey`, non réglées, et qui ne sont pas
   * dans la division que le règlement vient de décider : où chacune doit
   * aller. Une suivante DÉJÀ réglée n'est jamais sautée (voir
   * [realignFollowing]).
   */
  private async misplacedFollowing(
    tx: Prisma.TransactionClient,
    periodKey: string,
    results: ReadonlyArray<SettlementResult>,
  ): Promise<Array<{ userId: string; periodKey: string; division: LeagueDivision }>> {
    if (results.length === 0) {
      return [];
    }
    const suivantes = await tx.leagueMembership.findMany({
      where: { userId: { in: results.map((r) => r.userId) }, periodKey: { gt: periodKey } },
      distinct: ['userId'],
      orderBy: [{ userId: 'asc' }, { periodKey: 'asc' }],
      select: { userId: true, periodKey: true, division: true, settledAt: true },
    });
    const premiere = new Map(suivantes.map((suivante) => [suivante.userId, suivante]));
    return results.flatMap(({ userId, nextDivision }) => {
      const suivante = premiere.get(userId);
      return suivante !== undefined &&
        suivante.settledAt === null &&
        suivante.division !== nextDivision
        ? [{ userId, periodKey: suivante.periodKey, division: nextDivision }]
        : [];
    });
  }
}

/** Ce que le règlement décide pour une personne. */
export type SettlementResult = {
  userId: string;
  rank: number;
  nextDivision: LeagueDivision;
};
