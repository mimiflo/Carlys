import { Prisma } from '@prisma/client';
import { type PrismaService } from '../../../database/prisma/prisma.service';
import { CommunityChallengesRepository } from './community-challenges.repository';

/**
 * CE QUE CE FICHIER PROTÈGE : une réponse de quiz juste et sa contribution
 * aux défis CULTURE ne peuvent pas se séparer.
 *
 * Les deux écritures étaient consécutives et sans transaction. L'idempotence
 * rendait alors la perte DÉFINITIVE : si l'incrément échouait après l'écriture
 * de la réponse, le rejeu butait sur `@@unique([userId, lessonId,
 * answeredOn])`, rendait « déjà comptée », et n'incrémentait jamais. Une
 * leçon ne se répond qu'une fois par jour : il n'y a pas de rattrapage.
 */

const REPONSE = {
  userId: 'user-1',
  lessonId: 'lecon-dos',
  answeredOn: '2026-08-11',
  at: new Date('2026-08-11T09:00:00Z'),
};

function p2002(): Prisma.PrismaClientKnownRequestError {
  return new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
    code: 'P2002',
    clientVersion: 'test',
    meta: { target: ['userId', 'lessonId', 'answeredOn'] },
  });
}

interface Banc {
  repository: CommunityChallengesRepository;
  create: jest.Mock;
  updateMany: jest.Mock;
  /** Combien d'écritures ont eu lieu HORS transaction. */
  horsTransaction: () => number;
}

function banc(options: { createRejette?: Error; updateRejette?: Error } = {}): Banc {
  let dansTransaction = false;
  let horsTransaction = 0;

  const compter = (rejette?: Error) =>
    jest.fn(() => {
      if (!dansTransaction) {
        horsTransaction += 1;
      }
      return rejette === undefined ? Promise.resolve({ count: 1 }) : Promise.reject(rejette);
    });

  const create = compter(options.createRejette);
  const updateMany = compter(options.updateRejette);

  const modeles = { quizAnswer: { create }, challengeParticipation: { updateMany } };
  const prisma = {
    ...modeles,
    // Le rejet REMONTE après avoir quitté la transaction : c'est ce qui
    // permet d'observer qu'un échec de l'incrément annule bien l'ensemble.
    $transaction: jest.fn(async (rappel: (tx: unknown) => Promise<unknown>) => {
      dansTransaction = true;
      try {
        return await rappel(modeles);
      } finally {
        dansTransaction = false;
      }
    }),
  };

  return {
    repository: new CommunityChallengesRepository(prisma as unknown as PrismaService),
    create,
    updateMany,
    horsTransaction: () => horsTransaction,
  };
}

describe('CommunityChallengesRepository.recordQuizAnswer', () => {
  it('réponse juste : les DEUX écritures ont lieu dans la transaction', async () => {
    const b = banc();

    const cree = await b.repository.recordQuizAnswer({ ...REPONSE, correct: true });

    expect(cree).toBe(true);
    expect(b.create).toHaveBeenCalledTimes(1);
    expect(b.updateMany).toHaveBeenCalledTimes(1);
    // Le cœur du correctif : aucune des deux n'est passée à côté.
    expect(b.horsTransaction()).toBe(0);
  });

  it('réponse fausse : enregistrée, sans contribution', async () => {
    const b = banc();

    const cree = await b.repository.recordQuizAnswer({ ...REPONSE, correct: false });

    expect(cree).toBe(true);
    expect(b.create).toHaveBeenCalledTimes(1);
    expect(b.updateMany).not.toHaveBeenCalled();
  });

  it('rejeu (unicité) : ni erreur ni seconde contribution', async () => {
    const b = banc({ createRejette: p2002() });

    const cree = await b.repository.recordQuizAnswer({ ...REPONSE, correct: true });

    expect(cree).toBe(false);
    expect(b.updateMany).not.toHaveBeenCalled();
  });

  it('l’incrément échoue : l’erreur REMONTE, la transaction annule la réponse', async () => {
    // Le défaut, en une ligne : avant, la réponse restait écrite et la
    // contribution était perdue pour de bon. Maintenant l'appelant voit
    // l'échec, rien n'est écrit, et le rejeu refait les deux.
    const b = banc({ updateRejette: new Error('contention') });

    await expect(b.repository.recordQuizAnswer({ ...REPONSE, correct: true })).rejects.toThrow(
      'contention',
    );
  });

  it('une erreur qui n’est PAS un doublon remonte telle quelle', async () => {
    // Sans cette contre-épreuve, un `catch` trop large rendrait `false` sur
    // une panne de base : la réponse serait comptée comme « déjà là ».
    const b = banc({ createRejette: new Error('base indisponible') });

    await expect(b.repository.recordQuizAnswer({ ...REPONSE, correct: true })).rejects.toThrow(
      'base indisponible',
    );
  });
});
