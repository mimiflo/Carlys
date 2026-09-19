/**
 * Photos du catalogue livrées avec le seed.
 *
 * Les fichiers sont DÉTOURÉS (PNG ou WebP à canal alpha) : la figure seule, sans
 * fond. C'est ce qui permet aux écrans de les poser sur leur propre fond
 * sombre — et c'est pourquoi ils s'affichent en `contain`, jamais en `cover`,
 * qui rognerait les bras et les barres.
 *
 * Ce n'est PAS une entorse à l'ADR 0009 : rien n'est embarqué dans
 * l'application mobile. Ces fichiers suivent exactement le chemin d'un dépôt
 * d'administration — stockage objet, ligne `MediaAsset`, URL publique — mais
 * ils partent avec le catalogue qu'ils illustrent, comme son texte. Une fois
 * en place, l'administration les remplace comme n'importe quel autre média.
 *
 * Le stockage n'est pas une dépendance du seed : s'il est injoignable ou non
 * configuré, cette étape prévient et passe. Un développeur qui ne fait tourner
 * que PostgreSQL obtient un catalogue complet, simplement sans illustrations.
 *
 * Dans `src/` (compilé) et non dans `prisma/` : `dist/cli/catalog-seed`
 * exécute ce code sur un serveur, où ts-node n'existe pas. Les FICHIERS
 * photos, eux, restent sous `prisma/seed-media/exercises` — présents dans
 * l'image de production (le Dockerfile copie `prisma/` entier) comme dans le
 * dépôt ; le dossier se résout depuis le répertoire courant, identique en
 * développement (`apps/api`) et dans l'image (`/app`).
 */
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { type PrismaClient } from '@prisma/client';
import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { derivedUuid } from '../../../common/utilities/derived-uuid';
import { readImageSize } from './image-size';

const MEDIA_DIRECTORY = join(process.cwd(), 'prisma', 'seed-media', 'exercises');

/** Namespace propre au projet : deux slugs distincts, deux identifiants. */
const NAMESPACE = 'carlys.seed.media';

/**
 * Identifiant DÉTERMINISTE d'un média de seed, dérivé de son slug.
 *
 * C'est ce qui rend l'étape rejouable : re-seeder ne crée pas un second
 * média. La clé de stockage inclut le checksum pour renouveler les caches
 * immuables lorsque l'illustration change.
 *
 * Le calcul lui-même vit dans `common/utilities/derived-uuid.ts` depuis que la
 * génération de programme en a eu besoin : une seule définition, deux
 * namespaces.
 */
function mediaIdFor(slug: string): string {
  return derivedUuid(NAMESPACE, slug);
}

interface StorageSettings {
  client: S3Client;
  bucket: string;
}

function storageOf(): StorageSettings | null {
  const { S3_ENDPOINT, S3_BUCKET, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY } = process.env;
  if (!S3_ENDPOINT || !S3_BUCKET || !S3_ACCESS_KEY_ID || !S3_SECRET_ACCESS_KEY) {
    return null;
  }
  return {
    bucket: S3_BUCKET,
    client: new S3Client({
      endpoint: S3_ENDPOINT,
      region: process.env.S3_REGION ?? 'us-east-1',
      forcePathStyle: (process.env.S3_FORCE_PATH_STYLE ?? 'true') !== 'false',
      credentials: {
        accessKeyId: S3_ACCESS_KEY_ID,
        secretAccessKey: S3_SECRET_ACCESS_KEY,
      },
    }),
  };
}

/**
 * Ce que la passe des photos a réellement fait — pour que l'appelant décide.
 * Le seed de développement s'en moque (tolérance voulue : un poste sans
 * MinIO garde un catalogue complet, sans illustrations) ; le CLI serveur,
 * lui, ÉCHOUE quand les photos étaient demandées et n'ont pas pu partir.
 */
export type ExerciseMediaOutcome =
  | {
      readonly status: 'ok';
      readonly attached: number;
      readonly missing: number;
      /** Photos de seed que l'ADMINISTRATION a remplacées ou retirées : laissées. */
      readonly keptAdmin: number;
    }
  | { readonly status: 'sans-stockage' }
  | { readonly status: 'sans-dossier' }
  | { readonly status: 'stockage-injoignable'; readonly reason: string };

