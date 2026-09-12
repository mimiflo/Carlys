/**
 * `node dist/cli/catalog-seed [--sans-photos]`
 *
 * Charge le CATALOGUE D'EXERCICES dans la base — le seul moyen de le faire
 * sur un serveur. Le seed de développement, seul autre chemin, ne s'exécute
 * jamais en déploiement (il crée des comptes de développement) ; avant cette
 * commande, une recette fraîchement déployée avait sa bibliothèque
 * d'exercices VIDE : l'écran existait, rien ne s'y affichait.
 *
 * Elle réutilise exactement ce que le seed utilise : `syncCatalog` projette
 * groupes musculaires, matériels et exercices (upsert par slug, idempotent —
 * rejouable à volonté, y compris après une mise à jour du catalogue), et
 * `syncExerciseMedia` dépose les photos dans le stockage objet (identifiants
 * déterministes : re-déposer ne crée pas de doublon). Rien n'est recopié.
 *
 * STRICTEMENT le catalogue : aucun compte, aucun plan d'abonnement — les
 * identifiants produits Stripe/RevenueCat du seed sont factices et n'ont
 * rien à faire sur un serveur.
 *
 * Le cache Redis (préfixe `catalog:`) est purgé à la fin : l'API n'a pas vu
 * passer l'écriture, et sans purge les listes resteraient périmées jusqu'à
 * une heure. Redis injoignable n'est pas un échec — le TTL fait alors foi,
 * et la commande le dit.
 */
import { Redis } from 'ioredis';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { AppConfigService } from '../config/app-config.service';
import { type Env, validateEnv } from '../config/env.schema';
import { purgePrefix } from '../infrastructure/cache/purge-prefix';
import { syncCatalog } from '../modules/exercises/application/catalog-sync';
import { CATALOG_CACHE_PREFIX } from '../modules/exercises/application/exercises.service';
import { syncExerciseMedia } from '../modules/media/application/catalog-media-sync';

export class UsageError extends Error {}

export interface CatalogSeedArgs {
  readonly withPhotos: boolean;
}

/** Lit les arguments (sans `node` ni le script). */
export function parseArgs(argv: readonly string[]): CatalogSeedArgs {
  let withPhotos = true;
  for (const arg of argv) {
    if (arg === '--sans-photos') {
      withPhotos = false;
    } else {
      throw new UsageError(`Option inconnue : « ${arg} ».`);
    }
  }
  return { withPhotos };
}

function usage(): string {
  return [
    'Usage : node dist/cli/catalog-seed [--sans-photos]',
    '  Charge (ou met à jour) le catalogue d’exercices : groupes musculaires,',
    '  matériels, exercices publiés, et leurs photos dans le stockage objet.',
    '  Idempotent — rejouable sans doublon. --sans-photos saute le stockage.',
  ].join('\n');
}

/**
 * Purge le cache du catalogue. Rendu séparément testable, et TOLÉRANT :
 * un Redis absent laisse le TTL faire son office, il n'annule pas un
 * chargement déjà réussi.
 */
export async function purgeCatalogCache(redisUrl: string): Promise<number | null> {
  const client = new Redis(redisUrl, {
    lazyConnect: true,
    maxRetriesPerRequest: 1,
    enableOfflineQueue: false,
    retryStrategy: () => null,
  });
  // Sans écouteur, ioredis imprime « [ioredis] Unhandled error event » sur
  // stderr AVANT notre message propre — le même échec serait dit deux fois,
  // dont une en pile brute qui ressemble à un plantage.
  client.on('error', () => {});
  try {
    await client.connect();
    return await purgePrefix(client, CATALOG_CACHE_PREFIX);
  } catch {
    return null;
  } finally {
    client.disconnect();
  }
}

async function main(argv: readonly string[]): Promise<number> {
  let args: CatalogSeedArgs;
  try {
    args = parseArgs(argv);
  } catch (error) {
    process.stderr.write(`${(error as Error).message}\n\n${usage()}\n`);
    return 2;
  }

  // Dans le try : une configuration invalide doit sortir en « Échec : … »
  // avec un code maîtrisé, pas en rejet non géré à pile brute.
  let config: AppConfigService;
  try {
    const env: Env = validateEnv(process.env);
    config = new AppConfigService(new ConfigService<Env, true>(env));
  } catch (error) {
    process.stderr.write(`Échec : ${(error as Error).message}\n`);
    return 1;
  }
  const prisma = new PrismaClient({ datasourceUrl: config.databaseUrl });
  try {
    const summary = await syncCatalog(prisma);

    // Les photos DEMANDÉES qui ne partent pas sont un ÉCHEC, pas une note de
    // bas de page : sur un serveur, cette commande démarre MinIO exprès. Qui
    // veut un catalogue sans illustrations le dit avec --sans-photos.
    let photos = 'sautées (--sans-photos).';
    if (args.withPhotos) {
      const outcome = await syncExerciseMedia(prisma);
      if (outcome.status !== 'ok') {
        const cause = switchPhotoFailure(outcome.status);
        process.stderr.write(
          `Échec : le catalogue (textes) est chargé, mais les photos n'ont pas pu partir — ${cause}\n` +
            'Corriger la configuration du stockage objet (S3_*) puis relancer, ' +
            'ou assumer un catalogue sans illustrations avec --sans-photos.\n',
        );
        await purgeCatalogCache(config.redisUrl);
        return 1;
      }
      photos =
        `${outcome.attached} déposées dans le stockage objet` +
        (outcome.missing > 0 ? ` (${outcome.missing} sans exercice correspondant)` : '') +
        '.';
    }

    const purged = await purgeCatalogCache(config.redisUrl);
    process.stdout.write(
      [
        'Catalogue chargé.',
        `  groupes musculaires : ${summary.muscleGroups}`,
        `  matériels           : ${summary.equipment}`,
        `  exercices publiés   : ${summary.exercises}`,
        `  photos              : ${photos}`,
        purged === null
          ? '  cache : Redis injoignable — les listes se rafraîchiront au TTL (≤ 1 h).'
          : `  cache : ${purged} clé(s) « catalog: » purgée(s), l'API sert le nouveau catalogue immédiatement.`,
        '',
      ].join('\n'),
    );
    return 0;
  } catch (error) {
    process.stderr.write(`Échec : ${(error as Error).message}\n`);
    return 1;
  } finally {
    await prisma.$disconnect();
  }
}

function switchPhotoFailure(
  status: 'sans-stockage' | 'sans-dossier' | 'stockage-injoignable',
): string {
  return {
    'sans-stockage': 'les variables S3_* ne sont pas configurées.',
    'sans-dossier': 'le dossier prisma/seed-media/exercises est absent de cette image.',
    'stockage-injoignable': 'le stockage objet ne répond pas (détail ci-dessus).',
  }[status];
}

if (require.main === module) {
  main(process.argv.slice(2))
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error: unknown) => {
      process.stderr.write(`Échec : ${(error as Error).message}\n`);
      process.exitCode = 1;
    });
}
