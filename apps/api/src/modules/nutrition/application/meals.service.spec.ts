import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { type Food, type MealComponent, Prisma } from '@prisma/client';
import {
  ComponentIdTakenError,
  type MealsRepository,
  type MealWithComponents,
  type MealWrite,
} from '../infrastructure/meals.repository';
import { type Composition, type MealComposer } from './meal-composer';
import { type MealPhotoObjects } from './meal-photo-objects';
import { MealsService } from './meals.service';

const USER = 'utilisateur-1';
const OTHER = 'utilisateur-2';

function mealRow(overrides: Partial<MealWithComponents> = {}): MealWithComponents {
  return {
    id: 'repas-1',
    userId: USER,
    name: 'Poulet riz',
    moment: null,
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
    components: [],
    photo: null,
    ...overrides,
  };
}

/** Une ligne de composant stockée : 120 g d'un aliment à 150 kcal/100 g. */
function componentRow(overrides: Partial<MealComponent> = {}): MealComponent {
  return {
    id: 'composant-1',
    mealId: 'repas-1',
    foodCode: 990001,
    position: 0,
    quantityG: new Prisma.Decimal(120),
    foodName: 'Poulet, filet, sans peau, cuit',
    foodShortName: 'Poulet',
    foodGroup: 'viandes, œufs, poissons et assimilés',
    foodSourceVersion: '2020-07-07',
    kcalPer100g: new Prisma.Decimal(150),
    proteinPer100g: new Prisma.Decimal(29),
    carbsPer100g: new Prisma.Decimal(0),
    fatPer100g: null,
    createdAt: new Date(),
    ...overrides,
  };
}

const COMPOSITION: Composition = {
  rows: [
    {
      id: 'composant-1',
      position: 0,
      foodCode: 990001,
      foodName: 'Poulet, filet, sans peau, cuit',
      foodShortName: 'Poulet',
      foodGroup: null,
      foodSourceVersion: '2020-07-07',
      kcalPer100g: new Prisma.Decimal(150),
      proteinPer100g: new Prisma.Decimal(29),
      carbsPer100g: new Prisma.Decimal(0),
      fatPer100g: null,
      quantityG: new Prisma.Decimal(120),
    },
  ],
  totals: {
    kcal: 180,
    proteinG: 35,
    carbsG: 0,
    fatG: null,
    quantityG: new Prisma.Decimal(120),
  },
};

/** L'aliment 990001 de la base : 150 kcal, 29 g de protéines, 0 g de glucides pour 100 g. */
const POULET: Food = {
  code: 990001,
  name: 'Poulet, filet, sans peau, cuit',
  shortName: 'Poulet',
  groupCode: '04',
  groupName: null,
  subgroupCode: null,
  subgroupName: null,
  kcalPer100g: new Prisma.Decimal(150),
  proteinPer100g: new Prisma.Decimal(29),
  carbsPer100g: new Prisma.Decimal(0),
  fatPer100g: null,
  searchKey: 'poulet filet sans peau cuit',
  sourceVersion: '2020-07-07',
  retiredAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

interface Stubs {
  create: jest.Mock;
  findById: jest.Mock;
  listBetween: jest.Mock;
  correct: jest.Mock;
  softDelete: jest.Mock;
  compose: jest.Mock;
  catalogFor: jest.Mock;
  discard: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    create: jest.fn().mockResolvedValue(undefined),
    findById: jest.fn().mockResolvedValue(null),
    listBetween: jest.fn().mockResolvedValue([]),
    correct: jest.fn().mockResolvedValue(null),
    softDelete: jest.fn().mockResolvedValue(null),
    compose: jest.fn().mockResolvedValue(COMPOSITION),
    catalogFor: jest.fn().mockResolvedValue(new Map([[POULET.code, POULET]])),
    discard: jest.fn().mockResolvedValue(undefined),
  };
}

