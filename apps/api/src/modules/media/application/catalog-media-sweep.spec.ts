import {
  DeleteObjectCommand,
  ListObjectsV2Command,
  type ListObjectsV2CommandOutput,
  type S3Client,
} from '@aws-sdk/client-s3';
import { type PrismaClient } from '@prisma/client';
import { createHash } from 'node:crypto';
import { derivedUuid } from '../../../common/utilities/derived-uuid';
import { SEED_SWEEP_GRACE_MS, sweepSupersededSeedMedia } from './catalog-media-sweep';
import { seedMediaIdOf, seedMediaKey } from './catalog-media-sync';

/**
 * CE QUE CE FICHIER PROTÈGE : une illustration remplacée quitte le stockage,
 * et RIEN d'autre n'en sort.
 *
 * Changer une photo du catalogue dépose un nouvel objet (sa clé porte son
 * empreinte) et laissait l'ancien pour toujours : 13,6 Mo au passage des
 * quatorze PNG en WebP. Le balayage efface la version précédente, jamais la
 * courante, jamais un dépôt d'administration, jamais un dépôt en cours.
 */

const NOW = new Date('2026-09-25T12:00:00.000Z');
const ANCIEN = new Date(NOW.getTime() - SEED_SWEEP_GRACE_MS - 1);
const RECENT = new Date(NOW.getTime() - SEED_SWEEP_GRACE_MS + 60_000);

const ID = '2f1c9a4e-0b7d-4c3e-8a15-6d0e9b8c7a21';
const AUTRE_ID = '7a0e5d3c-1b2f-4e6d-9c8b-0f1e2d3c4b5a';
const empreinte = (chiffre: string) => chiffre.repeat(64);
const cleSeed = (id: string, chiffre: string, extension: 'png' | 'webp' = 'webp') =>
  seedMediaKey(id, empreinte(chiffre), extension);

const COURANTE = cleSeed(ID, 'b');
const PRECEDENTE = cleSeed(ID, 'a', 'png');

type Objet = { Key: string; LastModified: Date };

/**
 * Un stockage en mémoire : `pages` est ce que la liste rend, page par page ;
 * `refusee` est une clé dont l'effacement échoue.
 */
function banc(
  pages: Objet[][],
  lignes: Array<{ id: string; storageKey: string }>,
  refusee?: string,
) {
  const effacees: string[] = [];
  const listes: ListObjectsV2Command['input'][] = [];
  const send = jest.fn((command: unknown): Promise<unknown> => {
    if (command instanceof ListObjectsV2Command) {
      listes.push(command.input);
      const numero = Number(command.input.ContinuationToken ?? '0');
      const suivante = numero + 1 < pages.length ? String(numero + 1) : undefined;
      const page: Partial<ListObjectsV2CommandOutput> = {
        Contents: pages[numero] ?? [],
        IsTruncated: suivante !== undefined,
        NextContinuationToken: suivante,
      };
      return Promise.resolve(page);
    }
    if (command instanceof DeleteObjectCommand) {
      const key = command.input.Key ?? '';
      if (key === refusee) {
        return Promise.reject(new Error('AccessDenied'));
      }
      effacees.push(key);
      return Promise.resolve({});
    }
    return Promise.reject(new Error('commande inattendue'));
  });
  const client = { send } as unknown as S3Client;
  const findMany = jest.fn().mockResolvedValue(lignes);
  const prisma = { mediaAsset: { findMany } } as unknown as Pick<PrismaClient, 'mediaAsset'>;
  const balayer = () => sweepSupersededSeedMedia(prisma, { client, bucket: 'carlys-media' }, NOW);
  return { balayer, effacees, listes, findMany };
}

