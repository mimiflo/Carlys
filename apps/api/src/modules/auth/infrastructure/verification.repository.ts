import { Injectable } from '@nestjs/common';
import { type EmailVerification, type PasswordReset } from '@prisma/client';
import { lockNamed } from '../../../database/prisma/advisory-lock';
import { PrismaService } from '../../../database/prisma/prisma.service';

/** Cadence des liens envoyés par e-mail à un compte (vérification, réinitialisation). */
export interface LinkCadence {
  /** Délai minimal entre deux liens. */
  cooldownMs: number;
  /** Nombre maximal de liens sur la fenêtre glissante. */
  maxPerWindow: number;
  windowMs: number;
}

/**
 * `true` si un nouveau lien peut partir, vu les dates des liens déjà posés
 * sur la fenêtre (du plus récent au plus ancien).
 */
function allowsNewLink(recentDesc: readonly Date[], cadence: LinkCadence, now: number): boolean {
  const latest = recentDesc[0]?.getTime();
  return (
    recentDesc.length < cadence.maxPerWindow &&
    (latest === undefined || now - latest >= cadence.cooldownMs)
  );
}

/** Accès Prisma des jetons de vérification d'e-mail et de réinitialisation. */
@Injectable()
export class VerificationRepository {
  constructor(private readonly prisma: PrismaService) {}

  createEmailVerification(userId: string, tokenHash: string, expiresAt: Date): Promise<void> {
    return this.prisma.emailVerification
      .create({ data: { userId, tokenHash, expiresAt } })
      .then(() => undefined);
  }

  /**
   * Pose un NOUVEAU lien de vérification si la cadence du compte le permet,
   * et invalide tous les précédents : seul le dernier lien envoyé vaut.
   * `false` : trop tôt ou trop souvent, rien n'a été écrit.
   *
   * Compter puis écrire sous un verrou par compte : sans lui, des renvois
   * parallèles liraient tous « aucun envoi récent » et partiraient ensemble.
   */
  issueEmailVerification(
    userId: string,
    tokenHash: string,
    expiresAt: Date,
    cadence: LinkCadence,
  ): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      await lockNamed(tx, `email-verification:${userId}`);
      const now = Date.now();
      const recent = await tx.emailVerification.findMany({
        where: { userId, createdAt: { gte: new Date(now - cadence.windowMs) } },
        select: { createdAt: true },
        orderBy: { createdAt: 'desc' },
      });
      const dates = recent.map((row) => row.createdAt);
      if (!allowsNewLink(dates, cadence, now)) {
        return false;
      }
      await tx.emailVerification.updateMany({
        where: { userId, usedAt: null },
        data: { usedAt: new Date(now) },
      });
      await tx.emailVerification.create({ data: { userId, tokenHash, expiresAt } });
      return true;
    });
  }

  findEmailVerification(tokenHash: string): Promise<EmailVerification | null> {
    return this.prisma.emailVerification.findUnique({ where: { tokenHash } });
  }

  markEmailVerificationUsed(id: string): Promise<void> {
    return this.prisma.emailVerification
      .update({ where: { id }, data: { usedAt: new Date() } })
      .then(() => undefined);
  }

  /**
   * Pose un lien de réinitialisation si la cadence du compte le permet.
   * `false` : trop tôt ou trop souvent, rien n'a été écrit. Compter puis
   * écrire sous un verrou par compte, comme [issueEmailVerification].
   *
   * Les liens précédents restent valables, à la différence de la
   * vérification : cette demande est ANONYME, et invalider laisserait
   * n'importe qui casser le lien que la personne s'apprête à ouvrir. Ils
   * tombent tous dès que l'un sert, ou que le mot de passe change.
   */
  issuePasswordReset(
    userId: string,
    tokenHash: string,
    expiresAt: Date,
    cadence: LinkCadence,
  ): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      await lockNamed(tx, `password-reset:${userId}`);
      const now = Date.now();
      const recent = await tx.passwordReset.findMany({
        where: { userId, createdAt: { gte: new Date(now - cadence.windowMs) } },
        select: { createdAt: true },
        orderBy: { createdAt: 'desc' },
      });
      const dates = recent.map((row) => row.createdAt);
      if (!allowsNewLink(dates, cadence, now)) {
        return false;
      }
      await tx.passwordReset.create({ data: { userId, tokenHash, expiresAt } });
      return true;
    });
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
