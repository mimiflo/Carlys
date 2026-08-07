import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { ExerciseDifficulty, ExerciseMuscleRole, ExerciseType } from '@prisma/client';
import { type CacheService } from '../../../infrastructure/cache/cache.service';
import { type EntitlementsService } from '../../subscriptions/application/entitlements.service';
import {
  type ExercisesRepository,
  type ExerciseWithRelations,
} from '../infrastructure/exercises.repository';
import { ExercisesService } from './exercises.service';

const USER = 'user-1';

function exerciseRow(id: string, name: string): ExerciseWithRelations {
  return {
    id,
    slug: name.toLowerCase().replace(/\s+/g, '-'),
    name,
    description: `Description de ${name}`,
    instructions: ['Étape 1', 'Étape 2'],
    difficulty: ExerciseDifficulty.BEGINNER,
    type: ExerciseType.STRENGTH,
    isPremium: false,
    isPublished: true,
    tags: ['test'],
    createdAt: new Date(),
    updatedAt: new Date(),
    muscles: [
      {
        exerciseId: id,
        muscleGroupId: 'mg-1',
        role: ExerciseMuscleRole.PRIMARY,
        muscleGroup: {
          id: 'mg-1',
          slug: 'pectoraux',
          name: 'Pectoraux',
          sortOrder: 0,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      },
    ],
    equipment: [],
  };
}

interface Stubs {
  repository: {
    listPage: jest.Mock;
    findPublishedByIdOrSlug: jest.Mock;
    listMuscleGroups: jest.Mock;
    listEquipment: jest.Mock;
  };
  cache: { getJson: jest.Mock; setJson: jest.Mock; invalidatePrefix: jest.Mock };
  entitlements: { hasEntitlement: jest.Mock };
}

function buildStubs(): Stubs {
  return {
    repository: {
      listPage: jest.fn().mockResolvedValue([]),
      findPublishedByIdOrSlug: jest.fn().mockResolvedValue(null),
      listMuscleGroups: jest.fn().mockResolvedValue([]),
      listEquipment: jest.fn().mockResolvedValue([]),
    },
    cache: {
      getJson: jest.fn().mockResolvedValue(null),
      setJson: jest.fn().mockResolvedValue(undefined),
      invalidatePrefix: jest.fn().mockResolvedValue(undefined),
    },
    entitlements: {
      hasEntitlement: jest.fn().mockResolvedValue(false),
    },
  };
}

function buildService(stubs: Stubs): ExercisesService {
  return new ExercisesService(
    stubs.repository as unknown as ExercisesRepository,
    stubs.cache as unknown as CacheService,
    stubs.entitlements as unknown as EntitlementsService,
  );
}

describe('ExercisesService', () => {
  it('pagination : limit+1 lignes → hasMore et nextCursor sur le dernier élément servi', async () => {
    const stubs = buildStubs();
    stubs.repository.listPage.mockResolvedValue([
      exerciseRow('id-1', 'Curl'),
      exerciseRow('id-2', 'Dips'),
      exerciseRow('id-3', 'Squat'),
    ]);
    const service = buildService(stubs);

    const page = await service.list({}, 2);

    expect(page.items).toHaveLength(2);
    expect(page.hasMore).toBe(true);
    expect(page.nextCursor).toBe('id-2');
    expect(stubs.repository.listPage).toHaveBeenCalledWith({}, 2, undefined);
  });

  it('dernière page : pas de nextCursor', async () => {
    const stubs = buildStubs();
    stubs.repository.listPage.mockResolvedValue([exerciseRow('id-9', 'Planche')]);
    const service = buildService(stubs);

    const page = await service.list({}, 2, 'id-2');

    expect(page.items).toHaveLength(1);
    expect(page.hasMore).toBe(false);
    expect(page.nextCursor).toBeNull();
  });

  it('cache hit : la base n’est pas interrogée', async () => {
    const stubs = buildStubs();
    const cached = { items: [], hasMore: false, nextCursor: null };
    stubs.cache.getJson.mockResolvedValue(cached);
    const service = buildService(stubs);

    const page = await service.list({ search: 'squat' }, 20);

    expect(page).toBe(cached);
    expect(stubs.repository.listPage).not.toHaveBeenCalled();
    expect(stubs.cache.setJson).not.toHaveBeenCalled();
  });

  it('cache miss : le résultat est mis en cache avec un TTL', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.list({}, 20);

    expect(stubs.cache.setJson).toHaveBeenCalledWith(
      expect.stringContaining('catalog:exercises:'),
      expect.objectContaining({ items: [] }),
      300,
    );
  });

  it('des filtres différents produisent des clés de cache différentes', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.list({ search: 'squat' }, 20);
    await service.list({ muscleGroupSlug: 'dos' }, 20);

    const keys = stubs.cache.setJson.mock.calls.map((call: unknown[]) => call[0]);
    expect(new Set(keys).size).toBe(2);
  });

  it('détail introuvable ou non publié → 404', async () => {
    const service = buildService(buildStubs());

    await expect(service.detail('inconnu', USER)).rejects.toThrow(NotFoundException);
  });

  it('détail : présente muscles et instructions, puis met en cache', async () => {
    const stubs = buildStubs();
    stubs.repository.findPublishedByIdOrSlug.mockResolvedValue(exerciseRow('id-1', 'Squat'));
    const service = buildService(stubs);

    const detail = await service.detail('squat', USER);

    expect(detail.primaryMuscleGroup?.slug).toBe('pectoraux');
    expect(detail.instructions).toHaveLength(2);
    expect(stubs.cache.setJson).toHaveBeenCalledWith(
      'catalog:exercise:squat',
      expect.objectContaining({ id: 'id-1' }),
      3_600,
    );
  });

  it('exercice premium : refusé sans entitlement, servi avec (décision serveur)', async () => {
    const stubs = buildStubs();
    stubs.repository.findPublishedByIdOrSlug.mockResolvedValue({
      ...exerciseRow('id-1', 'Squat bulgare'),
      isPremium: true,
    });
    const service = buildService(stubs);

    await expect(service.detail('squat-bulgare', USER)).rejects.toThrow(ForbiddenException);

    stubs.entitlements.hasEntitlement.mockResolvedValue(true);
    const detail = await service.detail('squat-bulgare', USER);
    expect(detail.isPremium).toBe(true);
    expect(stubs.entitlements.hasEntitlement).toHaveBeenCalledWith(USER, 'premium_exercises');
  });

  it('la décision premium est réévaluée même sur un cache hit', async () => {
    const stubs = buildStubs();
    stubs.cache.getJson.mockResolvedValue({ id: 'id-1', isPremium: true });
    const service = buildService(stubs);

    await expect(service.detail('squat-bulgare', USER)).rejects.toThrow(ForbiddenException);
    expect(stubs.repository.findPublishedByIdOrSlug).not.toHaveBeenCalled();
  });

  it('référentiels servis depuis le cache quand disponible', async () => {
    const stubs = buildStubs();
    stubs.cache.getJson.mockResolvedValue([{ id: 'mg-1', slug: 'dos', name: 'Dos' }]);
    const service = buildService(stubs);

    const groups = await service.muscleGroups();

    expect(groups).toHaveLength(1);
    expect(stubs.repository.listMuscleGroups).not.toHaveBeenCalled();
  });
});
