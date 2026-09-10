import { Redis } from 'ioredis';

/**
 * Remet le compteur de débit à zéro AVANT CHAQUE FICHIER de la suite e2e.
 *
 * POURQUOI CE FICHIER EXISTE. Le compteur de la limitation de débit vivait
 * dans le processus : ouvrir une application par suite suffisait à lui donner
 * son propre budget, et plusieurs suites s'appuyaient explicitement là-dessus.
 * Il vit maintenant dans Redis, pour que tous les réplicas de l'API partagent
 * la même limite — c'est le but, et c'est ce qui empêche N réplicas de laisser
 * passer N fois le quota annoncé. Effet de bord immédiat sur les tests : les
 * vingt fichiers de la suite, qui viennent tous de 127.0.0.1, se sont mis à
 * partager le même seau et à se refuser mutuellement en 429. Mesuré avant
 * correctif : 96 tests en échec sur 155, tous sur des routes sans rapport avec
 * la limitation de débit.
 *
 * Ce qu'il ne fait PAS : desserrer la limite. Les trois suites qui PROUVENT le
 * refus (verrouillage admin, plafond de messages du coach, demandes d'amis)
 * continuent de l'atteindre à l'intérieur de leur fichier — seule la frontière
 * ENTRE fichiers est rétablie, exactement là où elle était avant.
 *
 * Portée volontairement étroite : le préfixe des seuls compteurs de débit.
 * Un `FLUSHDB` effacerait aussi les caches et la présence, et masquerait le
 * jour où une suite dépendrait par erreur de l'état laissé par une autre.
 */
const PREFIXE_DEBIT = 'carlys:throttle:';

beforeAll(async () => {
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
  } finally {
    await client.quit();
  }
});
