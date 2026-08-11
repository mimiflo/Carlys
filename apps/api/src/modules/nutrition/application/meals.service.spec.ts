import { ConflictException, NotFoundException } from '@nestjs/common';
import { type MealEntry } from '@prisma/client';
import { type MealsRepository } from '../infrastructure/meals.repository';
import { MealsService } from './meals.service';

const USER = 'utilisateur-1';
const OTHER = 'utilisateur-2';

function mealRow(overrides: Partial<MealEntry> = {}): MealEntry {
  return {
    id: 'repas-1',
    userId: USER,
    name: 'Poulet riz',
    kcal: 650,
    proteinG: 45,
    eatenAt: new Date('2026-08-11T12:00:00Z'),
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
    ...overrides,
  };
}

interface Stubs {
  create: jest.Mock;
  findById: jest.Mock;
  listBetween: jest.Mock;
  softDelete: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    create: jest.fn().mockResolvedValue(undefined),
    findById: jest.fn().mockResolvedValue(null),
    listBetween: jest.fn().mockResolvedValue([]),
    softDelete: jest.fn().mockResolvedValue(undefined),
  };
}

function buildService(stubs: Stubs): MealsService {
  return new MealsService(stubs as unknown as MealsRepository);
}

const input = {
  id: 'repas-1',
  name: 'Poulet riz',
  kcal: 650,
  proteinG: 45,
  eatenAt: new Date('2026-08-11T12:00:00Z'),
};

describe('MealsService', () => {
  it('rend l’entrée stockée après création', async () => {
    const stubs = buildStubs();
    stubs.findById.mockResolvedValue(mealRow());
    const service = buildService(stubs);

    const meal = await service.add(USER, input);

    expect(meal).toEqual({
      id: 'repas-1',
      name: 'Poulet riz',
      kcal: 650,
      proteinG: 45,
      eatenAt: '2026-08-11T12:00:00.000Z',
    });
  });

  it('un identifiant appartenant à AUTRUI est un conflit, pas un vol', async () => {
    const stubs = buildStubs();
    stubs.findById.mockResolvedValue(mealRow({ userId: OTHER }));
    const service = buildService(stubs);

    await expect(service.add(USER, input)).rejects.toBeInstanceOf(ConflictException);
  });

  it('supprimer un repas inconnu ou déjà supprimé aboutit sans bruit', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await expect(service.remove(USER, 'repas-inconnu')).resolves.toBeUndefined();
    expect(stubs.softDelete).not.toHaveBeenCalled();

    stubs.findById.mockResolvedValue(mealRow({ deletedAt: new Date() }));
    await expect(service.remove(USER, 'repas-1')).resolves.toBeUndefined();
    expect(stubs.softDelete).not.toHaveBeenCalled();
  });

  it('supprimer le repas d’autrui répond comme un 404', async () => {
    const stubs = buildStubs();
    stubs.findById.mockResolvedValue(mealRow({ userId: OTHER }));
    const service = buildService(stubs);

    await expect(service.remove(USER, 'repas-1')).rejects.toBeInstanceOf(NotFoundException);
    expect(stubs.softDelete).not.toHaveBeenCalled();
  });
});
