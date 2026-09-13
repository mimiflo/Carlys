import { Redis } from 'ioredis';

/** Préfixe des compteurs de débit — et LUI SEUL. */
const PREFIXE_DEBIT = 'carlys:throttle:';

/**
 * Remet à zéro les compteurs de limitation de débit.
 *
 * Le compteur vit dans Redis pour que tous les réplicas de l'API partagent la
 * même limite. Effet de bord en test : les suites, toutes émises depuis
 * 127.0.0.1, partagent aussi le même seau. `setup-e2e.ts` rétablit la
 * frontière ENTRE FICHIERS ; une suite qui, à elle seule, dépasse le quota
 * d'une route sensible (10/min) appelle cette fonction entre ses tests.
 *
 * Ce qu'elle ne fait PAS : desserrer la limite. Les suites qui PROUVENT le
 * refus l'atteignent à l'intérieur d'un même test, hors de portée de ce
 * nettoyage.
 *
 * Portée volontairement étroite : un `FLUSHDB` effacerait aussi les caches et
 * la présence, et masquerait le jour où une suite dépendrait par erreur de
 * l'état laissé par une autre.
 */
export async function reinitialiserDebit(): Promise<void> {
  const client = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379', {
    maxRetriesPerRequest: 1,
  });
  try {
    // SCAN, jamais KEYS : même dans les tests, on ne prend pas l'habitude de
    // bloquer Redis sur un parcours complet du keyspace.
    let cursor = '0';
    do {
      const [suivant, cles] = await client.scan(cursor, 'MATCH', `${PREFIXE_DEBIT}*`, 'COUNT', 500);
      cursor = suivant;
      if (cles.length > 0) {
        await client.del(...cles);
      }
    } while (cursor !== '0');
  } catch {
    // Redis absent : la limitation passe en fail-open, il n'y a alors aucun
    // compteur à effacer — le silence est ici la bonne réponse, et les
    // suites qui en dépendent vraiment échoueront d'elles-mêmes.
  } finally {
    await client.quit().catch(() => undefined);
  }
}
