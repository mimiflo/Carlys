/**
 * Photos du catalogue livrées avec le seed.
 *
 * Les fichiers sont DÉTOURÉS (WebP à canal alpha) : la figure seule, sans
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
 */
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { type PrismaClient } from '@prisma/client';
import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { readImageSize } from '../src/modules/media/application/image-size';

const MEDIA_DIRECTORY = join(__dirname, 'seed-media', 'exercises');

/** Namespace propre au projet : deux slugs distincts, deux identifiants. */
const NAMESPACE = 'carlys.seed.media';

/**
 * Identifiant DÉTERMINISTE d'un média de seed, dérivé de son slug.
 *
 * C'est ce qui rend l'étape rejouable : re-seeder ne crée pas un second média
 * ni un second objet, il retombe sur le même identifiant — donc sur la même
 * clé de stockage, puisque la clé EST l'identifiant.
 */
function mediaIdFor(slug: string): string {
  const hash = createHash('sha256').update(`${NAMESPACE}:${slug}`).digest();
  const bytes = Buffer.from(hash.subarray(0, 16));
  // Version 4 et variante RFC 4122 : un UUID valide, mais reproductible.
  bytes[6] = (bytes[6]! & 0x0f) | 0x40;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20),
  ].join('-');
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

export async function seedExerciseMedia(prisma: PrismaClient): Promise<void> {
  const storage = storageOf();
  if (storage === null) {
    console.warn('Stockage objet non configuré : photos du catalogue ignorées.');
    return;
  }

  let files: string[];
  try {
    files = (await readdir(MEDIA_DIRECTORY)).filter((name) => name.endsWith('.webp'));
  } catch {
    console.warn('Aucun dossier de photos de seed : étape ignorée.');
    return;
  }

  let attached = 0;
  let missing = 0;
  for (const file of files.sort()) {
    const slug = file.replace(/\.webp$/, '');
    const exercise = await prisma.exercise.findUnique({ where: { slug }, select: { id: true } });
    if (exercise === null) {
      // Une photo sans exercice n'est pas une erreur : le catalogue et les
      // illustrations n'avancent pas forcément au même rythme.
      missing++;
      continue;
    }

    const content = await readFile(join(MEDIA_DIRECTORY, file));
    const id = mediaIdFor(slug);
    const storageKey = `image/${id}.webp`;
    const size = readImageSize(content);

    try {
      await storage.client.send(
        new PutObjectCommand({
          Bucket: storage.bucket,
          Key: storageKey,
          Body: content,
          ContentType: 'image/webp',
          CacheControl: 'public, max-age=31536000, immutable',
        }),
      );
    } catch (error) {
      console.warn(
        `Stockage injoignable (${(error as Error).message}) : photos du catalogue ignorées.`,
      );
      return;
    }

    const data = {
      kind: 'IMAGE' as const,
      storageKey,
      mimeType: 'image/webp',
      byteSize: content.byteLength,
      width: size?.width ?? null,
      height: size?.height ?? null,
      checksum: createHash('sha256').update(content).digest('hex'),
      originalName: file,
      deletedAt: null,
    };
    await prisma.mediaAsset.upsert({
      where: { id },
      create: { id, ...data },
      update: data,
    });
    await prisma.exercise.update({ where: { id: exercise.id }, data: { imageId: id } });
    attached++;
  }

  console.log(
    `Photos du catalogue : ${attached} rattachées` +
      (missing > 0 ? `, ${missing} sans exercice correspondant` : ''),
  );
}
