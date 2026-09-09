import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { type PrismaClient } from '@prisma/client';
import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { seedExerciseMedia } from './seed-media';

jest.mock('node:fs/promises', () => ({ readdir: jest.fn(), readFile: jest.fn() }));

describe('photos du seed', () => {
  const env = { ...process.env };
  const upsert = jest.fn();
  const prisma = {
    exercise: { findUnique: jest.fn().mockResolvedValue({ id: 'exercise' }), update: jest.fn() },
    mediaAsset: { upsert },
  } as unknown as PrismaClient;

  beforeEach(() => {
    jest.clearAllMocks();
    Object.assign(process.env, {
      S3_ENDPOINT: 'http://localhost:9000',
      S3_BUCKET: 'test',
      S3_ACCESS_KEY_ID: 'test',
      S3_SECRET_ACCESS_KEY: 'test',
    });
    jest.spyOn(S3Client.prototype, 'send').mockResolvedValue({} as never);
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
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
      await seedExerciseMedia(prisma);
      const checksum = createHash('sha256').update(content).digest('hex');
      const command = jest.mocked(S3Client.prototype.send).mock.calls[0]![0] as PutObjectCommand;
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
    await seedExerciseMedia(prisma);
    await seedExerciseMedia(prisma);
    const first = upsert.mock.calls[0]![0];
    const second = upsert.mock.calls[1]![0];
    expect(first.where.id).toBe(second.where.id);
    expect(first.update.storageKey).not.toBe(second.update.storageKey);
  });
});
