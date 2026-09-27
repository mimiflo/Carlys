import { Prisma } from '@prisma/client';
import { type PrismaService } from '../../../database/prisma/prisma.service';
import { WorkoutsRepository } from './workouts.repository';

/**
 * CE QUE CE FICHIER PROTÈGE : qu'un POST de création de séance ne se termine
 * jamais par un 404.
 *
 * `createSession` rendait « déjà créée » pour TOUT P2002 levé dans sa
 * transaction. Or elle en écrit deux choses : la séance et son plan. Un
 * conflit venu du PLAN (deux prévisions au même rang, un identifiant d'item
 * déjà pris) annule la transaction entière — la séance n'existe alors PAS, et
 * répondre « déjà créée » envoyait l'appelant la relire pour ne rien trouver.
 */

/** Un conflit d'unicité tel que Prisma le lève, avec la cible qu'on veut. */
function conflictOn(target: string[] | string): Prisma.PrismaClientKnownRequestError {
  return new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
    code: 'P2002',
    clientVersion: 'test',
    meta: { target },
  });
}

interface Tx {
  workoutSession: { create: jest.Mock };
  workoutSessionPlanItem: { createMany: jest.Mock };
  workoutTemplate: { updateMany: jest.Mock };
}

function buildTx(): Tx {
  return {
    workoutSession: { create: jest.fn().mockResolvedValue(undefined) },
    workoutSessionPlanItem: { createMany: jest.fn().mockResolvedValue({ count: 1 }) },
    workoutTemplate: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
  };
}

function repositoryOver(tx: Tx): WorkoutsRepository {
  const prisma = {
    $transaction: (run: (inner: Tx) => Promise<unknown>) => run(tx),
  } as unknown as PrismaService;
  return new WorkoutsRepository(prisma);
}

const SESSION = {
  id: 'session-1',
  userId: 'user-1',
  startedAt: new Date('2026-09-15T10:00:00.000Z'),
} as unknown as Prisma.WorkoutSessionUncheckedCreateInput;

const PLAN = [
  { id: 'item-1', sessionId: 'session-1', exercisePosition: 0, setPosition: 0 },
] as unknown as Prisma.WorkoutSessionPlanItemUncheckedCreateInput[];

describe('WorkoutsRepository.createSession', () => {
  it('conflit sur la SÉANCE : c’est un rejeu, on rend « déjà créée »', async () => {
    const tx = buildTx();
    tx.workoutSession.create.mockRejectedValue(conflictOn(['id']));

    await expect(repositoryOver(tx).createSession(SESSION, undefined, PLAN)).resolves.toBe(false);
  });

  it('cible donnée en CHAÎNE (connecteur non PostgreSQL) : même lecture', async () => {
    const tx = buildTx();
    tx.workoutSession.create.mockRejectedValue(conflictOn('WorkoutSession_pkey'));

    await expect(repositoryOver(tx).createSession(SESSION, undefined, PLAN)).resolves.toBe(false);
  });

  it('conflit venu du PLAN : l’erreur remonte, la séance n’existe pas', async () => {
    const tx = buildTx();
    tx.workoutSessionPlanItem.createMany.mockRejectedValue(
      conflictOn(['sessionId', 'exercisePosition', 'setPosition']),
    );

    await expect(repositoryOver(tx).createSession(SESSION, undefined, PLAN)).rejects.toThrow(
      Prisma.PrismaClientKnownRequestError,
    );
  });

  it('cible inconnue : on ne prétend rien, l’erreur remonte', async () => {
    const tx = buildTx();
    tx.workoutSession.create.mockRejectedValue(conflictOn([]));

    await expect(repositoryOver(tx).createSession(SESSION, undefined, PLAN)).rejects.toThrow(
      Prisma.PrismaClientKnownRequestError,
    );
  });

  it('sans conflit : la séance est créée', async () => {
    const tx = buildTx();

    await expect(repositoryOver(tx).createSession(SESSION, undefined, PLAN)).resolves.toBe(true);
    expect(tx.workoutSessionPlanItem.createMany).toHaveBeenCalledWith({ data: PLAN });
  });
});

describe('WorkoutsRepository.softDeleteSet', () => {
  /**
   * La libération du plan est BORNÉE à la séance de la série. `doneSetId`
   * n'a pas d'index : sans `sessionId`, PostgreSQL balayait les prévisions
   * de tous les comptes (2 millions de lignes, 237 ms) à chaque suppression.
   */
  it('libère la prévision de la série dans SA séance, et seulement là', async () => {
    const setUpdate = jest.fn().mockReturnValue('pierre-tombale');
    const planUpdate = jest.fn().mockReturnValue('liberation');
    const transaction = jest.fn().mockResolvedValue([]);
    const prisma = {
      $transaction: transaction,
      workoutSet: { update: setUpdate },
      workoutSessionPlanItem: { updateMany: planUpdate },
    } as unknown as PrismaService;

    await new WorkoutsRepository(prisma).softDeleteSet('set-1', 'session-1');

    expect(setUpdate).toHaveBeenCalledWith({
      where: { id: 'set-1' },
      data: { deletedAt: expect.any(Date) as Date },
    });
    expect(planUpdate).toHaveBeenCalledWith({
      where: { sessionId: 'session-1', doneSetId: 'set-1' },
      data: { doneSetId: null },
    });
    // Les deux écritures partent ENSEMBLE : une série supprimée sans rendre
    // sa prévision laisserait un orphelin compté « fait » pour toujours.
    expect(transaction).toHaveBeenCalledWith(['pierre-tombale', 'liberation']);
  });
});
