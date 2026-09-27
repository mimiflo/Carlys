import { Prisma } from '@prisma/client';
import { type PrismaService } from '../../../database/prisma/prisma.service';
import { FriendChallengesRepository } from './friend-challenges.repository';

/**
 * CE QUE CE FICHIER PROTÈGE : la FORME de la contribution aux défis entre
 * amis, qui en décide le coût.
 *
 * L'`updateMany` de Prisma à filtre de relation rendait une semi-jointure que
 * PostgreSQL attaquait par `FriendChallenge(status, endsAt)` : tous les défis
 * ouverts de tous les comptes, sondés un par un (8 ms, 3 890 tampons), à
 * chaque séance close et chaque bonne réponse de quiz. La RÈGLE (quels défis
 * reçoivent la contribution) est gardée par l'e2e « une contribution ne va
 * QU'aux défis acceptés… » ; il passe à l'identique avec l'ancienne forme,
 * d'où ce banc, qui échoue, lui, si elle revient.
 */
describe('FriendChallengesRepository.contribute', () => {
  const USER = '00000000-0000-4000-8000-000000000001';
  const AT = new Date('2026-09-20T12:00:00.000Z');

  function banc() {
    const executeRaw = jest.fn().mockResolvedValue(1);
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const prisma = {
      $executeRaw: executeRaw,
      friendChallengeMember: { updateMany },
    } as unknown as PrismaService;
    return { repository: new FriendChallengesRepository(prisma), executeRaw, updateMany };
  }

  /** La requête telle qu'elle part, reconstituée depuis l'appel étiqueté. */
  function requete(executeRaw: jest.Mock): Prisma.Sql {
    expect(executeRaw).toHaveBeenCalledTimes(1);
    const [morceaux, ...valeurs] = executeRaw.mock.calls[0] as [TemplateStringsArray, ...unknown[]];
    return Prisma.sql(morceaux, ...valeurs);
  }

  it('part des APPARTENANCES de la personne, pas des défis ouverts de tous', async () => {
    const { repository, executeRaw, updateMany } = banc();

    await repository.contribute(USER, 'DISTANCE_METERS', 1200, AT);

    expect(updateMany).not.toHaveBeenCalled();
    const { text, values } = requete(executeRaw);
    const texte = text.replace(/\s+/g, ' ');
    // La table mise à jour est celle des membres, filtrée d'abord sur la
    // personne : c'est son index `(userId, status)` qui borne le travail.
    expect(texte).toMatch(/^ ?UPDATE "FriendChallengeMember" m /);
    expect(texte).toMatch(
      /WHERE m\."userId" = \$\d+::uuid AND m\."status" = 'ACCEPTED' AND EXISTS/,
    );
    // Le défi se lit par sa clé, DANS la sous-requête…
    expect(texte).toContain('c."id" = m."challengeId"');
    // …que l'`OFFSET 0` empêche de remettre à plat en semi-jointure.
    expect(texte).toMatch(/OFFSET 0 \)\s*$/);
    expect(values).toEqual([1200, USER, 'DISTANCE_METERS', AT, AT]);
  });

  it('compare les bornes en UTC, quel que soit le fuseau de la session', async () => {
    const { repository, executeRaw } = banc();

    await repository.contribute(USER, 'DISTANCE_METERS', 1200, AT);

    // `startsAt` et `endsAt` sont des `timestamp` SANS fuseau, écrits en
    // UTC ; l'instant lié arrive en `timestamptz`. Sans la conversion, un
    // serveur réglé sur Paris décalait la fenêtre de deux heures.
    const texte = requete(executeRaw).text.replace(/\s+/g, ' ');
    expect(texte).toMatch(/c\."startsAt" <= \(\$\d+::timestamptz AT TIME ZONE 'UTC'\)/);
    expect(texte).toMatch(/c\."endsAt" >= \(\$\d+::timestamptz AT TIME ZONE 'UTC'\)/);
  });

  it('écrit dans la transaction qu’on lui passe', async () => {
    const { repository, executeRaw } = banc();
    const tx = { $executeRaw: jest.fn().mockResolvedValue(1) };

    await repository.contribute(
      USER,
      'DISTANCE_METERS',
      1200,
      AT,
      tx as unknown as Prisma.TransactionClient,
    );

    expect(tx.$executeRaw).toHaveBeenCalledTimes(1);
    expect(executeRaw).not.toHaveBeenCalled();
  });

  it('une contribution nulle n’écrit rien', async () => {
    const { repository, executeRaw, updateMany } = banc();

    await repository.contribute(USER, 'DISTANCE_METERS', 0, AT);

    expect(executeRaw).not.toHaveBeenCalled();
    expect(updateMany).not.toHaveBeenCalled();
  });
});
