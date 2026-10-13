import { Injectable } from '@nestjs/common';
import { CommunityReportStatus, type Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { type CommunityReportRow, reportInclude } from './community-moderation.repository';

/** Le contenu qu'une décision retire : un encouragement, ou le mot d'un défi. */
export type RemovableContent =
  { kind: 'encouragement'; id: string } | { kind: 'friend_challenge'; id: string };

export interface DecisionInput {
  reportId: string;
  adminUserId: string;
  note: string | null;
  /** `null` : rien à retirer. */
  content: RemovableContent | null;
  userSuspended: boolean;
}

export type DecisionOutcome =
  | { kind: 'decided'; report: CommunityReportRow; siblingReportIds: string[] }
  | { kind: 'already_resolved' }
  | { kind: 'nothing_to_remove' };

/** Annule la transaction : Prisma la défait sur toute exception levée dedans. */
class DecisionAborted extends Error {
  constructor(readonly outcome: 'already_resolved' | 'nothing_to_remove') {
    super(outcome);
  }
}

/** La décision de modération, d'un seul tenant : résoudre ET retirer, ou rien. */
@Injectable()
export class ModerationDecisionRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Résout le signalement s'il est encore OUVERT, puis, si un contenu est à
   * retirer : résout aussi les AUTRES signalements ouverts du même contenu
   * (même décision), et le retire. Les signalements frères se lisent AVANT
   * le retrait : supprimer un encouragement met leur référence à NULL.
   * Rien n'est écrit si le signalement n'est plus ouvert ou si le contenu
   * n'existe plus.
   */
  async decide(input: DecisionInput): Promise<DecisionOutcome> {
    const resolution = {
      status: CommunityReportStatus.RESOLVED,
      resolvedAt: new Date(),
      resolvedByAdminId: input.adminUserId,
      resolutionNote: input.note,
      contentRemoved: input.content !== null,
      userSuspended: input.userSuspended,
    } satisfies Prisma.CommunityReportUncheckedUpdateManyInput;
    try {
      return await this.prisma.$transaction(async (tx) => {
        const claimed = await tx.communityReport.updateMany({
          where: { id: input.reportId, status: CommunityReportStatus.OPEN },
          data: resolution,
        });
        if (claimed.count === 0) {
          throw new DecisionAborted('already_resolved');
        }
        let siblingReportIds: string[] = [];
        if (input.content !== null) {
          siblingReportIds = await this.resolveSiblings(
            tx,
            input.reportId,
            input.content,
            resolution,
          );
          if (!(await this.removeContent(tx, input.content))) {
            throw new DecisionAborted('nothing_to_remove');
          }
        }
        const report = await tx.communityReport.findUniqueOrThrow({
          where: { id: input.reportId },
          include: reportInclude,
        });
        return { kind: 'decided' as const, report, siblingReportIds };
      });
    } catch (error) {
      if (error instanceof DecisionAborted) {
        return { kind: error.outcome };
      }
      throw error;
    }
  }

  /** Les signalements frères résolus, par identifiant (l'audit les cite). */
  private async resolveSiblings(
    tx: Prisma.TransactionClient,
    reportId: string,
    content: RemovableContent,
    resolution: Prisma.CommunityReportUncheckedUpdateManyInput,
  ): Promise<string[]> {
    const target =
      content.kind === 'encouragement'
        ? { encouragementId: content.id }
        : { friendChallengeId: content.id };
    const siblings = await tx.communityReport.findMany({
      where: { ...target, status: CommunityReportStatus.OPEN, id: { not: reportId } },
      select: { id: true },
    });
    const ids = siblings.map((sibling) => sibling.id);
    if (ids.length > 0) {
      await tx.communityReport.updateMany({ where: { id: { in: ids } }, data: resolution });
    }
    return ids;
  }

  /**
   * La suspension, faite APRÈS la décision, a échoué : les signalements
   * tranchés ne prétendent plus l'avoir faite.
   */
  async clearSuspension(reportIds: readonly string[]): Promise<void> {
    await this.prisma.communityReport.updateMany({
      where: { id: { in: [...reportIds] } },
      data: { userSuspended: false },
    });
  }

  /**
   * Un encouragement se SUPPRIME (comme quand son auteur le retire) ; un
   * défi perd son mot, daté, et garde son titre, ses membres, ses scores.
   * `false` : il n'y avait plus rien à retirer.
   */
  private async removeContent(
    tx: Prisma.TransactionClient,
    content: RemovableContent,
  ): Promise<boolean> {
    if (content.kind === 'encouragement') {
      const { count } = await tx.encouragement.deleteMany({ where: { id: content.id } });
      return count > 0;
    }
    const { count } = await tx.friendChallenge.updateMany({
      where: { id: content.id, message: { not: null } },
      data: { message: null, messageRemovedAt: new Date() },
    });
    return count > 0;
  }
}
