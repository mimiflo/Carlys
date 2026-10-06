import { type Prisma, type PrismaClient, UserStatus } from '@prisma/client';
import {
  type DeletedAccountsLedger,
  type SessionsPurged,
} from '../application/deleted-accounts-purge';

/**
 * Délai de la transaction d'effacement d'un compte. Celui de Prisma par
 * défaut (5 s) est taillé pour une requête HTTP ; ici, une commande de nuit
 * efface d'un geste des années de séances, de séries et de repas. Le vrai
 * remède est ailleurs : chaque clé que la cascade traverse a son index
 * (`test/purge-index.e2e-spec.ts`), et 300 séances passent de 7,3 s à
 * quelques dizaines de millisecondes. Ce délai est la marge : dépassé, le
 * compte n'était jamais effacé, et l'échec revenait chaque nuit.
 */
export const ERASE_ACCOUNT_TIMEOUT_MS = 60_000;

/**
 * Un événement de paiement JAMAIS appliqué (`processedAt` nul) qui ne nomme
 * aucun compte (`userId` nul), reçu avant `before` : l'index `receivedAt`
 * sert la lecture.
 */
function orphelinsAvant(before: Date): Prisma.SubscriptionEventWhereInput {
  return { processedAt: null, userId: null, receivedAt: { lt: before } };
}

/**
 * Une session CLOSE avant `before` : révoquée, ou expirée (échéance
 * absolue, fixée à la connexion).
 */
function sessionsClosesAvant(before: Date): Prisma.UserSessionWhereInput {
  return { OR: [{ revokedAt: { lt: before } }, { expiresAt: { lt: before } }] };
}

/**
 * Les comptes supprimés vus par la purge — un client Prisma NU, hors de
 * Nest, comme les autres commandes de `src/cli`.
 */
export class PrismaDeletedAccountsLedger implements DeletedAccountsLedger {
  constructor(private readonly prisma: PrismaClient) {}

  async listDeletedBefore(before: Date): Promise<string[]> {
    const rows = await this.prisma.user.findMany({
      where: { status: UserStatus.DELETED, deletedAt: { lt: before } },
      select: { id: true },
      orderBy: { id: 'asc' },
    });
    return rows.map((row) => row.id);
  }

  async isDeleted(id: string): Promise<boolean> {
    return (await this.prisma.user.count({ where: { id, status: UserStatus.DELETED } })) === 1;
  }

  countOrphanPaymentEventsBefore(before: Date): Promise<number> {
    return this.prisma.subscriptionEvent.count({ where: orphelinsAvant(before) });
  }

  async eraseOrphanPaymentEventsBefore(before: Date): Promise<number> {
    const { count } = await this.prisma.subscriptionEvent.deleteMany({
      where: orphelinsAvant(before),
    });
    return count;
  }

  async countDeadSessionsBefore(before: Date): Promise<SessionsPurged> {
    const [sessions, refreshTokens] = await Promise.all([
      this.prisma.userSession.count({ where: sessionsClosesAvant(before) }),
      this.prisma.refreshToken.count({ where: { expiresAt: { lt: before } } }),
    ]);
    return { sessions, refreshTokens };
  }

  /**
   * Les jetons échus D'ABORD : le compte rendu dit alors la même chose à
   * blanc et pour de bon. Les sessions closes emportent ensuite, par
   * cascade, leurs jetons restants et leurs jetons push. Deux instructions
   * hors transaction : chacune est sûre seule, et rejouée le lendemain.
   * ponytail: balayage sans index sur `expiresAt`, une fois par jour sur une
   * table que cette purge garde bornée ; un index (écrit à chaque rotation)
   * si le balayage se mesure un jour.
   */
  async eraseDeadSessionsBefore(before: Date): Promise<SessionsPurged> {
    const jetons = await this.prisma.refreshToken.deleteMany({
      where: { expiresAt: { lt: before } },
    });
    const sessions = await this.prisma.userSession.deleteMany({
      where: sessionsClosesAvant(before),
    });
    return { sessions: sessions.count, refreshTokens: jetons.count };
  }

  /**
   * Le compte part, et avec lui — par les cascades du schéma — sessions,
   * séances et séries, modèles, programmes, records, mesures, repas,
   * conversations du coach, amitiés, encouragements, défis, ligue,
   * réponses de quiz, abonnements et droits. Les événements de paiement
   * qui le NOMMENT survivraient à la cascade — `SetNull` sur l'abonnement,
   * et aucun lien du tout quand la projection a échoué — avec leur charge
   * utile brute : ils partent d'abord, dans la même transaction, retrouvés
   * par le compte recopié à la réception comme par l'abonnement.
   * La condition `status: DELETED` est reposée ICI : un compte réactivé entre
   * la lecture et l'écriture n'est pas touché.
   */
  async eraseAccount(id: string): Promise<boolean> {
    // La LIGUE d'abord, dans une écriture courte à elle : chaque ligne
    // supprimée décrémente l'effectif de son groupe (`LeagueCohort`). Dans la
    // longue cascade ci-dessous, ce verrou de ligne aurait tenu le temps de
    // supprimer séances et séries — et chaque placement dans ce groupe,
    // verrou de division en main, aurait attendu derrière.
    await this.prisma.leagueMembership.deleteMany({
      where: { userId: id, user: { status: UserStatus.DELETED } },
    });
    return this.prisma.$transaction(
      async (tx) => {
        const encore = await tx.user.count({ where: { id, status: UserStatus.DELETED } });
        if (encore === 0) {
          return false;
        }
        await tx.subscriptionEvent.deleteMany({
          where: { OR: [{ userId: id }, { subscription: { userId: id } }] },
        });
        const { count } = await tx.user.deleteMany({ where: { id, status: UserStatus.DELETED } });
        return count === 1;
      },
      { timeout: ERASE_ACCOUNT_TIMEOUT_MS },
    );
  }
}
