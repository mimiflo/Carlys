import { Injectable } from '@nestjs/common';
import { type User, type UserProfile, UserStatus } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

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
  create(input: CreateUserInput): Promise<UserWithProfile> {
    return this.prisma.user.create({
      data: {
        email: input.email,
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
    data: { displayName?: string; locale?: string; timezone?: string },
  ): Promise<UserWithProfile> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { profile: { update: data } },
      include: { profile: true },
    });
  }

  /** Suppression logique : le compte est désactivé, la purge est différée. */
  softDelete(userId: string): Promise<void> {
    return this.prisma.user
      .update({
        where: { id: userId },
        data: { status: UserStatus.DELETED, deletedAt: new Date() },
      })
      .then(() => undefined);
  }
}