function buildService(stubs: Stubs): MealsService {
  return new MealsService(
    stubs as unknown as MealsRepository,
    { compose: stubs.compose, catalogFor: stubs.catalogFor } as unknown as MealComposer,
    { discard: stubs.discard } as unknown as MealPhotoObjects,
  );
}

/**
 * `MealsRepository.correct` simulé : la décision est prise sur `current`,
 * l'état « relu sous verrou », et chaque écriture décidée est consignée.
 * `null` : le repas n'existe pas.
 */
function lockedOn(stubs: Stubs, current: MealWithComponents | null): MealWrite[] {
  const writes: MealWrite[] = [];
  // `async` : une exception de `decide` devient un rejet, comme dans la
  // transaction qu'elle annule.
  stubs.correct.mockImplementation(
    async (_id: string, decide: (meal: MealWithComponents) => MealWrite) => {
      await Promise.resolve();
      if (current === null) {
        return null;
      }
      writes.push(decide(current));
      return current;
    },
  );
  return writes;
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
    stubs.findById.mockResolvedValueOnce(null).mockResolvedValue(mealRow());
    const service = buildService(stubs);

    const meal = await service.add(USER, input);

    expect(meal).toEqual({
      id: 'repas-1',
      name: 'Poulet riz',
      moment: null,
      kcal: 650,
      quantity: null,
      quantityUnit: null,
      proteinG: 45,
      carbsG: 80,
      fatG: 12,
      eatenAt: '2026-08-11T12:00:00.000Z',
      components: [],
      computed: false,
      photo: null,
    });
  });

  it('expose la date de la photo (clé de cache du client), jamais sa clé de stockage', async () => {
    const stubs = buildStubs();
    stubs.findById.mockResolvedValue(
      mealRow({ photo: { updatedAt: new Date('2026-09-25T08:00:00Z') } }),
    );
    const service = buildService(stubs);

    const meal = await service.get(USER, 'repas-1');

    expect(meal.photo).toEqual({ updatedAt: '2026-09-25T08:00:00.000Z' });
  });

  it('enregistre le moment de la journée', async () => {
    const stubs = buildStubs();
    stubs.findById.mockResolvedValueOnce(null).mockResolvedValue(mealRow({ moment: 'DINNER' }));
    const service = buildService(stubs);

    const meal = await service.add(USER, { ...input, moment: 'DINNER' });

    expect(stubs.create).toHaveBeenCalledWith(expect.objectContaining({ moment: 'DINNER' }), []);
    expect(meal.moment).toBe('DINNER');
  });

  it('refuse un repas saisi à la main sans calories', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await expect(service.add(USER, { ...input, kcal: undefined })).rejects.toThrow(/calories/);
    expect(stubs.create).not.toHaveBeenCalled();
  });

  describe('composition', () => {
    const composed = {
      id: 'repas-1',
      name: 'Poulet',
      eatenAt: new Date('2026-08-11T12:00:00Z'),
      components: [{ id: 'composant-1', foodCode: 990001, quantityG: 120 }],
    };

    it('calcule les totaux côté serveur et écrit l’instantané avec le repas', async () => {
      const stubs = buildStubs();
      stubs.findById
        .mockResolvedValueOnce(null)
        .mockResolvedValue(
          mealRow({ kcal: 180, components: [componentRow()], quantityUnit: 'GRAM' }),
        );
      const service = buildService(stubs);

      const meal = await service.add(USER, composed);

      expect(stubs.compose).toHaveBeenCalledWith(composed.components);
      expect(stubs.create).toHaveBeenCalledWith(
        expect.objectContaining({
          kcal: 180,
          proteinG: 35,
          carbsG: 0,
          fatG: null,
          quantity: new Prisma.Decimal(120),
          quantityUnit: 'GRAM',
        }),
        COMPOSITION.rows,
      );
      expect(meal.computed).toBe(true);
      // Les valeurs DU composant, recalculées depuis l'instantané.
      expect(meal.components).toEqual([
        {
          id: 'composant-1',
          foodCode: 990001,
          name: 'Poulet, filet, sans peau, cuit',
          shortName: 'Poulet',
          group: 'viandes, œufs, poissons et assimilés',
          sourceVersion: '2020-07-07',
          quantityG: 120,
          kcal: 180,
          proteinG: 34.8,
          carbsG: 0,
          fatG: null,
        },
      ]);
    });

    it('un REJEU rend le repas déjà écrit sans recomposer (aliment retiré depuis)', async () => {
      const stubs = buildStubs();
      stubs.findById.mockResolvedValue(mealRow({ components: [componentRow()] }));
      stubs.compose.mockRejectedValue(new BadRequestException('aliment retiré de la base'));
      const service = buildService(stubs);

      const meal = await service.add(USER, composed);

      expect(meal.computed).toBe(true);
      expect(stubs.compose).not.toHaveBeenCalled();
      expect(stubs.create).not.toHaveBeenCalled();
    });

    it('refuse des aliments ACCOMPAGNÉS de totaux, avant même de lire la base', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      await expect(service.add(USER, { ...composed, kcal: 500 })).rejects.toBeInstanceOf(
        BadRequestException,
      );
      await expect(service.add(USER, { ...composed, quantity: null })).rejects.toThrow(/quantity/);
      expect(stubs.compose).not.toHaveBeenCalled();
      expect(stubs.create).not.toHaveBeenCalled();
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

    await expect(service.add(USER, input)).rejects.toThrow('Identifiant de repas déjà utilisé.');
  });

  it('une ligne dont l’identifiant est pris ailleurs : 409 qui nomme la ligne, pas le repas', async () => {
    const stubs = buildStubs();
    // L'écriture a buté sur un identifiant pris (ignorée par `create`), et
    // le repas reste introuvable : c'est celui d'une ligne.
    stubs.findById.mockResolvedValue(null);
    const service = buildService(stubs);

    await expect(
      service.add(USER, {
        id: 'repas-1',
        name: 'Copie',
        eatenAt: new Date('2026-08-11T12:00:00Z'),
        components: [{ id: 'ligne-prise', foodCode: 990001, quantityG: 120 }],
      }),
    ).rejects.toThrow(/identifiant de ligne d’aliment est déjà pris/);
  });

  describe('correction', () => {
    it('ne touche QUE ce qu’on lui donne, et décide sur l’état relu SOUS VERROU', async () => {
      const stubs = buildStubs();
      const writes = lockedOn(stubs, mealRow());
      const service = buildService(stubs);

      await service.update(USER, 'repas-1', { kcal: 700 });

      // Corriger les calories ne doit pas emporter les macros avec elles :
      // ce que l'objet d'écriture ne mentionne pas, Prisma ne l'écrase pas.
      // Et sans `components`, la composition n'est pas touchée.
      expect(writes).toEqual([{ data: { kcal: 700 } }]);
      // Aucune lecture HORS verrou : c'est elle qui pouvait être périmée.
      expect(stubs.findById).not.toHaveBeenCalled();
    });

    it('distingue « n’y touche pas » de « efface »', async () => {
      const stubs = buildStubs();
      const writes = lockedOn(stubs, mealRow());
      const service = buildService(stubs);

      await service.update(USER, 'repas-1', { proteinG: null, carbsG: undefined });

      // `null` EFFACE (on ne sait plus), `undefined` CONSERVE. Les confondre
      // reviendrait à effacer tout ce qui n'est pas renvoyé à chaque
      // correction.
      expect(writes).toEqual([{ data: { proteinG: null } }]);
    });

    it('refuse un corps entièrement vide', async () => {
      const stubs = buildStubs();
      lockedOn(stubs, mealRow());
      const service = buildService(stubs);

      await expect(service.update(USER, 'repas-1', {})).rejects.toBeInstanceOf(BadRequestException);
      // Le repas n'a même pas été lu : rien à corriger, rien à faire.
      expect(stubs.correct).not.toHaveBeenCalled();
    });

    it('juge la paire sur l’état APRÈS correction, pas sur le fragment', async () => {
      const stubs = buildStubs();
      const writes = lockedOn(
        stubs,
        mealRow({ quantity: new Prisma.Decimal('2'), quantityUnit: 'PORTION' }),
      );
      const service = buildService(stubs);

      // Effacer la seule unité laisserait « 2 » tout seul en base, ce
      // qu'aucun écran ne sait afficher.
      await expect(service.update(USER, 'repas-1', { quantityUnit: null })).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(writes).toEqual([]);

      // Effacer les DEUX est légitime : l'entrée redevient sans quantité.
      await expect(
        service.update(USER, 'repas-1', { quantity: null, quantityUnit: null }),
      ).resolves.toBeDefined();
    });

    it('ne corrige pas à la main les totaux d’un repas COMPOSÉ', async () => {
      const stubs = buildStubs();
      const writes = lockedOn(stubs, mealRow({ components: [componentRow()] }));
      const service = buildService(stubs);

      await expect(service.update(USER, 'repas-1', { kcal: 700 })).rejects.toThrow(
        /retire d’abord sa composition/,
      );
      // Le nom, le moment et l'heure, eux, se corrigent librement.
      await service.update(USER, 'repas-1', { name: 'Dîner', moment: null });
      expect(writes).toEqual([{ data: { name: 'Dîner', moment: null } }]);
    });

    it('des totaux renvoyés À L’IDENTIQUE ne sont pas une correction (client déjà publié)', async () => {
      const stubs = buildStubs();
      const current = mealRow({
        components: [componentRow()],
        kcal: 180,
        proteinG: 35,
        carbsG: 0,
        fatG: null,
        quantity: new Prisma.Decimal(120),
        quantityUnit: 'GRAM',
      });
      const writes = lockedOn(stubs, current);
      const service = buildService(stubs);
      const everything = {
        name: 'Renommé',
        kcal: 180,
        proteinG: 35,
        carbsG: 0,
        fatG: null,
        quantity: 120,
        quantityUnit: 'GRAM' as const,
        eatenAt: current.eatenAt,
      };

      await service.update(USER, 'repas-1', everything);
      // Seul ce qui DÉCRIT le repas s'écrit ; ses totaux calculés, non.
      expect(writes).toEqual([{ data: { name: 'Renommé', eatenAt: current.eatenAt } }]);

      await expect(service.update(USER, 'repas-1', { ...everything, fatG: 4 })).rejects.toThrow(
        /fatG/,
      );
    });

    it('retirer la composition garde les derniers totaux, et rend la main', async () => {
      const stubs = buildStubs();
      const writes = lockedOn(
        stubs,
        mealRow({
          components: [componentRow()],
          quantity: new Prisma.Decimal(120),
          quantityUnit: 'GRAM',
        }),
      );
      const service = buildService(stubs);

      await service.update(USER, 'repas-1', { components: [] });
      await service.update(USER, 'repas-1', { components: [], kcal: 200 });

      // Aucun total dans la première écriture : ceux du repas restent tels quels.
      expect(writes).toEqual([
        { data: {}, components: [] },
        { data: { kcal: 200 }, components: [] },
      ]);
    });

    it('une nouvelle composition remplace l’ancienne et recalcule tout', async () => {
      const stubs = buildStubs();
      const writes = lockedOn(stubs, mealRow());
      const service = buildService(stubs);
      const components = [{ id: 'ligne-neuve', foodCode: 990001, quantityG: 120 }];

      await service.update(USER, 'repas-1', { components, name: 'Poulet' });

      // La base se lit AVANT le verrou, le calcul se fait dessous.
      expect(stubs.catalogFor).toHaveBeenCalledWith(components);
      expect(writes[0]?.data).toMatchObject({
        name: 'Poulet',
        kcal: 180,
        proteinG: 35,
        fatG: null,
        quantityUnit: 'GRAM',
      });
      expect(writes[0]?.components).toEqual([
        expect.objectContaining({ id: 'ligne-neuve', position: 0, foodCode: 990001 }),
      ]);
      await expect(service.update(USER, 'repas-1', { components, proteinG: 10 })).rejects.toThrow(
        /proteinG/,
      );
    });

    it('des aliments ET des totaux : refusé avant toute lecture', async () => {
      const stubs = buildStubs();
      lockedOn(stubs, mealRow());
      const service = buildService(stubs);

      await expect(
        service.update(USER, 'repas-1', {
          components: [{ id: 'ligne', foodCode: 990001, quantityG: 120 }],
          kcal: 500,
        }),
      ).rejects.toThrow(/n’envoie pas kcal/);
      expect(stubs.catalogFor).not.toHaveBeenCalled();
      expect(stubs.correct).not.toHaveBeenCalled();
    });

    it('un identifiant de ligne déjà pris par un autre repas : 409, pas 500', async () => {
      const stubs = buildStubs();
      stubs.correct.mockRejectedValue(new ComponentIdTakenError());
      const service = buildService(stubs);

      await expect(
        service.update(USER, 'repas-1', {
          components: [{ id: 'ligne', foodCode: 990001, quantityG: 120 }],
        }),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('corriger le repas d’autrui, inconnu ou supprimé répond 404', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      lockedOn(stubs, null);
      await expect(service.update(USER, 'inconnu', { kcal: 700 })).rejects.toBeInstanceOf(
        NotFoundException,
      );

      const foreign = lockedOn(stubs, mealRow({ userId: OTHER }));
      await expect(service.update(USER, 'repas-1', { kcal: 700 })).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(foreign).toEqual([]);

      const deleted = lockedOn(stubs, mealRow({ deletedAt: new Date() }));
      await expect(service.update(USER, 'repas-1', { kcal: 700 })).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(deleted).toEqual([]);
    });
  });

  it('lire un repas : le sien seulement, et vivant', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await expect(service.get(USER, 'inconnu')).rejects.toBeInstanceOf(NotFoundException);
    stubs.findById.mockResolvedValue(mealRow({ userId: OTHER }));
    await expect(service.get(USER, 'repas-1')).rejects.toBeInstanceOf(NotFoundException);
    stubs.findById.mockResolvedValue(mealRow({ deletedAt: new Date() }));
    await expect(service.get(USER, 'repas-1')).rejects.toBeInstanceOf(NotFoundException);
    stubs.findById.mockResolvedValue(mealRow({ moment: 'LUNCH' }));
    await expect(service.get(USER, 'repas-1')).resolves.toMatchObject({ moment: 'LUNCH' });
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

  it('supprimer un repas efface sa photo, APRÈS la suppression douce', async () => {
    const stubs = buildStubs();
    stubs.findById.mockResolvedValue(mealRow());
    const order: string[] = [];
    stubs.softDelete.mockImplementation(() => {
      order.push('suppression douce');
      return Promise.resolve('meal-photos/utilisateur-1/photo.jpg');
    });
    stubs.discard.mockImplementation(() => {
      order.push('objet effacé');
      return Promise.resolve();
    });
    const service = buildService(stubs);

    await service.remove(USER, 'repas-1', 'requete-42');

    expect(order).toEqual(['suppression douce', 'objet effacé']);
    // Le requestId accompagne l'effacement : c'est lui qui corrèle un échec
    // journalisé à la requête qui l'a provoqué.
    expect(stubs.discard).toHaveBeenCalledWith('meal-photos/utilisateur-1/photo.jpg', 'requete-42');
  });

  it('supprimer un repas SANS photo ne touche pas au stockage', async () => {
    const stubs = buildStubs();
    stubs.findById.mockResolvedValue(mealRow());
    const service = buildService(stubs);

    await service.remove(USER, 'repas-1', 'requete-42');

    expect(stubs.softDelete).toHaveBeenCalledWith('repas-1');
    expect(stubs.discard).not.toHaveBeenCalled();
  });
});
