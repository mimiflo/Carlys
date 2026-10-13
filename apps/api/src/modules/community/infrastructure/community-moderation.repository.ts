import { Injectable } from '@nestjs/common';
import {
  type CommunityBlock,
  type CommunityReportReason,
  CommunityReportStatus,
  FriendRequestStatus,
  type Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export interface BlockedUserRow extends CommunityBlock {
  blocked: { profile: { displayName: string } | null };
}

/** Les deux personnes d'un signalement, avec de quoi agir depuis le back-office. */
const reportPartySelect = {
  id: true,
  email: true,
  profile: { select: { displayName: true } },
} satisfies Prisma.UserSelect;

export const reportInclude = {
  reporter: { select: reportPartySelect },
  // Le statut COURANT du compte signalé : la décision de suspendre en dépend.
  reportedUser: { select: { ...reportPartySelect, status: true } },
  resolvedBy: { select: { id: true, email: true, displayName: true } },
  friendChallenge: { select: { messageRemovedAt: true } },
} satisfies Prisma.CommunityReportInclude;

export type CommunityReportRow = Prisma.CommunityReportGetPayload<{
  include: typeof reportInclude;
}>;

export interface CreateReportInput {
  reporterId: string;
  reportedUserId: string;
  /** Exclusif avec `friendChallengeId` : le service refuse les deux ensemble. */
  encouragementId: string | null;
  friendChallengeId: string | null;
  reason: CommunityReportReason;
  details: string | null;
}

export interface ReportFilters {
  status?: CommunityReportStatus;
  reason?: CommunityReportReason;
  reportedUserId?: string;
}

/** Les CLICHÉS figés à la création d'un signalement, `null` s'ils ne s'appliquent pas. */
type ReportSnapshot = Pick<
  Prisma.CommunityReportUncheckedCreateInput,
  'encouragementMessage' | 'friendChallengeTitle' | 'friendChallengeMessage'
>;

/** Blocages, suppression d'encouragements et signalements. */
@Injectable()
export class CommunityModerationRepository {
  constructor(private readonly prisma: PrismaService) {}

  // ── Blocages ────────────────────────────────────────────────────────────

  /** Un blocage existe-t-il entre les deux, dans un sens OU dans l'autre ? */
  async isBlockedEitherWay(a: string, b: string): Promise<boolean> {
    const block = await this.prisma.communityBlock.findFirst({
      where: {
        OR: [
          { blockerId: a, blockedId: b },
          { blockerId: b, blockedId: a },
        ],
      },
      select: { id: true },
    });
    return block !== null;
  }

  /** Personnes que `userId` a bloquées OU qui l'ont bloqué : invisibles pour lui. */
  async blockedUserIdsEitherWay(userId: string): Promise<Set<string>> {
    const rows = await this.prisma.communityBlock.findMany({
      where: { OR: [{ blockerId: userId }, { blockedId: userId }] },
      select: { blockerId: true, blockedId: true },
    });
    return new Set(rows.map((row) => (row.blockerId === userId ? row.blockedId : row.blockerId)));
  }

  /**
   * Bloque (idempotent) et retire, d'un seul tenant, l'amitié ou la demande
   * en attente de la paire, dans les deux sens. Une ligne DECLINED, elle,
   * RESTE : le blocage la rend déjà inopérante, et le délai de 30 jours
   * qu'elle porte survit ainsi au déblocage — sinon bloquer puis débloquer
   * suffirait à contourner un refus et à faire resonner une demande.
   */
  async block(blockerId: string, blockedId: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.communityBlock.upsert({
        where: { blockerId_blockedId: { blockerId, blockedId } },
        create: { blockerId, blockedId },
        update: {},
      }),
      this.prisma.friendship.deleteMany({
        where: {
          status: { in: [FriendRequestStatus.PENDING, FriendRequestStatus.ACCEPTED] },
          OR: [
            { requesterId: blockerId, addresseeId: blockedId },
            { requesterId: blockedId, addresseeId: blockerId },
          ],
        },
      }),
    ]);
  }

  /** Idempotent : débloquer quelqu'un qui ne l'est pas aboutit sans bruit. */
  async unblock(blockerId: string, blockedId: string): Promise<void> {
    await this.prisma.communityBlock.deleteMany({ where: { blockerId, blockedId } });
  }

  /** Mes blocages, les comptes supprimés depuis exclus (plus rien à bloquer). */
  listBlocks(blockerId: string): Promise<BlockedUserRow[]> {
    return this.prisma.communityBlock.findMany({
      where: { blockerId, blocked: { deletedAt: null } },
      orderBy: { createdAt: 'desc' },
      include: { blocked: { select: { profile: { select: { displayName: true } } } } },
    });
  }

  /** Compte encore présent (un compte supprimé porte une valeur tombale). */
  async userExists(userId: string): Promise<boolean> {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      select: { id: true },
    });
    return user !== null;
  }

  // ── Encouragements ──────────────────────────────────────────────────────

  /** Supprime si `userId` en est l'auteur OU le destinataire ; sinon ne touche à rien. */
  async deleteEncouragementFor(userId: string, encouragementId: string): Promise<void> {
    await this.prisma.encouragement.deleteMany({
      where: { id: encouragementId, OR: [{ senderId: userId }, { recipientId: userId }] },
    });
  }

  // ── Signalements ────────────────────────────────────────────────────────

  /**
   * Signalement OUVERT du même auteur sur la même cible : même personne, et
   * même encouragement OU même défi (`null` compris — un signalement de la
   * personne en général n'est pas celui d'un de ses messages).
   */
  findOpenReport(
    reporterId: string,
    reportedUserId: string,
    target: Pick<CreateReportInput, 'encouragementId' | 'friendChallengeId'>,
  ): Promise<CommunityReportRow | null> {
    return this.prisma.communityReport.findFirst({
      where: {
        reporterId,
        reportedUserId,
        encouragementId: target.encouragementId,
        friendChallengeId: target.friendChallengeId,
        status: CommunityReportStatus.OPEN,
      },
      include: reportInclude,
    });
  }

  /**
   * Crée le signalement en FIGEANT le texte visé, lu dans la même
   * transaction : l'auteur pourra retirer son message, la preuve restera
   * lisible par l'administration. Si la cible n'est pas signalable par cette
   * personne (voir `snapshotOf`), rien n'est écrit et `null` est rendu.
   */
  createReport(input: CreateReportInput): Promise<CommunityReportRow | null> {
    return this.prisma.$transaction(async (tx) => {
      const snapshot = await this.snapshotOf(tx, input);
      if (snapshot === null) {
        return null;
      }
      return tx.communityReport.create({
        data: { ...input, ...snapshot },
        include: reportInclude,
      });
    });
  }

  /**
   * Les clichés à figer, lus dans la transaction du signalement — ou `null`
   * si la cible n'est pas signalable par cette personne :
   *  - un encouragement ne se signale que s'il a été REÇU de la personne
   *    signalée ;
   *  - un défi, que si le signalant en est MEMBRE (quel que soit son statut :
   *    il a pu lire le message avant de refuser) et que la personne signalée
   *    en est la CRÉATRICE — le titre et le message sont les siens.
   * Un seul `null` pour tous les refus : rien ne distingue « ce défi
   * n'existe pas » de « tu n'en es pas » ni de « il n'est pas d'elle ».
   */
  private async snapshotOf(
    tx: Prisma.TransactionClient,
    input: CreateReportInput,
  ): Promise<ReportSnapshot | null> {
    const snapshot: ReportSnapshot = {
      encouragementMessage: null,
      friendChallengeTitle: null,
      friendChallengeMessage: null,
    };
    if (input.encouragementId !== null) {
      const encouragement = await tx.encouragement.findFirst({
        where: {
          id: input.encouragementId,
          senderId: input.reportedUserId,
          recipientId: input.reporterId,
        },
        select: { message: true },
      });
      if (encouragement === null) {
        return null;
      }
      snapshot.encouragementMessage = encouragement.message;
    }
    if (input.friendChallengeId !== null) {
      const challenge = await tx.friendChallenge.findFirst({
        where: {
          id: input.friendChallengeId,
          creatorId: input.reportedUserId,
          members: { some: { userId: input.reporterId } },
        },
        select: { title: true, message: true },
      });
      if (challenge === null) {
        return null;
      }
      snapshot.friendChallengeTitle = challenge.title;
      snapshot.friendChallengeMessage = challenge.message;
    }
    return snapshot;
  }

  findReportById(id: string): Promise<CommunityReportRow | null> {
    return this.prisma.communityReport.findUnique({ where: { id }, include: reportInclude });
  }

  /**
   * Signalements du plus récent au plus ancien, pagination par curseur
   * (limit + 1). Filtres cumulables, chacun absent = pas de filtre.
   */
  listReports(
    filters: ReportFilters,
    limit: number,
    cursor?: string,
  ): Promise<CommunityReportRow[]> {
    return this.prisma.communityReport.findMany({
      where: {
        status: filters.status,
        reason: filters.reason,
        reportedUserId: filters.reportedUserId,
      },
      include: reportInclude,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor === undefined ? {} : { cursor: { id: cursor }, skip: 1 }),
    });
  }

  /**
   * Signalements reçus par chacune de ces personnes, par statut — UNE
   * requête pour toute une page, jamais une par ligne.
   */
  async reportCountsFor(
    reportedUserIds: readonly string[],
  ): Promise<Map<string, { total: number; open: number }>> {
    const counts = new Map<string, { total: number; open: number }>();
    if (reportedUserIds.length === 0) {
      return counts;
    }
    const groups = await this.prisma.communityReport.groupBy({
      by: ['reportedUserId', 'status'],
      where: { reportedUserId: { in: [...new Set(reportedUserIds)] } },
      _count: { _all: true },
    });
    for (const group of groups) {
      const entry = counts.get(group.reportedUserId) ?? { total: 0, open: 0 };
      entry.total += group._count._all;
      if (group.status === CommunityReportStatus.OPEN) {
        entry.open += group._count._all;
      }
      counts.set(group.reportedUserId, entry);
    }
    return counts;
  }

  /**
   * Résoudre SANS décision pose qui l'a fait et efface la décision
   * précédente (note, drapeaux) : elle ne doit pas s'afficher sous le nom
   * d'un autre. Rouvrir ne vide que `resolvedAt` — la décision précédente
   * reste lisible tant que personne ne résout à nouveau.
   */
  setReportStatus(
    id: string,
    status: CommunityReportStatus,
    adminUserId: string,
  ): Promise<CommunityReportRow> {
    const resolving = status === CommunityReportStatus.RESOLVED;
    return this.prisma.communityReport.update({
      where: { id },
      data: {
        status,
        resolvedAt: resolving ? new Date() : null,
        ...(resolving
          ? {
              resolvedByAdminId: adminUserId,
              resolutionNote: null,
              contentRemoved: false,
              userSuspended: false,
            }
          : {}),
      },
      include: reportInclude,
    });
  }
}
