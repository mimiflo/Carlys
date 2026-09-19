import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { Prisma, type MealEntry } from '@prisma/client';
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
    quantity: null,
    quantityUnit: null,
    proteinG: 45,
    carbsG: 80,
    fatG: 12,
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
  update: jest.Mock;
  softDelete: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    create: jest.fn().mockResolvedValue(undefined),
    findById: jest.fn().mockResolvedValue(null),
    listBetween: jest.fn().mockResolvedValue([]),
    update: jest.fn().mockImplementation(() => Promise.resolve(mealRow())),
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
  quantity: null,
  quantityUnit: null,
  proteinG: 45,
  // Les trois macros sont INDÉPENDANTES : celle qu'on ne connaît pas reste
  // nulle, et l'entrée est acceptée quand même.
  carbsG: 80,
  fatG: null,
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
      quantity: null,
      quantityUnit: null,
      proteinG: 45,
      carbsG: 80,
      fatG: 12,
      eatenAt: '2026-08-11T12:00:00.000Z',
    });
  });

  it('rend la quantité en NOMBRE, pas en Decimal sérialisé', async () => {
    const stubs = buildStubs();
    stubs.findById.mockResolvedValue(
      mealRow({ quantity: new Prisma.Decimal('250.50'), quantityUnit: 'GRAM' }),
    );
    const service = buildService(stubs);

    const meal = await service.add(USER, { ...input, quantity: 250.5, quantityUnit: 'GRAM' });

    // Un `Decimal` traversant JSON devient la CHAÎNE « 250.5 », que le
    // contrat (`z.number()`) refuse : le client ne verrait alors aucune
    // quantité là où il en existe une.
    expect(meal.quantity).toBe(250.5);
    expect(typeof meal.quantity).toBe('number');
    expect(meal.quantityUnit).toBe('GRAM');
  });

  it('refuse une quantité sans unité, et une unité sans quantité', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await expect(service.add(USER, { ...input, quantity: 250 })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(service.add(USER, { ...input, quantityUnit: 'GRAM' })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    // Rien n'a été écrit : la paire se vérifie AVANT la base.
    expect(stubs.create).not.toHaveBeenCalled();
  });

  it('un identifiant appartenant à AUTRUI est un conflit, pas un vol', async () => {
    const stubs = buildStubs();
    stubs.findById.mockResolvedValue(mealRow({ userId: OTHER }));
    const service = buildService(stubs);

    await expect(service.add(USER, input)).rejects.toBeInstanceOf(ConflictException);
  });

  describe('correction', () => {
    it('ne touche QUE ce qu’on lui donne', async () => {
      const stubs = buildStubs();
      stubs.findById.mockResolvedValue(mealRow());
      const service = buildService(stubs);

      await service.update(USER, 'repas-1', { kcal: 700 });

      // Corriger les calories ne doit pas emporter les macros avec elles :
      // ce que l'objet d'écriture ne mentionne pas, Prisma ne l'écrase pas.
      expect(stubs.update).toHaveBeenCalledWith('repas-1', { kcal: 700 });
    });

    it('distingue « n’y touche pas » de « efface »', async () => {
      const stubs = buildStubs();
      stubs.findById.mockResolvedValue(mealRow());
      const service = buildService(stubs);

      await service.update(USER, 'repas-1', { proteinG: null, carbsG: undefined });

      // `null` EFFACE (on ne sait plus), `undefined` CONSERVE. Les confondre
      // reviendrait à effacer tout ce qui n'est pas renvoyé à chaque
      // correction.
      expect(stubs.update).toHaveBeenCalledWith('repas-1', { proteinG: null });
    });

    it('refuse un corps entièrement vide', async () => {
      const stubs = buildStubs();
      stubs.findById.mockResolvedValue(mealRow());
      const service = buildService(stubs);

      await expect(service.update(USER, 'repas-1', {})).rejects.toBeInstanceOf(BadRequestException);
      // Le repas n'a même pas été lu : rien à corriger, rien à faire.
      expect(stubs.findById).not.toHaveBeenCalled();
    });

    it('juge la paire sur l’état APRÈS correction, pas sur le fragment', async () => {
      const stubs = buildStubs();
      stubs.findById.mockResolvedValue(
        mealRow({ quantity: new Prisma.Decimal('2'), quantityUnit: 'PORTION' }),
      );
      const service = buildService(stubs);

      // Effacer la seule unité laisserait « 2 » tout seul en base, ce
      // qu'aucun écran ne sait afficher.
      await expect(service.update(USER, 'repas-1', { quantityUnit: null })).rejects.toBeInstanceOf(
        BadRequestException,
      );

      // Effacer les DEUX est légitime : l'entrée redevient sans quantité.
      await expect(
        service.update(USER, 'repas-1', { quantity: null, quantityUnit: null }),
      ).resolves.toBeDefined();
    });

    it('corriger le repas d’autrui, inconnu ou supprimé répond 404', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await expect(service.update(USER, 'inconnu', { kcal: 700 })).rejects.toBeInstanceOf(
        NotFoundException,
      );

      stubs.findById.mockResolvedValue(mealRow({ userId: OTHER }));
      await expect(service.update(USER, 'repas-1', { kcal: 700 })).rejects.toBeInstanceOf(
        NotFoundException,
      );

      stubs.findById.mockResolvedValue(mealRow({ deletedAt: new Date() }));
      await expect(service.update(USER, 'repas-1', { kcal: 700 })).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(stubs.update).not.toHaveBeenCalled();
    });
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
