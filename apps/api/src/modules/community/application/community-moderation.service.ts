import {
  type AdminCommunityReport,
  type BlockedUser,
  type CommunityReport as ReportContract,
  type CommunityReportReason,
  type CommunityReportStatus,
} from '@carlys/api-contracts';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditService } from '../../audit/audit.service';
import {
  CommunityModerationRepository,
  type CommunityReportRow,
} from '../infrastructure/community-moderation.repository';

export interface AdminActor {
  adminUserId: string;
  ipAddress?: string;
  requestId?: string;
}

export interface CreateReportCommand {
  reportedUserId: string;
  encouragementId?: string;
  reason: CommunityReportReason;
  details?: string;
}

export interface ReportsPage {
  items: AdminCommunityReport[];
  nextCursor: string | null;
  hasMore: boolean;
}

function presentReport(row: CommunityReportRow): ReportContract {
  return {
    id: row.id,
    reportedUserId: row.reportedUserId,
    encouragementId: row.encouragementId,
    reason: row.reason,
    details: row.details,
    status: row.status,
    createdAt: row.createdAt.toISOString(),
    resolvedAt: row.resolvedAt?.toISOString() ?? null,
  };
}

function presentAdminReport(row: CommunityReportRow): AdminCommunityReport {
  return {
    ...presentReport(row),
    reporter: {
      id: row.reporter.id,
      email: row.reporter.email,
      displayName: row.reporter.profile?.displayName ?? null,
    },
    reportedUser: {
      id: row.reportedUser.id,
      email: row.reportedUser.email,
      displayName: row.reportedUser.profile?.displayName ?? null,
    },
    // Le cliché pris au signalement, jamais le message vivant : l'auteur a pu
    // le retirer depuis, la preuve doit rester lisible.
    encouragementMessage: row.encouragementMessage,
  };
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
   * Signaler une personne, ou un encouragement précis qu'elle m'a envoyé.
   * Un signalement OUVERT identique n'est pas dupliqué : rejouer l'envoi
   * rend le même accusé de réception, l'administration ne reçoit pas de
   * doublons. Le texte visé est figé à la création (voir le dépôt).
   */
  async report(userId: string, command: CreateReportCommand): Promise<ReportContract> {
    if (command.reportedUserId === userId) {
      throw new BadRequestException('Tu ne peux pas te signaler toi-même.');
    }
    if (!(await this.moderation.userExists(command.reportedUserId))) {
      throw new NotFoundException('Compte introuvable.');
    }
    const encouragementId = command.encouragementId ?? null;
    const existing = await this.moderation.findOpenReport(
      userId,
      command.reportedUserId,
      encouragementId,
    );
    if (existing !== null) {
      return presentReport(existing);
    }
    const details = command.details?.trim();
    const created = await this.moderation.createReport({
      reporterId: userId,
      reportedUserId: command.reportedUserId,
      encouragementId,
      reason: command.reason,
      details: details === undefined || details === '' ? null : details,
    });
    if (created === null) {
      // Seul ce qu'on a REÇU de cette personne peut être signalé sous son nom.
      throw new NotFoundException('Encouragement introuvable.');
    }
    return presentReport(created);
  }

  // ── Administration ──────────────────────────────────────────────────────

  async listReports(
    status: CommunityReportStatus | undefined,
    limit: number,
    cursor?: string,
  ): Promise<ReportsPage> {
    const rows = await this.moderation.listReports(status, limit, cursor);
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit).map(presentAdminReport);
    return {
      items,
      hasMore,
      nextCursor: hasMore ? (items.at(-1)?.id ?? null) : null,
    };
  }

  /** Résoudre (ou rouvrir) un signalement — audité, idempotent sur le même statut. */
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
      return presentAdminReport(report);
    }
    const updated = await this.moderation.setReportStatus(reportId, status);
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
    return presentAdminReport(updated);
  }
}
