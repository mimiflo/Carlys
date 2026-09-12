/**
 * Ce que ces tests protègent : l'ATOMICITÉ par exercice.
 *
 * Les liaisons muscles/équipements sont reconstruites par suppression puis
 * recréation. Hors transaction, une interruption entre les deux laisse un
 * exercice publié SANS groupe musculaire — servi tel quel par l'API, et le
 * groupe disparaît des filtres, qui n'exposent que les groupes non vides.
 * Le chargement du catalogue étant devenu une étape automatique de chaque
 * déploiement, cette fenêtre s'ouvrirait très souvent : on prouve donc ici
 * qu'aucune écriture de liaison n'a lieu hors d'une transaction, plutôt que
 * de l'affirmer en commentaire.
 */
import { EQUIPMENT, EXERCISES, MUSCLE_GROUPS } from './catalog-data';
import { mustGet, syncCatalog } from './catalog-sync';
import type { PrismaClient } from '@prisma/client';

interface Trace {
  readonly appel: string;
  /** `true` si l'appel est passé par le client de transaction. */
  readonly dansTransaction: boolean;
}

/**
 * Un faux Prisma qui note chaque écriture et si elle a eu lieu dans une
 * transaction. `$transaction` exécute le rappel immédiatement avec un client
 * dont les méthodes sont marquées — c'est exactement ce qu'on veut vérifier.
 */
function fauxPrisma(): { client: PrismaClient; traces: Trace[]; transactions: number } {
  const traces: Trace[] = [];
  const etat = { transactions: 0 };

  const ecriture = (appel: string, dansTransaction: boolean) => {
    return jest.fn(() => {
      traces.push({ appel, dansTransaction });
      return Promise.resolve(
        appel === 'exercise.upsert' ? { id: `id-${traces.length}` } : { count: 0 },
      );
    });
  };

  const modeles = (dansTransaction: boolean) => ({
    muscleGroup: {
      upsert: ecriture('muscleGroup.upsert', dansTransaction),
      findMany: jest.fn(() =>
        Promise.resolve(MUSCLE_GROUPS.map((g) => ({ id: `mg-${g.slug}`, slug: g.slug }))),
      ),
    },
    equipment: {
      upsert: ecriture('equipment.upsert', dansTransaction),
      findMany: jest.fn(() =>
        Promise.resolve(EQUIPMENT.map((e) => ({ id: `eq-${e.slug}`, slug: e.slug }))),
      ),
    },
    exercise: { upsert: ecriture('exercise.upsert', dansTransaction) },
    exerciseMuscle: {
      deleteMany: ecriture('exerciseMuscle.deleteMany', dansTransaction),
      createMany: ecriture('exerciseMuscle.createMany', dansTransaction),
    },
    exerciseEquipment: {
      deleteMany: ecriture('exerciseEquipment.deleteMany', dansTransaction),
      createMany: ecriture('exerciseEquipment.createMany', dansTransaction),
    },
  });

  const racine = modeles(false);
  const client = {
    ...racine,
    $transaction: jest.fn(async (rappel: (tx: unknown) => Promise<unknown>) => {
      etat.transactions += 1;
      return rappel(modeles(true));
    }),
  };

  return {
    client: client as unknown as PrismaClient,
    traces,
    get transactions() {
      return etat.transactions;
    },
  };
}

describe('syncCatalog', () => {
  it('écrit chaque exercice et ses liaisons dans UNE transaction', async () => {
    const faux = fauxPrisma();

    const resume = await syncCatalog(faux.client);

    expect(resume).toEqual({
      muscleGroups: MUSCLE_GROUPS.length,
      equipment: EQUIPMENT.length,
      exercises: EXERCISES.length,
    });
    // Une transaction par exercice, ni plus ni moins.
    expect(faux.transactions).toBe(EXERCISES.length);
  });

  it('ne reconstruit AUCUNE liaison hors transaction', async () => {
    const faux = fauxPrisma();

    await syncCatalog(faux.client);

    const liaisonsHorsTransaction = faux.traces.filter(
      (t) => !t.dansTransaction && t.appel.startsWith('exercise'),
    );
    expect(liaisonsHorsTransaction).toEqual([]);

    // Et chaque exercice a bien ses quatre écritures de liaison + son upsert.
    const dedans = faux.traces.filter((t) => t.dansTransaction);
    expect(dedans).toHaveLength(EXERCISES.length * 5);
  });

  it('projette groupes et matériels avant de lire leurs identifiants', async () => {
    const faux = fauxPrisma();

    await faux.client.muscleGroup.findMany();
    await syncCatalog(faux.client);

    const upserts = faux.traces.filter((t) => t.appel === 'muscleGroup.upsert');
    expect(upserts).toHaveLength(MUSCLE_GROUPS.length);
    // Les groupes sont upsertés AVANT la première écriture d'exercice.
    const premierExercice = faux.traces.findIndex((t) => t.appel === 'exercise.upsert');
    const dernierGroupe = faux.traces.map((t) => t.appel).lastIndexOf('muscleGroup.upsert');
    expect(dernierGroupe).toBeLessThan(premierExercice);
  });
});

describe('mustGet', () => {
  it('rend la valeur quand le slug existe', () => {
    expect(mustGet(new Map([['dos', 'id-dos']]), 'dos')).toBe('id-dos');
  });

  it('refuse un slug inconnu plutôt que de rendre undefined', () => {
    expect(() => mustGet(new Map(), 'inconnu')).toThrow(/slug inconnu/);
  });
});
