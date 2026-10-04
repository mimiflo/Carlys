import { type AdminAuditLog, type AdminOverview } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { type AuditLog } from '@prisma/client';
import { AdminRepository } from '../infrastructure/admin.repository';
import { type CursorPage, cursorPage } from '../../../common/utilities/cursor-page';

function presentAuditLog(log: AuditLog): AdminAuditLog {
  return {
    id: log.id,
    actorType: log.actorType,
    action: log.action,
    userId: log.userId,
    adminUserId: log.adminUserId,
    resourceType: log.resourceType,
    resourceId: log.resourceId,
    ipAddress: log.ipAddress,
    metadata: log.metadata,
    createdAt: log.createdAt.toISOString(),
  };
}

/** Synthèse de la plateforme et journal d'audit. */
@Injectable()
export class AdminPlatformService {
  constructor(private readonly admin: AdminRepository) {}

  overview(): Promise<AdminOverview> {
    return this.admin.overview();
  }

  async auditLogs(limit: number, cursor?: string): Promise<CursorPage<AdminAuditLog>> {
    const rows = await this.admin.listAuditLogs(limit, cursor);
    return cursorPage(rows, limit, presentAuditLog);
  }
}
