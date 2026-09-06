import { Injectable } from '@nestjs/common';
import {
  type CommunityBlock,
  type CommunityReportReason,
  CommunityReportStatus,
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

const reportInclude = {
  reporter: { select: reportPartySelect },
  reportedUser: { select: reportPartySelect },
  encouragement: { select: { message: true } },
} satisfies Prisma.CommunityReportInclude;

export type CommunityReportRow = Prisma.CommunityReportGetPayload<{
  include: typeof reportInclude;
}>;

export interface CreateReportInput {
  reporterId: string;
  reportedUserId: string;
  encouragementId: string | null;
  reason: CommunityReportReason;
  details: string | null;
}

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
   * Bloque (idempotent) et retire, d'un seul tenant, l'amitié et les
   * demandes en attente dans les deux sens : une seule ligne par paire,
   * quel que soit son statut.
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

  /** L'encouragement `id` a-t-il bien été envoyé par `senderId` à `recipientId` ? */
  async encouragementExistsBetween(
    id: string,
    senderId: string,
    recipientId: string,
  ): Promise<boolean> {
    const row = await this.prisma.encouragement.findFirst({
      where: { id, senderId, recipientId },
      select: { id: true },
    });
    return row !== null;
  }

  // ── Signalements ────────────────────────────────────────────────────────

  /** Signalement OUVERT du même auteur sur la même cible (et le même message). */
  findOpenReport(
    reporterId: string,
    reportedUserId: string,
    encouragementId: string | null,
  ): Promise<CommunityReportRow | null> {
    return this.prisma.communityReport.findFirst({
      where: { reporterId, reportedUserId, encouragementId, status: CommunityReportStatus.OPEN },
      include: reportInclude,
    });
  }

  createReport(input: CreateReportInput): Promise<CommunityReportRow> {
    return this.prisma.communityReport.create({ data: input, include: reportInclude });
  }

  findReportById(id: string): Promise<CommunityReportRow | null> {
    return this.prisma.communityReport.findUnique({ where: { id }, include: reportInclude });
  }

  /** Signalements du plus récent au plus ancien, pagination par curseur (limit + 1). */
  listReports(
    status: CommunityReportStatus | undefined,
    limit: number,
    cursor?: string,
  ): Promise<CommunityReportRow[]> {
    return this.prisma.communityReport.findMany({
      where: status === undefined ? {} : { status },
      include: reportInclude,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor === undefined ? {} : { cursor: { id: cursor }, skip: 1 }),
    });
  }

  setReportStatus(id: string, status: CommunityReportStatus): Promise<CommunityReportRow> {
    return this.prisma.communityReport.update({
      where: { id },
      data: { status, resolvedAt: status === CommunityReportStatus.RESOLVED ? new Date() : null },
      include: reportInclude,
    });
  }
}
