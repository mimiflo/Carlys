import { reinitialiserDebit } from './support/throttle';

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
 * Ce qu'il ne fait PAS : desserrer la limite. Les suites qui PROUVENT le refus
 * (verrouillage admin, plafond de messages du coach, demandes d'amis, quota de
 * la connexion sociale) continuent de l'atteindre à l'intérieur d'un même
 * test — seule la frontière ENTRE fichiers est rétablie, exactement là où elle
 * était avant.
 *
 * Le geste lui-même vit dans `support/throttle.ts` : une suite dense en
 * requêtes sur une route sensible le rejoue entre ses propres tests.
 */
beforeAll(reinitialiserDebit);
