import { ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { type PrismaService } from '../../../database/prisma/prisma.service';
import { UsersRepository } from './users.repository';

/**
 * CE QUE CE FICHIER PROTÈGE : la course entre deux inscriptions simultanées
 * sur la même adresse.
 *
 * `AuthService.register` vérifie l'unicité de l'e-mail AVANT d'appeler
 * `create`. Entre les deux, une autre inscription peut passer : la perdante
 * reçoit un P2002 sur l'e-mail. La boucle de reprise le prenait pour une
 * collision de code ami, retirait trois codes contre le même mur, puis
 * relançait l'erreur brute — soit un 500 là où la personne attend le 409
 * qu'elle aurait obtenu une milliseconde plus tôt.
 */
function p2002(target: string[] | string): Prisma.PrismaClientKnownRequestError {
  return new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
    code: 'P2002',
    clientVersion: 'test',
    meta: { target },
  });
}

function repositoryOn(create: jest.Mock): UsersRepository {
  return new UsersRepository({ user: { create } } as unknown as PrismaService);
}

const INPUT = { email: 'a@b.fr', passwordHash: 'hash', displayName: 'Alex' };

describe('UsersRepository.create — collisions d’unicité', () => {
  it('collision sur l’E-MAIL : 409, sans retirer de code', async () => {
    const create = jest.fn().mockRejectedValue(p2002(['email']));

    await expect(repositoryOn(create).create(INPUT)).rejects.toThrow(ConflictException);
    // Une seule tentative : retirer un code ami ne changerait rien au mur.
    expect(create).toHaveBeenCalledTimes(1);
  });

  it('collision sur le CODE AMI : on retire, et ça passe', async () => {
    const create = jest
      .fn()
      .mockRejectedValueOnce(p2002(['friendCode']))
      .mockResolvedValue({ id: 'u-1', profile: null });

    await expect(repositoryOn(create).create(INPUT)).resolves.toMatchObject({ id: 'u-1' });
    expect(create).toHaveBeenCalledTimes(2);
  });

  it('code ami obstinément en collision : on abandonne après trois essais', async () => {
    const create = jest.fn().mockRejectedValue(p2002(['friendCode']));

    await expect(repositoryOn(create).create(INPUT)).rejects.toThrow(
      Prisma.PrismaClientKnownRequestError,
    );
    expect(create).toHaveBeenCalledTimes(3);
  });

  it('cible d’unicité inconnue : on ne prétend rien, l’erreur remonte', async () => {
    const create = jest.fn().mockRejectedValue(p2002('une_contrainte_inattendue'));

    await expect(repositoryOn(create).create(INPUT)).rejects.toThrow(
      Prisma.PrismaClientKnownRequestError,
    );
    expect(create).toHaveBeenCalledTimes(1);
  });
});
