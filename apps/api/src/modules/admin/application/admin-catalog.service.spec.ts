import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { AdminCatalogService } from './admin-catalog.service';
import { AdminCategoriesService } from './admin-categories.service';

const ACTOR = { adminUserId: 'admin-1', ipAddress: '10.0.0.1', requestId: 'req-1' };

interface RepositoryDouble {
  softDeleteExercise: jest.Mock;
  restoreExercise: jest.Mock;
  setExercisePublication: jest.Mock;
  findExercise: jest.Mock;
  setExerciseCategories: jest.Mock;
  findMuscleGroupIdsBySlugs: jest.Mock;
  findEquipmentIdsBySlugs: jest.Mock;
  listMuscleGroups: jest.Mock;
  findMuscleGroupBySlug: jest.Mock;
  createMuscleGroup: jest.Mock;
  updateMuscleGroup: jest.Mock;
  deleteMuscleGroup: jest.Mock;
}

function exerciseRow(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: 'ex-1',
    slug: 'developpe-couche',
    name: 'Développé couché',
    isPublished: true,
    isPremium: false,
    deletedAt: null,
    muscles: [
      { role: 'PRIMARY', muscleGroup: { slug: 'pectoraux', name: 'Pectoraux' } },
      { role: 'SECONDARY', muscleGroup: { slug: 'triceps', name: 'Triceps' } },
    ],
    equipment: [{ equipment: { slug: 'barre' } }],
    image: null,
    mesh: null,
    ...overrides,
  };
}

function make(): {
  catalog: AdminCatalogService;
  categories: AdminCategoriesService;
  repository: RepositoryDouble;
  audit: { record: jest.Mock };
  exercises: { invalidateCache: jest.Mock };
} {
  const repository: RepositoryDouble = {
    softDeleteExercise: jest.fn().mockResolvedValue(true),
    restoreExercise: jest.fn().mockResolvedValue(true),
    setExercisePublication: jest.fn().mockResolvedValue(true),
    findExercise: jest.fn().mockResolvedValue(exerciseRow()),
    setExerciseCategories: jest.fn().mockResolvedValue(undefined),
    findMuscleGroupIdsBySlugs: jest.fn().mockResolvedValue([
      { id: 'mg-pec', slug: 'pectoraux' },
      { id: 'mg-tri', slug: 'triceps' },
    ]),
    findEquipmentIdsBySlugs: jest.fn().mockResolvedValue([{ id: 'eq-barre', slug: 'barre' }]),
    listMuscleGroups: jest.fn().mockResolvedValue([
      {
        id: 'mg-pec',
        slug: 'pectoraux',
        name: 'Pectoraux',
        sortOrder: 0,
        primaryExercisesCount: 3,
        exercisesCount: 5,
      },
      {
        id: 'mg-vide',
        slug: 'mollets',
        name: 'Mollets',
        sortOrder: 1,
        primaryExercisesCount: 0,
        exercisesCount: 2,
      },
    ]),
    findMuscleGroupBySlug: jest.fn().mockResolvedValue(null),
    createMuscleGroup: jest.fn().mockResolvedValue({ id: 'mg-pec' }),
    updateMuscleGroup: jest.fn().mockResolvedValue(true),
    deleteMuscleGroup: jest.fn().mockResolvedValue(true),
  };
  const audit = { record: jest.fn() };
  const exercises = { invalidateCache: jest.fn().mockResolvedValue(undefined) };
  const config = { s3PublicBaseUrl: 'http://storage.local/carlys/' };

  return {
    repository,
    audit,
    exercises,
    catalog: new AdminCatalogService(
      repository as never,
      audit as never,
      exercises as never,
      config as never,
    ),
    categories: new AdminCategoriesService(repository as never, audit as never, exercises as never),
  };
}

