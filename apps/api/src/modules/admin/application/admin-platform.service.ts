import { type AdminAuditLog, type AdminOverview } from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { type AuditLog } from '@prisma/client';
import { AuditService } from '../../audit/audit.service';
import { ExercisesService } from '../../exercises/application/exercises.service';
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

/** Synthèse, journal d'audit et modération du catalogue. */
@Injectable()
export class AdminPlatformService {
  constructor(
    private readonly admin: AdminRepository,
    private readonly audit: AuditService,
    private readonly exercises: ExercisesService,
  ) {}

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

  /** Publication/dépublication d'un exercice + invalidation du cache catalogue. */
  async setExercisePublication(
    exerciseId: string,
    isPublished: boolean,
    actor: { adminUserId: string; ipAddress?: string; requestId?: string },
  ): Promise<void> {
    const updated = await this.admin.setExercisePublication(exerciseId, isPublished);
    if (!updated) {
      throw new NotFoundException('Exercice introuvable.');
    }
    await this.exercises.invalidateCache();
    this.audit.record({
      action: isPublished ? 'admin.exercise_published' : 'admin.exercise_unpublished',
      actorType: 'ADMIN',
      adminUserId: actor.adminUserId,
      resourceType: 'exercise',
      resourceId: exerciseId,
      requestId: actor.requestId,
      ipAddress: actor.ipAddress,
    });
  }
}
