import {
  type AdminExerciseSummary,
  type MediaAsset,
  type SetExerciseCategoriesInput,
} from '@carlys/api-contracts';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { AuditService } from '../../audit/audit.service';
import { ExercisesService } from '../../exercises/application/exercises.service';
import { type AdminExerciseRow, AdminRepository } from '../infrastructure/admin.repository';

/** Auteur d'une action de catalogue, tel que le journal d'audit le retient. */
export interface CatalogActor {
  adminUserId: string;
  ipAddress?: string;
  requestId?: string;
}

export interface AdminExercisePage {
  items: AdminExerciseSummary[];
  nextCursor: string | null;
  hasMore: boolean;
}

/**
 * Le CATALOGUE vu du back-office : lister, publier, supprimer, reclasser.
 *
 * Séparé d'`AdminPlatformService`, qui garde la synthèse et le journal : les
 * deux n'ont ni les mêmes permissions ni le même rythme d'évolution, et le
 * fichier réuni dépassait la taille tenable.
 */
@Injectable()
export class AdminCatalogService {
  constructor(
    private readonly admin: AdminRepository,
    private readonly audit: AuditService,
    private readonly exercises: ExercisesService,
    private readonly config: AppConfigService,
  ) {}

  async listExercises(
    limit: number,
    search?: string,
    cursor?: string,
    includeDeleted = false,
  ): Promise<AdminExercisePage> {
    const rows = await this.admin.listExercises(search, limit, cursor, includeDeleted);
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit).map((row) => this.presentExercise(row));
    return { items, hasMore, nextCursor: hasMore ? (items.at(-1)?.id ?? null) : null };
  }

  /** Publication/dépublication + invalidation du cache catalogue. */
  async setExercisePublication(
    exerciseId: string,
    isPublished: boolean,
    actor: CatalogActor,
  ): Promise<void> {
    const updated = await this.admin.setExercisePublication(exerciseId, isPublished);
    if (!updated) {
      throw new NotFoundException('Exercice introuvable.');
    }
    await this.afterCatalogChange(
      isPublished ? 'admin.exercise_published' : 'admin.exercise_unpublished',
      exerciseId,
      actor,
    );
  }

  /**
   * Retire un exercice du catalogue.
   *
   * Suppression DOUCE : les séries déjà réalisées, les records et les modèles
   * de séance le citent. L'effacer pour de bon trouerait l'historique de gens
   * qui n'ont rien demandé — et l'opération serait irréversible.
   */
  async deleteExercise(exerciseId: string, actor: CatalogActor): Promise<void> {
    const deleted = await this.admin.softDeleteExercise(exerciseId);
    if (!deleted) {
      throw new NotFoundException('Exercice introuvable ou déjà supprimé.');
    }
    await this.afterCatalogChange('admin.exercise_deleted', exerciseId, actor);
  }

  /** Remet un exercice supprimé — dépublié : sa republication se décide. */
  async restoreExercise(exerciseId: string, actor: CatalogActor): Promise<void> {
    const restored = await this.admin.restoreExercise(exerciseId);
    if (!restored) {
      throw new NotFoundException('Exercice introuvable ou déjà en place.');
    }
    await this.afterCatalogChange('admin.exercise_restored', exerciseId, actor);
  }

  /** Remplace en bloc les groupes musculaires et matériels d'un exercice. */
  async setExerciseCategories(
    exerciseId: string,
    input: SetExerciseCategoriesInput,
    actor: CatalogActor,
  ): Promise<AdminExerciseSummary> {
    const exercise = await this.admin.findExercise(exerciseId);
    if (exercise === null || exercise.deletedAt !== null) {
      throw new NotFoundException('Exercice introuvable.');
    }

    // Le principal n'est pas repris en secondaire : la fiche afficherait deux
    // fois le même muscle, et la contrainte d'unicité refuserait la ligne.
    const secondaries = [...new Set(input.secondaryMuscleGroupSlugs)].filter(
      (slug) => slug !== input.primaryMuscleGroupSlug,
    );
    const equipmentSlugs = [...new Set(input.equipmentSlugs)];

    const groups = await this.admin.findMuscleGroupIdsBySlugs([
      input.primaryMuscleGroupSlug,
      ...secondaries,
    ]);
    const byGroupSlug = new Map(groups.map((group) => [group.slug, group.id]));
    const primaryId = byGroupSlug.get(input.primaryMuscleGroupSlug);
    if (primaryId === undefined) {
      throw new BadRequestException(`Groupe musculaire inconnu : ${input.primaryMuscleGroupSlug}.`);
    }
    const missingGroup = secondaries.find((slug) => !byGroupSlug.has(slug));
    if (missingGroup !== undefined) {
      throw new BadRequestException(`Groupe musculaire inconnu : ${missingGroup}.`);
    }

    const equipment = await this.admin.findEquipmentIdsBySlugs(equipmentSlugs);
    const byEquipmentSlug = new Map(equipment.map((item) => [item.slug, item.id]));
    const missingEquipment = equipmentSlugs.find((slug) => !byEquipmentSlug.has(slug));
    if (missingEquipment !== undefined) {
      throw new BadRequestException(`Matériel inconnu : ${missingEquipment}.`);
    }

    await this.admin.setExerciseCategories(
      exerciseId,
      primaryId,
      secondaries.map((slug) => byGroupSlug.get(slug) as string),
      equipmentSlugs.map((slug) => byEquipmentSlug.get(slug) as string),
    );
    await this.afterCatalogChange('admin.exercise_categories_updated', exerciseId, actor);

    const updated = await this.admin.findExercise(exerciseId);
    if (updated === null) {
      throw new NotFoundException('Exercice introuvable.');
    }
    return this.presentExercise(updated);
  }

  private async afterCatalogChange(
    action: string,
    exerciseId: string,
    actor: CatalogActor,
  ): Promise<void> {
    // Sans invalidation, la modification attendrait l'expiration du cache.
    await this.exercises.invalidateCache();
    this.audit.record({
      action,
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
      primaryMuscleGroupSlug: primary?.muscleGroup.slug ?? null,
      muscleGroupSlugs: row.muscles.map((link) => link.muscleGroup.slug),
      equipmentSlugs: row.equipment.map((link) => link.equipment.slug),
      deletedAt: row.deletedAt?.toISOString() ?? null,
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
