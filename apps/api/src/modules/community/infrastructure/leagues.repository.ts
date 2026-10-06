import { Injectable } from '@nestjs/common';
import { type LeagueDivision, type LeagueMembership, type Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { type LeagueStanding } from '../domain/league-ladder';
import { groupsForArrivals, groupWithRoom, lockGroups } from './league-groups';

type Client = Prisma.TransactionClient | PrismaService;

/** Une ligne de classement, avec le nom qu'on affiche à côté du score. */
export type LeagueMemberWithName = LeagueMembership & {
  user: {
    profile: { displayName: string } | null;
    /** Absente ou `joinsLeague: false` : la personne a quitté la ligue. */
    communityPreference: { joinsLeague: boolean } | null;
  };
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

  /**
   * Entre dans la ligue, ou en sort. Crée la préférence si besoin. Dans la
   * transaction de l'appelant s'il en fournit une (suppression du compte).
   */
  async setJoined(userId: string, joined: boolean, client: Client = this.prisma): Promise<void> {
    await client.communityPreference.upsert({
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
      // La division de DÉPART aussi : le déplacement décrémente son effectif
      // (`LeagueCohort`, tenu par la base). Sans son verrou, deux
      // déplacements en sens opposé prenaient les deux compteurs en croix —
      // interblocage. Les verrous se prennent dans l'ordre global.
      await lockGroups(tx, [
        { periodKey, division },
        ...(ligne === null ? [] : [{ periodKey, division: ligne.division }]),
      ]);
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
   * membres de son groupe. TOUS les membres de la période, partis compris :
   * le règlement se fait sur le groupe entier ; c'est la LECTURE qui tait
   * ceux qui ont quitté la ligue (`communityPreference.joinsLeague`).
   */
  standings(
    periodKey: string,
    division: LeagueDivision,
    cohort: number,
  ): Promise<LeagueMemberWithName[]> {
    return this.prisma.leagueMembership.findMany({
      where: { periodKey, division, cohort },
      include: {
        user: {
          select: {
            profile: { select: { displayName: true } },
            communityPreference: { select: { joinsLeague: true } },
          },
        },
      },
      orderBy: [{ score: 'desc' }, { userId: 'asc' }],
    });
  }

  /**
   * Les SCORES d'un groupe, du meilleur au dernier : tout ce que le
   * règlement lit (`settleDivision`), et rien de plus.
   *
   * `standings` joint le compte, le profil et la préférence de ligue pour
   * l'AFFICHAGE : trois requêtes de plus, que le règlement payait à chaque
   * semaine échue (78 sur 350 pour un revenant de 26 semaines). Même groupe,
   * mêmes lignes (partis compris) et même ordre que `standings`.
   */
  groupScores(
    periodKey: string,
    division: LeagueDivision,
    cohort: number,
  ): Promise<LeagueStanding[]> {
    return this.prisma.leagueMembership.findMany({
      where: { periodKey, division, cohort },
      select: { userId: true, score: true },
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
      const reglees = await this.settleRows(tx, periodKey, ordonnes);
      await this.realignFollowing(tx, periodKey, reglees);
      return reglees.length;
    });
  }

  /**
   * Les écritures du règlement, en DEUX requêtes pour tout le groupe.
   *
   * Elles en faisaient une par membre : vingt `UPDATE` à la suite par
   * semaine, et le règlement étant paresseux, un groupe que personne n'avait
   * lu depuis six mois payait 364 à 623 requêtes (0,4 à 0,7 s) sur un seul
   * GET. Le contrat de chaque ligne ne change pas : `settledAt IS NULL` dans
   * la condition, rang, division suivante et date posés ENSEMBLE, et seules
   * les lignes réellement réglées ici sont rendues.
   *
   * Le `FOR UPDATE` trié garde l'ordre de verrouillage par identifiant que
   * les écritures une à une donnaient d'elles-mêmes : un `UPDATE … FROM` ne
   * promet aucun ordre, et deux règlements concurrents du même groupe
   * pourraient sinon se prendre en croix.
   */
  private async settleRows(
    tx: Prisma.TransactionClient,
    periodKey: string,
    ordonnes: readonly SettlementResult[],
  ): Promise<SettlementResult[]> {
    if (ordonnes.length === 0) {
      return [];
    }
    const userIds = ordonnes.map((result) => result.userId);
    await tx.$queryRaw`
      SELECT "userId" FROM "LeagueMembership"
      WHERE "periodKey" = ${periodKey} AND "userId" = ANY(${userIds}::uuid[])
      ORDER BY "userId"
      FOR UPDATE
    `;
    // `settledAt` est un `timestamp` SANS fuseau, écrit en UTC par Prisma ;
    // une date liée en SQL brut arrive en `timestamptz`, que PostgreSQL
    // convertirait dans le fuseau de la SESSION. `AT TIME ZONE 'UTC'` écrit
    // la même heure que l'ORM, quel que soit le réglage du serveur.
    const reglees = await tx.$queryRaw<{ userId: string }[]>`
      UPDATE "LeagueMembership" lm
      SET "settledAt" = (${new Date()}::timestamptz AT TIME ZONE 'UTC'),
          "finalRank" = v.rank,
          "nextDivision" = v.next::"LeagueDivision"
      FROM unnest(
        ${userIds}::uuid[],
        ${ordonnes.map((result) => result.rank)}::int[],
        ${ordonnes.map((result) => result.nextDivision)}::text[]
      ) AS v(user_id, rank, next)
      WHERE lm."userId" = v.user_id
        AND lm."periodKey" = ${periodKey}
        AND lm."settledAt" IS NULL
      RETURNING lm."userId"::text AS "userId"
    `;
    const faites = new Set(reglees.map((ligne) => ligne.userId));
    return ordonnes.filter((result) => faites.has(result.userId));
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
    if (deplacements.length === 0) {
      return;
    }
    // Arrivées ET départs : chaque déplacement décrémente l'effectif de son
    // groupe de départ (`LeagueCohort`) ; tous ces compteurs sont couverts
    // par un verrou pris dans l'ordre global, avant tout verrou de ligne.
    await lockGroups(tx, [
      ...deplacements,
      ...deplacements.map(({ periodKey: cle, depart }) => ({ periodKey: cle, division: depart })),
    ]);
    // Un comptage par division d'arrivée, un seul `UPDATE` pour tout le lot :
    // le résultat est celui d'un `groupWithRoom` et d'une écriture par
    // membre, dans le même ordre, sans leurs allers-retours.
    const places = await groupsForArrivals(tx, deplacements);
    await tx.$executeRaw`
      UPDATE "LeagueMembership" lm
      SET "division" = v.division::"LeagueDivision", "cohort" = v.cohort
      FROM unnest(
        ${places.map((place) => place.userId)}::uuid[],
        ${places.map((place) => place.periodKey)}::text[],
        ${places.map((place) => place.division)}::text[],
        ${places.map((place) => place.cohort)}::int[]
      ) AS v(user_id, period_key, division, cohort)
      WHERE lm."userId" = v.user_id AND lm."periodKey" = v.period_key
    `;
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
  ): Promise<
    Array<{ userId: string; periodKey: string; division: LeagueDivision; depart: LeagueDivision }>
  > {
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
        ? [
            {
              userId,
              periodKey: suivante.periodKey,
              division: nextDivision,
              depart: suivante.division,
            },
          ]
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
