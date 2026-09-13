import { Injectable } from '@nestjs/common';
import { type ExternalIdentityProvider, Prisma, type User, type UserProfile } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type IdentityOwner = User & { profile: UserProfile | null };

/**
 * Identités externes (Apple, Google) : le lien entre un `sub` de fournisseur
 * et un compte Carlys. L'unicité `(provider, subject)` est portée par la
 * base — un même compte fournisseur ne peut pointer que vers UN utilisateur.
 */
@Injectable()
export class IdentitiesRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Le PROPRIÉTAIRE de l'identité, s'il existe et n'est pas supprimé. */
  async findOwner(
    provider: ExternalIdentityProvider,
    subject: string,
  ): Promise<IdentityOwner | null> {
    const identity = await this.prisma.externalIdentity.findUnique({
      where: { provider_subject: { provider, subject } },
      include: { user: { include: { profile: true } } },
    });
    if (identity === null || identity.user.deletedAt !== null) {
      return null;
    }
    return identity.user;
  }

  /**
   * Rattache l'identité à un compte. Deux premières connexions simultanées
   * avec le même jeton peuvent se courser : la contrainte d'unicité tranche,
   * et le perdant repart comme une connexion ordinaire (`false`).
   */
  async attach(
    userId: string,
    provider: ExternalIdentityProvider,
    subject: string,
    email: string | null,
  ): Promise<boolean> {
    try {
      await this.prisma.externalIdentity.create({
        data: { userId, provider, subject, email },
      });
      return true;
    } catch (error) {
      const alreadyAttached =
        error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
      if (alreadyAttached) {
        return false;
      }
      throw error;
    }
  }
}
