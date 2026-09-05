import { Injectable } from '@nestjs/common';
import { Prisma, type User, type UserProfile, UserStatus } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { generateFriendCode } from '../domain/friend-code';
import { tombstoneEmail, tombstoneFriendCode } from '../domain/tombstone';

export type UserWithProfile = User & { profile: UserProfile | null };

export interface CreateUserInput {
  email: string;
  passwordHash: string;
  displayName: string;
  locale?: string;
  timezone?: string;
}

/** Accès Prisma du domaine utilisateurs — seul point de contact avec la base. */
@Injectable()
export class UsersRepository {
  constructor(private readonly prisma: PrismaService) {}

  findActiveByEmail(email: string): Promise<UserWithProfile | null> {
    return this.prisma.user.findFirst({
      where: { email, deletedAt: null },
      include: { profile: true },
    });
  }

  findActiveById(id: string): Promise<UserWithProfile | null> {
    return this.prisma.user.findFirst({
      where: { id, deletedAt: null },
      include: { profile: true },
    });
  }

  emailExists(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  /** Crée l'utilisateur, son profil et sa crédential en une transaction. */
  async create(input: CreateUserInput): Promise<UserWithProfile> {
    // Le code ami est tiré ici, pas en base : l'alphabet est une règle du
    // domaine. Une collision sur 2×10¹¹ combinaisons est invraisemblable ;
    // si elle arrive, on retire — l'e-mail unique, lui, a déjà été vérifié
    // par l'appelant, donc un P2002 ne peut venir que du code.
    for (let attempt = 0; ; attempt += 1) {
      try {
        return await this.prisma.user.create({
          data: {
            email: input.email,
            friendCode: generateFriendCode(),
            profile: {
              create: {
                displayName: input.displayName,
                locale: input.locale ?? 'fr',
                timezone: input.timezone ?? 'Europe/Paris',
              },
            },
            credential: {
              create: { passwordHash: input.passwordHash },
            },
          },
          include: { profile: true },
        });
      } catch (error) {
        const collision =
          error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
        if (!collision || attempt >= 2) {
          throw error;
        }
      }
    }
  }

  findPasswordHash(userId: string): Promise<string | null> {
    return this.prisma.userCredential
      .findUnique({ where: { userId }, select: { passwordHash: true } })
      .then((credential) => credential?.passwordHash ?? null);
  }

  updatePasswordHash(userId: string, passwordHash: string): Promise<void> {
    return this.prisma.userCredential
      .update({ where: { userId }, data: { passwordHash } })
      .then(() => undefined);
  }

  markEmailVerified(userId: string): Promise<void> {
    return this.prisma.user
      .update({ where: { id: userId }, data: { emailVerifiedAt: new Date() } })
      .then(() => undefined);
  }

  updateProfile(
    userId: string,
    data: Prisma.UserProfileUpdateWithoutUserInput,
  ): Promise<UserWithProfile> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { profile: { update: data } },
      include: { profile: true },
    });
  }

  /**
   * Suppression de compte, en UNE transaction : le compte passe DELETED et
   * son identité est libérée (adresse et code ami tombaux, nom et profil
   * personnel effacés), ses jetons d'appareil disparaissent. `within` tourne
   * dans la même transaction : c'est la place de ce qui appartient à un autre
   * domaine (la suppression des sessions et de leurs refresh tokens), pour
   * qu'aucun état intermédiaire ne survive à un échec.
   *
   * La ligne reste : l'identifiant est cité par l'audit et par l'historique
   * agrégé (séances, records, journal alimentaire), qui ne portent plus rien
   * qui identifie la personne une fois ces colonnes effacées.
   */
  async deleteAccount(
    userId: string,
    within: (tx: Prisma.TransactionClient) => Promise<void>,
  ): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await within(tx);
      await tx.deviceToken.deleteMany({ where: { userId } });
      await tx.userProfile.updateMany({
        where: { userId },
        data: { displayName: '', birthDate: null, sex: null, heightCm: null },
      });
      await tx.user.update({
        where: { id: userId },
        data: {
          status: UserStatus.DELETED,
          deletedAt: new Date(),
          email: tombstoneEmail(userId),
          friendCode: tombstoneFriendCode(userId),
        },
      });
    });
  }
}
