import { type AdminMuscleGroup, type Equipment } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditService } from '../../audit/audit.service';
import { ExercisesService } from '../../exercises/application/exercises.service';
import { AdminRepository } from '../infrastructure/admin.repository';
import { type CatalogActor } from './admin-catalog.service';

/** Catégories du catalogue — les groupes musculaires, créés et retirés ici. */
@Injectable()
export class AdminCategoriesService {
  constructor(
    private readonly admin: AdminRepository,
    private readonly audit: AuditService,
    private readonly exercises: ExercisesService,
  ) {}

  list(): Promise<AdminMuscleGroup[]> {
    return this.admin.listMuscleGroups();
  }

  /**
   * Référentiel des MATÉRIELS.
   *
   * Doublé ici plutôt que réutilisé depuis la route mobile `/equipment` :
   * celle-ci exige un jeton d'utilisateur, et les jetons admin et mobiles ne
   * sont jamais interchangeables — c'est même une règle vérifiée en e2e.
   */
  listEquipment(): Promise<Equipment[]> {
    return this.admin.listEquipment();
  }

  async create(
    input: { slug: string; name: string; sortOrder?: number },
    actor: CatalogActor,
  ): Promise<AdminMuscleGroup> {
    const existing = await this.admin.findMuscleGroupBySlug(input.slug);
    if (existing !== null) {
      throw new ConflictException(`Une catégorie porte déjà le slug « ${input.slug} ».`);
    }
    const created = await this.admin.createMuscleGroup(
      input.slug,
      input.name,
      input.sortOrder ?? 0,
    );
    await this.after('admin.muscle_group_created', created.id, actor);
    const group = (await this.admin.listMuscleGroups()).find((row) => row.id === created.id);
    if (group === undefined) {
      throw new NotFoundException('Catégorie introuvable.');
    }
    return group;
  }

  async update(
    id: string,
    input: { name?: string; sortOrder?: number },
    actor: CatalogActor,
  ): Promise<void> {
    if (input.name === undefined && input.sortOrder === undefined) {
      throw new BadRequestException('Rien à modifier.');
    }
    const updated = await this.admin.updateMuscleGroup(id, input);
    if (!updated) {
      throw new NotFoundException('Catégorie introuvable.');
    }
    await this.after('admin.muscle_group_updated', id, actor);
  }

  /**
   * Supprime une catégorie — sauf si elle est le groupe PRINCIPAL d'un
   * exercice vivant.
   *
   * La contrainte de base est en cascade : sans cette garde, la suppression
   * passerait en silence et laisserait ces exercices sans muscle principal,
   * donc introuvables dans une bibliothèque qui se parcourt par groupe.
   */
  async remove(id: string, actor: CatalogActor): Promise<void> {
    const group = (await this.admin.listMuscleGroups()).find((row) => row.id === id);
    if (group === undefined) {
      throw new NotFoundException('Catégorie introuvable.');
    }
    if (group.primaryExercisesCount > 0) {
      throw new ConflictException(
        `« ${group.name} » est le groupe principal de ${group.primaryExercisesCount} ` +
          'exercice(s) : reclassez-les avant de supprimer la catégorie.',
      );
    }
    const removed = await this.admin.deleteMuscleGroup(id);
    if (!removed) {
      throw new NotFoundException('Catégorie introuvable.');
    }
    await this.after('admin.muscle_group_deleted', id, actor);
  }

  private async after(action: string, groupId: string, actor: CatalogActor): Promise<void> {
    await this.exercises.invalidateCache();
    this.audit.record({
      action,
      actorType: 'ADMIN',
      adminUserId: actor.adminUserId,
      resourceType: 'muscle_group',
      resourceId: groupId,
      requestId: actor.requestId,
      ipAddress: actor.ipAddress,
    });
  }
}