describe('AdminCatalogService', () => {
  it('supprime en douceur, invalide le cache et journalise', async () => {
    const { catalog, repository, audit, exercises } = make();

    await catalog.deleteExercise('ex-1', ACTOR);

    expect(repository.softDeleteExercise).toHaveBeenCalledWith('ex-1');
    expect(exercises.invalidateCache).toHaveBeenCalled();
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.exercise_deleted', resourceId: 'ex-1' }),
    );
  });

  it('refuse de supprimer deux fois', async () => {
    const { catalog, repository } = make();
    repository.softDeleteExercise.mockResolvedValue(false);

    await expect(catalog.deleteExercise('ex-1', ACTOR)).rejects.toBeInstanceOf(NotFoundException);
  });

  it('restaure un exercice supprimé', async () => {
    const { catalog, repository, audit } = make();

    await catalog.restoreExercise('ex-1', ACTOR);

    expect(repository.restoreExercise).toHaveBeenCalledWith('ex-1');
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.exercise_restored' }),
    );
  });

  it('reclasse un exercice et rend sa fiche à jour', async () => {
    const { catalog, repository } = make();

    const updated = await catalog.setExerciseCategories(
      'ex-1',
      {
        primaryMuscleGroupSlug: 'pectoraux',
        secondaryMuscleGroupSlugs: ['triceps'],
        equipmentSlugs: ['barre'],
      },
      ACTOR,
    );

    expect(repository.setExerciseCategories).toHaveBeenCalledWith(
      'ex-1',
      'mg-pec',
      ['mg-tri'],
      ['eq-barre'],
    );
    expect(updated.primaryMuscleGroupSlug).toBe('pectoraux');
    expect(updated.equipmentSlugs).toEqual(['barre']);
  });

  it('écarte le principal repris en secondaire, et les doublons', async () => {
    // Sans ce ménage, la ligne serait refusée par la clé primaire composite —
    // et la fiche afficherait deux fois le même muscle.
    const { catalog, repository } = make();

    await catalog.setExerciseCategories(
      'ex-1',
      {
        primaryMuscleGroupSlug: 'pectoraux',
        secondaryMuscleGroupSlugs: ['pectoraux', 'triceps', 'triceps'],
        equipmentSlugs: ['barre', 'barre'],
      },
      ACTOR,
    );

    expect(repository.setExerciseCategories).toHaveBeenCalledWith(
      'ex-1',
      'mg-pec',
      ['mg-tri'],
      ['eq-barre'],
    );
  });

  it('refuse un groupe musculaire inconnu', async () => {
    const { catalog, repository } = make();
    repository.findMuscleGroupIdsBySlugs.mockResolvedValue([{ id: 'mg-pec', slug: 'pectoraux' }]);

    await expect(
      catalog.setExerciseCategories(
        'ex-1',
        {
          primaryMuscleGroupSlug: 'pectoraux',
          secondaryMuscleGroupSlugs: ['licorne'],
          equipmentSlugs: [],
        },
        ACTOR,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(repository.setExerciseCategories).not.toHaveBeenCalled();
  });

  it('refuse de reclasser un exercice supprimé', async () => {
    const { catalog, repository } = make();
    repository.findExercise.mockResolvedValue(exerciseRow({ deletedAt: new Date() }));

    await expect(
      catalog.setExerciseCategories(
        'ex-1',
        {
          primaryMuscleGroupSlug: 'pectoraux',
          secondaryMuscleGroupSlugs: [],
          equipmentSlugs: [],
        },
        ACTOR,
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('AdminCategoriesService', () => {
  it('crée une catégorie et journalise', async () => {
    const { categories, repository, audit } = make();

    await categories.create({ slug: 'pectoraux', name: 'Pectoraux' }, ACTOR);

    expect(repository.createMuscleGroup).toHaveBeenCalledWith('pectoraux', 'Pectoraux', 0);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.muscle_group_created' }),
    );
  });

  it('refuse un slug déjà pris', async () => {
    const { categories, repository } = make();
    repository.findMuscleGroupBySlug.mockResolvedValue({ id: 'mg-pec' });

    await expect(
      categories.create({ slug: 'pectoraux', name: 'Pectoraux' }, ACTOR),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(repository.createMuscleGroup).not.toHaveBeenCalled();
  });

  it('refuse de supprimer une catégorie encore principale', async () => {
    // La contrainte de base est en CASCADE : sans cette garde, la suppression
    // passerait en silence et laisserait trois exercices sans muscle principal.
    const { categories, repository } = make();

    await expect(categories.remove('mg-pec', ACTOR)).rejects.toBeInstanceOf(ConflictException);
    expect(repository.deleteMuscleGroup).not.toHaveBeenCalled();
  });

  it('supprime une catégorie qui n’est principale nulle part', async () => {
    const { categories, repository, exercises } = make();

    await categories.remove('mg-vide', ACTOR);

    expect(repository.deleteMuscleGroup).toHaveBeenCalledWith('mg-vide');
    expect(exercises.invalidateCache).toHaveBeenCalled();
  });

  it('refuse une modification vide', async () => {
    const { categories } = make();

    await expect(categories.update('mg-pec', {}, ACTOR)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });
});
