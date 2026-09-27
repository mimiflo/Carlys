/**
 * Efface du bucket PUBLIC les versions PRÉCÉDENTES des photos du catalogue.
 *
 * La clé d'une photo de seed porte son empreinte (`image/<id>-<sha256>.<ext>`,
 * voir `syncExerciseMedia`) : changer une illustration dépose un NOUVEL objet
 * et repointe la ligne `MediaAsset`, sans toucher à l'ancien. Rien ne
 * l'effaçait. Le passage des quatorze PNG en WebP en laissait 13,6 Mo, et les
 * deux changements d'illustration d'avant (2c296d7, 3f9fcfa) autant d'autres,
 * que la sauvegarde de MinIO recopiait chaque nuit.
 *
 * UN BALAYAGE, pas un effacement au fil de l'eau : il retrouve aussi les
 * versions laissées par les chargements passés, et un passage manqué (cache
 * non purgé, stockage capricieux) se rattrape au suivant.
 *
 * Est effacé un objet qui réunit les quatre conditions :
 * - sa clé a la forme d'une clé de SEED. Un dépôt d'administration
 *   (`image/<id>.<ext>`, sans empreinte, `StorageService.keyFor`) n'est
 *   jamais candidat ;
 * - sa ligne `MediaAsset` EXISTE. Un objet sans ligne est peut-être un dépôt
 *   en cours, dont le PUT précède l'upsert ;
 * - cette ligne pointe AILLEURS : la version courante n'est jamais touchée,
 *   même celle d'un média que l'administration a retiré ;
 * - il a plus d'une heure. Un chargement concurrent a pu déposer la nouvelle
 *   version sans avoir encore repointé la ligne : sans ce délai, on
 *   effacerait l'objet qu'il s'apprête à citer.
 *
 * À appeler APRÈS la purge du cache du catalogue (`catalog-seed`) : avant,
 * une liste encore en cache servirait l'URL de l'objet effacé.
 */
import { DeleteObjectCommand, ListObjectsV2Command, type S3Client } from '@aws-sdk/client-s3';
import { type PrismaClient } from '@prisma/client';
import { seedMediaIdOf } from './catalog-media-sync';

/** Délai de grâce : un objet plus jeune est épargné (voir plus haut). */
export const SEED_SWEEP_GRACE_MS = 60 * 60_000;

export interface SeedMediaSweep {
  /** Objets du préfixe `image/` lus. */
  readonly scanned: number;
  /** Versions précédentes effacées. */
  readonly deleted: number;
  /** Une ligne par effacement refusé : le balayage continue, il le dit. */
  readonly failures: readonly string[];
}

interface Candidate {
  readonly key: string;
  readonly id: string;
}

export async function sweepSupersededSeedMedia(
  prisma: Pick<PrismaClient, 'mediaAsset'>,
  storage: { readonly client: S3Client; readonly bucket: string },
  now: Date = new Date(),
): Promise<SeedMediaSweep> {
  const { scanned, candidates } = await listSeedObjects(storage, now);
  if (candidates.length === 0) {
    return { scanned, deleted: 0, failures: [] };
  }

  const rows = await prisma.mediaAsset.findMany({
    where: { id: { in: [...new Set(candidates.map((candidate) => candidate.id))] } },
    select: { id: true, storageKey: true },
  });
  const current = new Map(rows.map((row) => [row.id, row.storageKey]));

  let deleted = 0;
  const failures: string[] = [];
  for (const { key, id } of candidates) {
    const courante = current.get(id);
    if (courante === undefined || courante === key) {
      continue;
    }
    try {
      await storage.client.send(new DeleteObjectCommand({ Bucket: storage.bucket, Key: key }));
      deleted += 1;
    } catch (error) {
      failures.push(`${key} : ${(error as Error).message}`);
    }
  }
  return { scanned, deleted, failures };
}

/** Les objets de seed assez anciens pour être candidats, page par page. */
async function listSeedObjects(
  storage: { readonly client: S3Client; readonly bucket: string },
  now: Date,
): Promise<{ scanned: number; candidates: Candidate[] }> {
  const limite = now.getTime() - SEED_SWEEP_GRACE_MS;
  const candidates: Candidate[] = [];
  let scanned = 0;
  let cursor: string | undefined;
  do {
    const page = await storage.client.send(
      new ListObjectsV2Command({
        Bucket: storage.bucket,
        Prefix: 'image/',
        ContinuationToken: cursor,
      }),
    );
    for (const object of page.Contents ?? []) {
      scanned += 1;
      const id = object.Key === undefined ? null : seedMediaIdOf(object.Key);
      // Sans date de dépôt, on ne sait pas l'âge : on épargne.
      const depose = object.LastModified?.getTime() ?? now.getTime();
      if (id !== null && object.Key !== undefined && depose <= limite) {
        candidates.push({ key: object.Key, id });
      }
    }
    cursor = page.IsTruncated === true ? page.NextContinuationToken : undefined;
  } while (cursor !== undefined);
  return { scanned, candidates };
}
