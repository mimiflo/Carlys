import {
  type AdminCommunityReport,
  type AdminCommunityReportFilters,
  type BlockedUser,
  type CommunityReport as ReportContract,
  type CommunityReportReason,
  type CommunityReportStatus,
} from '@carlys/api-contracts';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { blankToNull } from '../../../common/utilities/blank-to-null';
import { type AdminActor, AuditService } from '../../audit/audit.service';
import { CommunityModerationRepository } from '../infrastructure/community-moderation.repository';
import {
  presentAdminReport,
  presentOneAdminReport,
  presentReport,
} from './community-report.presenter';
import { type CursorPage, cursorPage } from '../../../common/utilities/cursor-page';

export interface CreateReportCommand {
  reportedUserId: string;
  /** `null` et absent disent la même chose : pas de cible de ce type. */
  encouragementId?: string | null;
  friendChallengeId?: string | null;
  reason: CommunityReportReason;
  details?: string;
}

/**
 * Modération de la communauté : blocages (unilatéraux, opaques), retrait
 * d'un encouragement par l'auteur ou le destinataire, signalements lus et
 * résolus par l'administration.
 */
@Injectable()
export class CommunityModerationService {
  constructor(
    private readonly moderation: CommunityModerationRepository,
    private readonly audit: AuditService,
  ) {}

  // ── Blocages ────────────────────────────────────────────────────────────

  /**
   * Bloquer retire l'amitié et les demandes en attente dans les deux sens.
   * L'autre n'est jamais prévenu : pour lui, ce compte n'existe plus.
   */
  async block(userId: string, targetId: string): Promise<void> {
    if (targetId === userId) {
      throw new BadRequestException('Tu ne peux pas te bloquer toi-même.');
    }
    if (!(await this.moderation.userExists(targetId))) {
      throw new NotFoundException('Compte introuvable.');
    }
    await this.moderation.block(userId, targetId);
  }

  /** Débloquer ne rétablit ni l'amitié ni les demandes : tout repart de zéro. */
  unblock(userId: string, targetId: string): Promise<void> {
    return this.moderation.unblock(userId, targetId);
  }

  async listBlocks(userId: string): Promise<BlockedUser[]> {
    const rows = await this.moderation.listBlocks(userId);
    return rows.map((row) => ({
      userId: row.blockedId,
      displayName: row.blocked.profile?.displayName ?? 'Membre Carlys',
      blockedAt: row.createdAt.toISOString(),
    }));
  }

  // ── Encouragements ──────────────────────────────────────────────────────

  /**
   * L'auteur retire ce qu'il a écrit, le destinataire retire ce qu'il ne
   * veut plus lire. Rejouable et OPAQUE : un identifiant inconnu, ou celui
   * du message de quelqu'un d'autre, aboutit pareil sans rien toucher.
   */
  deleteEncouragement(userId: string, encouragementId: string): Promise<void> {
    return this.moderation.deleteEncouragementFor(userId, encouragementId);
  }

  // ── Signalements ────────────────────────────────────────────────────────

  /**
   * Signaler une personne, un encouragement précis qu'elle m'a envoyé, ou un
   * défi entre amis qu'elle a créé et dont je suis membre — un encouragement
   * OU un défi, jamais les deux. Un signalement OUVERT identique n'est pas
   * dupliqué : rejouer l'envoi rend le même accusé de réception,
   * l'administration ne reçoit pas de doublons. Le texte visé est figé à la
   * création (voir le dépôt).
   */
  async report(userId: string, command: CreateReportCommand): Promise<ReportContract> {
    // Normalisée d'abord : `@IsOptional` laisse passer un `null` explicite,
    // qui dit « pas de cible » comme une clé absente.
    const target = {
      encouragementId: command.encouragementId ?? null,
      friendChallengeId: command.friendChallengeId ?? null,
    };
    if (target.encouragementId !== null && target.friendChallengeId !== null) {
      throw new BadRequestException('Signale un encouragement OU un défi, pas les deux à la fois.');
    }
    if (command.reportedUserId === userId) {
      throw new BadRequestException('Tu ne peux pas te signaler toi-même.');
    }
    if (!(await this.moderation.userExists(command.reportedUserId))) {
      throw new NotFoundException('Compte introuvable.');
    }
    const existing = await this.moderation.findOpenReport(userId, command.reportedUserId, target);
    if (existing !== null) {
      return presentReport(existing);
    }
    const created = await this.moderation.createReport({
      reporterId: userId,
      reportedUserId: command.reportedUserId,
      ...target,
      reason: command.reason,
      details: blankToNull(command.details),
    });
    if (created === null) {
      // Seul ce qu'on a REÇU de cette personne, ou un défi qu'elle a lancé et
      // où l'on figure, peut être signalé sous son nom. Le message est celui
      // d'un défi introuvable, sans dire lequel des refus s'applique.
      throw new NotFoundException(
        target.friendChallengeId === null ? 'Encouragement introuvable.' : 'Défi introuvable.',
      );
    }
    return presentReport(created);
  }

  // ── Administration ──────────────────────────────────────────────────────

  async listReports(
    filters: AdminCommunityReportFilters & { status?: CommunityReportStatus },
    limit: number,
    cursor?: string,
  ): Promise<CursorPage<AdminCommunityReport>> {
    const rows = await this.moderation.listReports(filters, limit, cursor);
    const counts = await this.moderation.reportCountsFor(rows.map((row) => row.reportedUserId));
    return cursorPage(rows, limit, (row) =>
      presentAdminReport(row, counts.get(row.reportedUserId)),
    );
  }

  /**
   * Résoudre (ou rouvrir) un signalement SANS décision — audité, idempotent
   * sur le même statut. Résoudre pose l'administrateur ; rouvrir garde la
   * décision précédente comme historique.
   */
  async setReportStatus(
    reportId: string,
    status: CommunityReportStatus,
    actor: AdminActor,
  ): Promise<AdminCommunityReport> {
    const report = await this.moderation.findReportById(reportId);
    if (report === null) {
      throw new NotFoundException('Signalement introuvable.');
    }
    if (report.status === status) {
      return presentOneAdminReport(this.moderation, report);
    }
    const updated = await this.moderation.setReportStatus(reportId, status, actor.adminUserId);
    this.audit.record({
      action:
        status === 'RESOLVED'
          ? 'admin.community_report_resolved'
          : 'admin.community_report_reopened',
      actorType: 'ADMIN',
      adminUserId: actor.adminUserId,
      userId: report.reportedUserId,
      resourceType: 'community_report',
      resourceId: reportId,
      requestId: actor.requestId,
      ipAddress: actor.ipAddress,
      metadata: { reason: report.reason, reporterId: report.reporterId },
    });
    return presentOneAdminReport(this.moderation, updated);
  }
}
