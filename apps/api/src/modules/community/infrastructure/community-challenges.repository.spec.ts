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

/**
 * CE QUE CETTE SECTION PROTÈGE : un compteur collectif ne redescend jamais.
 *
 * Quitter un défi EFFAÇAIT la ligne de participation. Les séances déjà
 * comptées disparaissaient de la somme affichée à tous les autres : la barre
 * du mois reculait, sans que personne n'y puisse rien. Ce qui a été fait
 * pendant qu'on participait appartient au défi ; seule la présence s'arrête.
 */

/** Ce que le test lit d'un appel d'agrégat : ce qu'il demande, et sur quoi. */
interface GroupByArgs {
  _sum?: unknown;
  where: Record<string, unknown>;
}

interface BancDefis {
  repository: CommunityChallengesRepository;
  upsert: jest.Mock;
  updateMany: jest.Mock<Promise<{ count: number }>, [{ where: Record<string, unknown> }]>;
  deleteMany: jest.Mock;
  groupBy: jest.Mock<Promise<unknown[]>, [GroupByArgs]>;
}

/** Un défi ouvert, deux participants présents, un parti qui a contribué. */
function bancDefis(): BancDefis {
  const upsert = jest.fn().mockResolvedValue({});
  const updateMany = jest
    .fn<Promise<{ count: number }>, [{ where: Record<string, unknown> }]>()
    .mockResolvedValue({ count: 1 });
  const deleteMany = jest.fn().mockResolvedValue({ count: 1 });
  // Les deux agrégats se distinguent par ce qu'ils demandent : la SOMME
  // porte sur toutes les lignes, le COMPTE sur les présents seulement.
  const groupBy = jest.fn<Promise<unknown[]>, [GroupByArgs]>((args) =>
    Promise.resolve(
      args._sum === undefined
        ? [{ challengeId: 'defi-1', _count: { _all: 2 } }]
        : [{ challengeId: 'defi-1', _sum: { contribution: 30 } }],
    ),
  );
  const prisma = {
    communityChallenge: {
      findMany: jest.fn().mockResolvedValue([{ id: 'defi-1', kind: 'SPORT', target: 100 }]),
    },
    challengeParticipation: {
      upsert,
      updateMany,
      deleteMany,
      groupBy,
      findMany: jest.fn().mockResolvedValue([]),
    },
  };
  return {
    repository: new CommunityChallengesRepository(prisma as unknown as PrismaService),
    upsert,
    updateMany,
    deleteMany,
    groupBy,
  };
}

describe('CommunityChallengesRepository — départ d’un défi', () => {
  it('quitter DATE le départ, la ligne n’est jamais effacée', async () => {
    const b = bancDefis();

    await b.repository.leaveChallenge('defi-1', 'user-1');

    expect(b.deleteMany).not.toHaveBeenCalled();
    expect(b.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { challengeId: 'defi-1', userId: 'user-1', leftAt: null },
      }),
    );
  });

  it('revenir reprend la MÊME ligne : contribution ni perdue ni doublée', async () => {
    const b = bancDefis();

    await b.repository.joinChallenge('defi-1', 'user-1');

    expect(b.upsert).toHaveBeenCalledWith(expect.objectContaining({ update: { leftAt: null } }));
  });

  it('la somme garde les partants, le compte ne retient que les présents', async () => {
    const b = bancDefis();

    const [stats] = await b.repository.listOpenChallenges(
      new Date('2026-09-15T12:00:00.000Z'),
      'user-1',
    );

    expect(stats).toMatchObject({ totalContribution: 30, participants: 2, joined: false });
    // Le cœur du correctif : la SOMME ne filtre pas les partants.
    const somme = b.groupBy.mock.calls.find(([args]) => args._sum !== undefined)?.[0];
    expect(somme?.where).not.toHaveProperty('leftAt');
  });

  it('un défi quitté ne reçoit plus de nouvelles contributions', async () => {
    const b = bancDefis();

    await b.repository.contribute('user-1', 'WORKOUTS', 1, new Date('2026-09-15T12:00:00.000Z'));

    expect(b.updateMany.mock.calls[0]?.[0].where).toMatchObject({
      userId: 'user-1',
      leftAt: null,
      challenge: { metric: 'WORKOUTS' },
    });
  });

  it('une quantité NULLE n’écrit rien du tout', async () => {
    const b = bancDefis();

    // Une séance de fonte ne parcourt aucun mètre : le cas ordinaire, pas
    // une erreur. Une écriture par métrique absente, en revanche, en serait
    // une — une par séance et par défi, pour ajouter zéro.
    await b.repository.contribute(
      'user-1',
      'DISTANCE_METERS',
      0,
      new Date('2026-09-15T12:00:00.000Z'),
    );

    expect(b.updateMany).not.toHaveBeenCalled();
  });
});
