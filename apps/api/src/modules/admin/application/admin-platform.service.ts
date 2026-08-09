import {
  type AdminAuditLog,
  type AdminExerciseSummary,
  type AdminOverview,
  type MediaAsset,
} from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { type AuditLog } from '@prisma/client';
import { AuditService } from '../../audit/audit.service';
import { ExercisesService } from '../../exercises/application/exercises.service';
import { AppConfigService } from '../../../config/app-config.service';
import { type AdminExerciseRow, AdminRepository } from '../infrastructure/admin.repository';

export interface AuditPage {
  items: AdminAuditLog[];
  nextCursor: string | null;
  hasMore: boolean;
}

export interface AdminExercisePage {
  items: AdminExerciseSummary[];
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
    private readonly config: AppConfigService,
  ) {}

  async listExercises(limit: number, search?: string, cursor?: string): Promise<AdminExercisePage> {
    const rows = await this.admin.listExercises(search, limit, cursor);
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit).map((row) => this.presentExercise(row));
    return {
      items,
      hasMore,
      nextCursor: hasMore ? (items.at(-1)?.id ?? null) : null,
    };
  }

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

  /**
   * Le média est rendu ENTIER (nom du fichier, dimensions, poids), pas réduit
   * à son URL comme côté mobile : l'écran d'administration doit pouvoir dire
   * quel fichier est rattaché, sinon on ne remplace jamais la bonne photo.
   */
  private presentExercise(row: AdminExerciseRow): AdminExerciseSummary {
    const primary = row.muscles.find((link) => link.role === 'PRIMARY');
    return {
      id: row.id,
      slug: row.slug,
      name: row.name,
      isPublished: row.isPublished,
      isPremium: row.isPremium,
      primaryMuscleGroupName: primary?.muscleGroup.name ?? null,
      image: this.presentMedia(row.image),
      mesh: this.presentMedia(row.mesh),
    };
  }

  private presentMedia(media: AdminExerciseRow['image']): MediaAsset | null {
    if (media === null || media.deletedAt !== null) return null;
    const base = this.config.s3PublicBaseUrl.replace(/\/+$/, '');
    return {
      id: media.id,
      kind: media.kind,
      url: `${base}/${media.storageKey}`,
      mimeType: media.mimeType,
      byteSize: media.byteSize,
      width: media.width,
      height: media.height,
      originalName: media.originalName,
      createdAt: media.createdAt.toISOString(),
    };
  }
}
