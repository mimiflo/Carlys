import { type PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { type PrismaClient } from '@prisma/client';
import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { syncExerciseMedia } from './catalog-media-sync';

jest.mock('node:fs/promises', () => ({ readdir: jest.fn(), readFile: jest.fn() }));

/** La forme de l'upsert que le test inspecte — typée pour rester lisible. */
interface UpsertArgs {
  where: { id: string };
  update: {
    mimeType: string;
    checksum: string;
    storageKey: string;
    width?: number | null;
    height?: number | null;
  };
}

describe('photos du seed', () => {
  const env = { ...process.env };
  const upsert = jest.fn<Promise<unknown>, [UpsertArgs]>();
  /** Ce que la base porte DÉJÀ pour ce média : un retrait ne se défait pas. */
  const findMedia = jest.fn<Promise<{ deletedAt: Date | null } | null>, [unknown]>();
  /**
   * Le rattachement ne s'impose qu'aux exercices portant ENCORE cette photo
   * (ou aucune) : zéro ligne touchée = décision du back-office.
   */
  const attachImage = jest.fn<Promise<{ count: number }>, [unknown]>();
  const prisma = {
    exercise: {
      findUnique: jest.fn().mockResolvedValue({ id: 'exercise' }),
      updateMany: attachImage,
    },
    mediaAsset: { upsert, findUnique: findMedia },
  } as unknown as PrismaClient;
  let send: jest.SpiedFunction<typeof S3Client.prototype.send>;

  beforeEach(() => {
    jest.clearAllMocks();
    // Le cas ordinaire : média jamais retiré, exercice rattaché.
    findMedia.mockResolvedValue(null);
    attachImage.mockResolvedValue({ count: 1 });
    Object.assign(process.env, {
      S3_ENDPOINT: 'http://localhost:9000',
      S3_BUCKET: 'test',
      S3_ACCESS_KEY_ID: 'test',
      S3_SECRET_ACCESS_KEY: 'test',
    });
    send = jest.spyOn(S3Client.prototype, 'send').mockResolvedValue({} as never);
    jest.spyOn(process.stdout, 'write').mockImplementation(() => true);
  });

  afterEach(() => {
    process.env = { ...env };
    jest.restoreAllMocks();
  });

  it.each(['png', 'webp'])(
    'publie le format %s avec son MIME et une URL versionnée',
    async (extension) => {
      const content = Buffer.alloc(32);
      if (extension === 'png') {
        content.writeUInt32BE(0x89504e47, 0);
        content.writeUInt32BE(1536, 16);
        content.writeUInt32BE(1152, 20);
      }
      jest.mocked(readdir).mockResolvedValue([`developpe-couche.${extension}`] as never);
      jest.mocked(readFile).mockResolvedValue(content);
      await syncExerciseMedia(prisma);
      const checksum = createHash('sha256').update(content).digest('hex');
      const command = send.mock.calls[0]![0] as PutObjectCommand;
      expect(command.input.ContentType).toBe(`image/${extension}`);
      expect(command.input.Key).toContain(`-${checksum}.${extension}`);
      expect(upsert.mock.calls[0]![0].update).toMatchObject({
        mimeType: `image/${extension}`,
        checksum,
        storageKey: command.input.Key,
        ...(extension === 'png' ? { width: 1536, height: 1152 } : {}),
      });
    },
  );

  it('garde le même média mais renouvelle son URL quand les octets changent', async () => {
    jest.mocked(readdir).mockResolvedValue(['developpe-couche.png'] as never);
    jest
      .mocked(readFile)
      .mockResolvedValueOnce(Buffer.from('version1'))
      .mockResolvedValueOnce(Buffer.from('version2'));
    await syncExerciseMedia(prisma);
    await syncExerciseMedia(prisma);
    const first = upsert.mock.calls[0]![0];
    const second = upsert.mock.calls[1]![0];
    expect(first.where.id).toBe(second.where.id);
    expect(first.update.storageKey).not.toBe(second.update.storageKey);
  });

  it('ne ressuscite pas un média que le back-office a supprimé', async () => {
    // Le chargement forçait `deletedAt: null` puis réécrivait `imageId` : une
    // photo retirée depuis l'administration revenait à CHAQUE déploiement, et
    // celle choisie à la main était remplacée par celle du dépôt.
    jest.mocked(readdir).mockResolvedValue(['developpe-couche.png'] as never);
    jest.mocked(readFile).mockResolvedValue(Buffer.from('version1'));
    findMedia.mockResolvedValue({ deletedAt: new Date('2026-09-01T10:00:00.000Z') });

    const outcome = await syncExerciseMedia(prisma);

    expect(outcome).toMatchObject({ status: 'ok', attached: 0, keptAdmin: 1 });
    // Le contenu se met à jour, la suppression ne se défait pas.
    expect(upsert.mock.calls[0]![0].update).not.toHaveProperty('deletedAt');
    expect(attachImage).not.toHaveBeenCalled();
  });

  it('laisse l’exercice dont le back-office a choisi une AUTRE photo', async () => {
    jest.mocked(readdir).mockResolvedValue(['developpe-couche.png'] as never);
    jest.mocked(readFile).mockResolvedValue(Buffer.from('version1'));
    // Zéro ligne mise à jour : l'exercice porte une image choisie à la main.
    attachImage.mockResolvedValue({ count: 0 });

    const outcome = await syncExerciseMedia(prisma);

    expect(outcome).toMatchObject({ status: 'ok', attached: 0, keptAdmin: 1 });
    // Le média lui-même reste à jour : c'est le RATTACHEMENT qu'on laisse.
    expect(upsert).toHaveBeenCalledTimes(1);
  });
});