export async function syncExerciseMedia(
  prisma: PrismaClient,
  directory: string = MEDIA_DIRECTORY,
): Promise<ExerciseMediaOutcome> {
  const storage = storageOf();
  if (storage === null) {
    console.warn('Stockage objet non configuré : photos du catalogue ignorées.');
    return { status: 'sans-stockage' };
  }

  let files: string[];
  try {
    files = (await readdir(directory)).filter((name) => /\.(png|webp)$/.test(name));
  } catch {
    console.warn('Aucun dossier de photos de seed : étape ignorée.');
    return { status: 'sans-dossier' };
  }

  let attached = 0;
  let missing = 0;
  let keptAdmin = 0;
  for (const file of files.sort()) {
    const slug = file.replace(/\.(png|webp)$/, '');
    const exercise = await prisma.exercise.findUnique({ where: { slug }, select: { id: true } });
    if (exercise === null) {
      // Une photo sans exercice n'est pas une erreur : le catalogue et les
      // illustrations n'avancent pas forcément au même rythme.
      missing++;
      continue;
    }

    const content = await readFile(join(directory, file));
    const id = mediaIdFor(slug);
    const extension = file.endsWith('.png') ? 'png' : 'webp';
    const mimeType = `image/${extension}`;
    const checksum = createHash('sha256').update(content).digest('hex');
    const storageKey = `image/${id}-${checksum}.${extension}`;
    const size = readImageSize(content);

    try {
      await storage.client.send(
        new PutObjectCommand({
          Bucket: storage.bucket,
          Key: storageKey,
          Body: content,
          ContentType: mimeType,
          CacheControl: 'public, max-age=31536000, immutable',
        }),
      );
    } catch (error) {
      console.warn(
        `Stockage injoignable (${(error as Error).message}) : photos du catalogue ignorées.`,
      );
      return { status: 'stockage-injoignable', reason: (error as Error).message };
    }

    // CE QUE L'ADMINISTRATION A DÉCIDÉ FAIT FOI, comme pour les exercices
    // eux-mêmes (`syncCatalog` et son `keptDeleted`). Ce code forçait
    // `deletedAt: null` puis réécrivait `exercise.imageId` : une photo de
    // seed supprimée depuis le back-office RESSUSCITAIT à chaque
    // déploiement, et la photo choisie à la main était remplacée par celle
    // du dépôt. Le contenu se met à jour, la DÉCISION ne se défait pas.
    const existing = await prisma.mediaAsset.findUnique({
      where: { id },
      select: { deletedAt: true },
    });
    const data = {
      kind: 'IMAGE' as const,
      storageKey,
      mimeType,
      byteSize: content.byteLength,
      width: size?.width ?? null,
      height: size?.height ?? null,
      checksum,
      originalName: file,
    };
    await prisma.mediaAsset.upsert({
      where: { id },
      create: { id, ...data, deletedAt: null },
      // `deletedAt` n'est PAS touché : un média retiré le reste, son
      // contenu se met simplement à jour s'il revient un jour.
      update: data,
    });
    if (existing?.deletedAt != null) {
      keptAdmin++;
      continue;
    }
    // Le rattachement ne s'impose qu'aux exercices qui portent ENCORE cette
    // photo-là (ou aucune) : celui dont l'administration a choisi une autre
    // image garde la sienne.
    const { count } = await prisma.exercise.updateMany({
      where: { id: exercise.id, OR: [{ imageId: null }, { imageId: id }] },
      data: { imageId: id },
    });
    if (count === 0) {
      keptAdmin++;
      continue;
    }
    attached++;
  }

  process.stdout.write(
    `Photos du catalogue : ${attached} rattachées` +
      (missing > 0 ? `, ${missing} sans exercice correspondant` : '') +
      (keptAdmin > 0 ? `, ${keptAdmin} laissée(s) à la décision du back-office` : '') +
      '\n',
  );
  return { status: 'ok', attached, missing, keptAdmin };
}
