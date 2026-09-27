import { type PrismaClient, UserStatus } from '@prisma/client';
import { type DeletedAccountsLedger } from '../application/deleted-accounts-purge';

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