describe('clé de seed', () => {
  // Le balayage ne reconnaît que la forme que le chargement ÉCRIT : si l'une
  // change sans l'autre, plus rien n'est balayé, sans un mot.
  it('reconnaît la clé qu’écrit le chargement, et elle seule', () => {
    const id = derivedUuid('carlys.seed.media', 'developpe-couche');
    const sha = createHash('sha256').update('octets').digest('hex');

    expect(seedMediaIdOf(seedMediaKey(id, sha, 'webp'))).toBe(id);
    expect(seedMediaIdOf(seedMediaKey(id, sha, 'png'))).toBe(id);
    expect(seedMediaIdOf(`image/${id}.webp`)).toBeNull();
    expect(seedMediaIdOf(`mesh_3d/${id}-${sha}.glb`)).toBeNull();
  });
});

describe('sweepSupersededSeedMedia', () => {
  it('efface la version PRÉCÉDENTE d’une photo changée, garde la courante', async () => {
    const { balayer, effacees } = banc(
      [
        [
          { Key: PRECEDENTE, LastModified: ANCIEN },
          { Key: COURANTE, LastModified: ANCIEN },
        ],
      ],
      [{ id: ID, storageKey: COURANTE }],
    );

    const rapport = await balayer();

    expect(effacees).toEqual([PRECEDENTE]);
    expect(rapport).toEqual({ scanned: 2, deleted: 1, failures: [] });
  });

  it('ne touche jamais un dépôt d’administration, sans empreinte dans sa clé', async () => {
    const depotAdmin = `image/${AUTRE_ID}.webp`;
    const { balayer, effacees, findMany } = banc(
      [[{ Key: depotAdmin, LastModified: ANCIEN }]],
      [{ id: AUTRE_ID, storageKey: `image/${AUTRE_ID}.jpg` }],
    );

    await balayer();

    expect(effacees).toEqual([]);
    expect(findMany).not.toHaveBeenCalled();
  });

  it('épargne un objet sans ligne : son dépôt est peut-être en cours', async () => {
    const { balayer, effacees } = banc([[{ Key: PRECEDENTE, LastModified: ANCIEN }]], []);

    await balayer();

    expect(effacees).toEqual([]);
  });

  it('épargne un objet récent : un chargement concurrent va peut-être le citer', async () => {
    const { balayer, effacees } = banc(
      [[{ Key: PRECEDENTE, LastModified: RECENT }]],
      [{ id: ID, storageKey: COURANTE }],
    );

    await balayer();

    expect(effacees).toEqual([]);
  });

  it('lit toutes les pages du préfixe, et seulement lui', async () => {
    const autrePrecedente = cleSeed(AUTRE_ID, 'c');
    const { balayer, effacees, listes } = banc(
      [
        [{ Key: PRECEDENTE, LastModified: ANCIEN }],
        [{ Key: autrePrecedente, LastModified: ANCIEN }],
      ],
      [
        { id: ID, storageKey: COURANTE },
        { id: AUTRE_ID, storageKey: cleSeed(AUTRE_ID, 'd') },
      ],
    );

    const rapport = await balayer();

    expect(effacees).toEqual([PRECEDENTE, autrePrecedente]);
    expect(rapport.scanned).toBe(2);
    expect(listes).toHaveLength(2);
    expect(listes[0]).toMatchObject({ Bucket: 'carlys-media', Prefix: 'image/' });
  });

  it('un effacement refusé est dit, et le balayage continue', async () => {
    const autrePrecedente = cleSeed(AUTRE_ID, 'c');
    const { balayer, effacees } = banc(
      [
        [
          { Key: PRECEDENTE, LastModified: ANCIEN },
          { Key: autrePrecedente, LastModified: ANCIEN },
        ],
      ],
      [
        { id: ID, storageKey: COURANTE },
        { id: AUTRE_ID, storageKey: cleSeed(AUTRE_ID, 'd') },
      ],
      PRECEDENTE,
    );

    const rapport = await balayer();

    expect(effacees).toEqual([autrePrecedente]);
    expect(rapport.deleted).toBe(1);
    expect(rapport.failures).toEqual([`${PRECEDENTE} : AccessDenied`]);
  });
});
