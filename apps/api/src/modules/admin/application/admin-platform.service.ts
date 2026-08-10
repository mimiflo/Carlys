import { type AdminAuditLog, type AdminOverview } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { type AuditLog } from '@prisma/client';
import { AdminRepository } from '../infrastructure/admin.repository';

export interface AuditPage {
  items: AdminAuditLog[];
  nextCursor: string | null;
  hasMore: boolean;
}

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

  async auditLogs(limit: number, cursor?: string): Promise<AuditPage> {
    const rows = await this.admin.listAuditLogs(limit, cursor);
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit).map(presentAuditLog);
    return {
      items,
      hasMore,
      nextCursor: hasMore ? (items.at(-1)?.id ?? null) : null,
    };
  }
}
