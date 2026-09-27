import { type Prisma } from '@prisma/client';

/**
 * Verrou consultatif PostgreSQL tenu jusqu'à la fin de la transaction `tx`,
 * nommé par une chaîne (`hashtext` la ramène à l'entier qu'attend
 * `pg_advisory_xact_lock`).
 *
 * L'usage : sérialiser un « compter puis écrire » PAR COMPTE — deux requêtes
 * parallèles du même compte lisaient toutes deux le même décompte avant
 * qu'aucune n'écrive, et franchissaient ensemble le plafond que ce décompte
 * devait tenir. Sous ce verrou, la seconde attend que la première ait écrit,
 * puis compte juste. Des comptes différents ne s'attendent pas.
 *
 * Deux noms distincts peuvent tomber sur le même entier (`hashtext` rend 32
 * bits) : la seule conséquence est une attente inutile, jamais une erreur.
 */
export async function lockNamed(tx: Prisma.TransactionClient, name: string): Promise<void> {
  // `$executeRaw` et non `$queryRaw` : la fonction rend `void`, que le client
  // ne sait pas désérialiser en colonne.
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${name}))`;
}
