import { Prisma } from '@prisma/client';
import { type CiqualFood } from './ciqual-parse';
import { isMassRetirement, planFoodSync } from './ciqual-sync';

const d = (value: number): Prisma.Decimal => new Prisma.Decimal(value);

function incoming(code: number, kcal = 100): CiqualFood {
  return {
    code,
    name: `Aliment ${code}, cuit`,
    shortName: `Aliment ${code}`,
    searchKey: `aliment ${code} cuit`,
    groupCode: '04',
    groupName: 'viandes, œufs, poissons et assimilés',
    subgroupCode: null,
    subgroupName: null,
    kcalPer100g: d(kcal),
    proteinPer100g: d(20),
    carbsPer100g: null,
    fatPer100g: d(0),
  };
}

function stored(
  code: number,
  overrides: { kcal?: number; version?: string; retiredAt?: Date | null } = {},
) {
  return {
    ...incoming(code, overrides.kcal ?? 100),
    sourceVersion: overrides.version ?? '2020-07-07',
    retiredAt: overrides.retiredAt ?? null,
  };
}

describe('planFoodSync', () => {
  it('première version : tout est créé', () => {
    const plan = planFoodSync([], [incoming(1), incoming(2)], '2020-07-07');
    expect(plan.toCreate.map((row) => row.code)).toEqual([1, 2]);
    expect(plan.toCreate[0]?.sourceVersion).toBe('2020-07-07');
    expect(plan).toMatchObject({ toUpdate: [], toReactivate: [], toRetire: [], unchanged: 0 });
  });

  it('la même version rejouée ne change RIEN (idempotence)', () => {
    const plan = planFoodSync([stored(1), stored(2)], [incoming(1), incoming(2)], '2020-07-07');
    expect(plan).toMatchObject({ toCreate: [], toUpdate: [], toReactivate: [], toRetire: [] });
    expect(plan.unchanged).toBe(2);
  });

  it('compare les décimaux par valeur, pas par représentation', () => {
    const existing = { ...stored(1), kcalPer100g: new Prisma.Decimal('100.00') };
    expect(planFoodSync([existing], [incoming(1)], '2020-07-07').unchanged).toBe(1);
  });

  it('une valeur ou une version qui change : mise à jour', () => {
    const plan = planFoodSync(
      [stored(1), stored(2)],
      [incoming(1, 105), incoming(2)],
      '2020-07-07',
    );
    expect(plan.toUpdate.map((row) => row.code)).toEqual([1]);
    const bumped = planFoodSync([stored(1)], [incoming(1)], '2099-01-01');
    expect(bumped.toUpdate.map((row) => row.code)).toEqual([1]);
  });

  it('un aliment disparu est RETIRÉ, jamais supprimé ; un retiré qui revient est réactivé', () => {
    const plan = planFoodSync(
      [
        stored(1),
        stored(2),
        stored(3, { retiredAt: new Date() }),
        stored(4, { retiredAt: new Date() }),
      ],
      [incoming(1), incoming(3)],
      '2020-07-07',
    );
    expect(plan.toRetire).toEqual([2]);
    expect(plan.toReactivate.map((row) => row.code)).toEqual([3]);
    // Déjà retiré et toujours absent : rien à faire, ni à compter.
    expect(plan.toRetire).not.toContain(4);
  });
});

describe('isMassRetirement', () => {
  const base = [stored(1), stored(2), stored(3), stored(4), stored(5, { retiredAt: new Date() })];

  it('au-delà d’un quart des aliments EN SERVICE retirés d’un coup : c’est suspect', () => {
    // 4 en service ; en retirer 2, c'est la moitié.
    const plan = planFoodSync(base, [incoming(1), incoming(2)], '2020-07-07');
    expect(plan.activeBefore).toBe(4);
    expect(isMassRetirement(plan)).toBe(true);
  });

  it('un retrait ordinaire, ou une base vide, ne l’est pas', () => {
    const plan = planFoodSync(base, [incoming(1), incoming(2), incoming(3)], '2020-07-07');
    expect(plan.toRetire).toEqual([4]);
    expect(isMassRetirement(plan)).toBe(false);
    expect(isMassRetirement(planFoodSync([], [incoming(1)], '2020-07-07'))).toBe(false);
  });
});
