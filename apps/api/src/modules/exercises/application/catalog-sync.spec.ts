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
/** Fait échouer UNE écriture, pour éprouver le chemin d'erreur. */
interface Panne {
  readonly appel: string;
  /** Rang de l'appel qui doit échouer (1 = le premier). */
  readonly occurrence: number;
}

function fauxPrisma(panne?: Panne): {
  client: PrismaClient;
  traces: Trace[];
  transactions: number;
  transactionsAnnulees: number;
} {
  const traces: Trace[] = [];
  const etat = { transactions: 0, annulees: 0 };
  const compteur = new Map<string, number>();

  const ecriture = (appel: string, dansTransaction: boolean) => {
    return jest.fn(() => {
      const rang = (compteur.get(appel) ?? 0) + 1;
      compteur.set(appel, rang);
      if (panne !== undefined && panne.appel === appel && panne.occurrence === rang) {
        return Promise.reject(new Error(`panne simulée sur ${appel}`));
      }
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
    // Imite ce qui compte d'une transaction : le rappel s'exécute, et son
    // REJET remonte après avoir compté une annulation. Un faux `$transaction`
    // qui avale l'erreur laisserait passer un `catch {}` posé dans le code de
    // production — c'est précisément ce que le test « propage » vérifie.
    $transaction: jest.fn(async (rappel: (tx: unknown) => Promise<unknown>) => {
      etat.transactions += 1;
      try {
        return await rappel(modeles(true));
      } catch (erreur) {
        etat.annulees += 1;
        throw erreur;
      }
    }),
  };

  return {
    client: client as unknown as PrismaClient,
    traces,
    get transactions() {
      return etat.transactions;
    },
    get transactionsAnnulees() {
      return etat.annulees;
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

    await syncCatalog(faux.client);

    const upserts = faux.traces.filter((t) => t.appel === 'muscleGroup.upsert');
    expect(upserts).toHaveLength(MUSCLE_GROUPS.length);
    // Les groupes sont upsertés AVANT la première écriture d'exercice.
    const premierExercice = faux.traces.findIndex((t) => t.appel === 'exercise.upsert');
    const dernierGroupe = faux.traces.map((t) => t.appel).lastIndexOf('muscleGroup.upsert');
    expect(dernierGroupe).toBeLessThan(premierExercice);
  });

  // Compter les écritures ne suffit pas : leur ORDRE est ce qui rend la
  // reconstruction correcte. Une suppression jouée APRÈS la création laisserait
  // l'exercice sans aucune liaison — la panne même que la transaction est
  // censée rendre impossible — sans changer ni le nombre d'appels ni leur
  // routage.
  it('supprime les liaisons AVANT de les recréer, exercice par exercice', async () => {
    const faux = fauxPrisma();

    await syncCatalog(faux.client);

    const liaisons = faux.traces
      .map((t) => t.appel)
      .filter((appel) => appel.startsWith('exercise') && appel !== 'exercise.upsert');
    expect(liaisons).toHaveLength(EXERCISES.length * 4);

    // Le motif attendu se répète à l'identique pour chaque exercice.
    for (let i = 0; i < EXERCISES.length; i += 1) {
      expect(liaisons.slice(i * 4, i * 4 + 4)).toEqual([
        'exerciseMuscle.deleteMany',
        'exerciseMuscle.createMany',
        'exerciseEquipment.deleteMany',
        'exerciseEquipment.createMany',
      ]);
    }
  });

  // « Entier ou inchangé » ne vaut que si l'échec REMONTE : une écriture qui
  // échoue et qu'on avalerait laisserait la transaction s'engager sur un état
  // incomplet, et le chargement se déclarerait réussi.
  it("laisse l'échec d'une liaison annuler la transaction et interrompre le chargement", async () => {
    const faux = fauxPrisma({ appel: 'exerciseMuscle.createMany', occurrence: 3 });

    await expect(syncCatalog(faux.client)).rejects.toThrow(/panne simulée/);

    // Trois exercices entamés, un seul annulé : les deux premiers sont passés.
    expect(faux.transactions).toBe(3);
    expect(faux.transactionsAnnulees).toBe(1);
    // Et rien n'a été tenté après l'échec : la boucle s'arrête là.
    expect(faux.traces.filter((t) => t.appel === 'exercise.upsert')).toHaveLength(3);
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
