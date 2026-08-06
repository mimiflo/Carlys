import { Injectable } from '@nestjs/common';
import { type EmailVerification, type PasswordReset } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/** Accès Prisma des jetons de vérification d'e-mail et de réinitialisation. */
@Injectable()
export class VerificationRepository {
  constructor(private readonly prisma: PrismaService) {}

  createEmailVerification(userId: string, tokenHash: string, expiresAt: Date): Promise<void> {
    return this.prisma.emailVerification
      .create({ data: { userId, tokenHash, expiresAt } })
      .then(() => undefined);
  }

  findEmailVerification(tokenHash: string): Promise<EmailVerification | null> {
    return this.prisma.emailVerification.findUnique({ where: { tokenHash } });
  }

  markEmailVerificationUsed(id: string): Promise<void> {
    return this.prisma.emailVerification
      .update({ where: { id }, data: { usedAt: new Date() } })
      .then(() => undefined);
  }

  createPasswordReset(userId: string, tokenHash: string, expiresAt: Date): Promise<void> {
    return this.prisma.passwordReset
      .create({ data: { userId, tokenHash, expiresAt } })
      .then(() => undefined);
  }

  findPasswordReset(tokenHash: string): Promise<PasswordReset | null> {
    return this.prisma.passwordReset.findUnique({ where: { tokenHash } });
  }

  markPasswordResetUsed(id: string): Promise<void> {
    return this.prisma.passwordReset
      .update({ where: { id }, data: { usedAt: new Date() } })
      .then(() => undefined);
  }

  /** Invalide les jetons de réinitialisation encore ouverts d'un utilisateur. */
  invalidateOpenPasswordResets(userId: string): Promise<void> {
    return this.prisma.passwordReset
      .updateMany({
        where: { userId, usedAt: null },
        data: { usedAt: new Date() },
      })
      .then(() => undefined);
  }
}
