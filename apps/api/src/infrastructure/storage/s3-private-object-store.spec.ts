import {
  DeleteObjectCommand,
  GetBucketPolicyCommand,
  type GetObjectCommand,
  HeadBucketCommand,
  type ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { type AppConfigService } from '../../config/app-config.service';
import { S3PrivateObjectStore } from './s3-private-object-store';

const config = {
  s3Endpoint: 'http://localhost:9000',
  s3Region: 'us-east-1',
  s3ForcePathStyle: true,
  s3AccessKeyId: 'cle',
  s3SecretAccessKey: 'secret',
  s3Bucket: 'carlys-media',
  s3PrivateBucket: 'carlys-private',
} as unknown as AppConfigService;

function namedError(name: string): Error {
  return Object.assign(new Error(name), { name });
}

describe('S3PrivateObjectStore', () => {
  let send: jest.SpyInstance;
  let store: S3PrivateObjectStore;

  beforeEach(() => {
    send = jest.spyOn(S3Client.prototype, 'send');
    store = new S3PrivateObjectStore(config);
  });

  afterEach(() => {
    send.mockRestore();
    store.onModuleDestroy();
  });

  it('écrit dans le bucket PRIVÉ, jamais dans celui des médias publics', async () => {
    send.mockResolvedValue({});

    await store.put('meal-photos/u/p.jpg', Buffer.from('x'), 'image/jpeg');
    await store.delete('meal-photos/u/p.jpg');

    const [put] = send.mock.calls[0] as [PutObjectCommand];
    const [removal] = send.mock.calls[1] as [DeleteObjectCommand];
    expect(put).toBeInstanceOf(PutObjectCommand);
    expect(put.input).toMatchObject({
      Bucket: 'carlys-private',
      Key: 'meal-photos/u/p.jpg',
      ContentType: 'image/jpeg',
      CacheControl: 'private, no-store',
    });
    expect(removal).toBeInstanceOf(DeleteObjectCommand);
    expect(removal.input.Bucket).toBe('carlys-private');
  });

  it('lit les octets ; une clé absente rend null, une autre panne remonte', async () => {
    send.mockResolvedValueOnce({
      Body: { transformToByteArray: () => Promise.resolve(new Uint8Array([1, 2, 3])) },
    });
    expect(await store.get('k')).toEqual(Buffer.from([1, 2, 3]));
    expect((send.mock.calls[0] as [GetObjectCommand])[0].input.Bucket).toBe('carlys-private');

    send.mockRejectedValueOnce(namedError('NoSuchKey'));
    expect(await store.get('absente')).toBeNull();

    send.mockRejectedValueOnce(namedError('InternalError'));
    await expect(store.get('k')).rejects.toThrow('InternalError');
  });

  it('liste par page, avec le curseur de S3', async () => {
    const date = new Date('2026-09-25T10:00:00Z');
    send.mockResolvedValueOnce({
      Contents: [{ Key: 'meal-photos/a.jpg', LastModified: date }],
      IsTruncated: true,
      NextContinuationToken: 'suite',
    });

    const page = await store.list('meal-photos/', null);

    expect(page).toEqual({
      objects: [{ key: 'meal-photos/a.jpg', lastModified: date }],
      next: 'suite',
    });
    const [list] = send.mock.calls[0] as [ListObjectsV2Command];
    expect(list.input).toMatchObject({ Bucket: 'carlys-private', Prefix: 'meal-photos/' });
  });

  it('inspection : sans politique, c’est sain ; avec une politique, c’est signalé', async () => {
    send.mockImplementation((command: unknown) =>
      command instanceof GetBucketPolicyCommand
        ? Promise.reject(namedError('NoSuchBucketPolicy'))
        : Promise.resolve({}),
    );
    expect(await store.inspect()).toEqual({ state: 'ok' });

    send.mockImplementation((command: unknown) =>
      command instanceof HeadBucketCommand || command instanceof GetBucketPolicyCommand
        ? Promise.resolve({ Policy: '{"Statement":[{"Principal":"*"}]}' })
        : Promise.resolve({}),
    );
    expect(await store.inspect()).toEqual({ state: 'has-policy' });

    send.mockRejectedValue(namedError('NotFound'));
    expect(await store.inspect()).toMatchObject({ state: 'unreachable' });
  });
});
