import { type Redis } from 'ioredis';

/**
 * Efface toutes les clés d'un préfixe — SCAN, jamais KEYS (qui bloque Redis
 * le temps de parcourir tout l'espace de clés).
 *
 * Extrait de `CacheService.invalidatePrefix` pour être appelable HORS du
 * processus API : `dist/cli/catalog-seed` écrit le catalogue directement en
 * base et doit purger le préfixe `catalog:` lui-même, sans quoi les listes
 * resteraient périmées jusqu'à une heure (le TTL des fiches). Le service et
 * le CLI partagent ce code ; seule la tolérance aux pannes diffère, et elle
 * appartient à l'appelant.
 */
export async function purgePrefix(client: Redis, prefix: string): Promise<number> {
  let cursor = '0';
  let purged = 0;
  do {
    const [nextCursor, keys] = await client.scan(cursor, 'MATCH', `${prefix}*`, 'COUNT', 100);
    cursor = nextCursor;
    if (keys.length > 0) {
      purged += await client.del(...keys);
    }
  } while (cursor !== '0');
  return purged;
}
