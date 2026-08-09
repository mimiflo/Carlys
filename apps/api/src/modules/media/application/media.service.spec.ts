import {
  BadRequestException,
  NotFoundException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { type MediaAsset } from '@prisma/client';
import { type AppConfigService } from '../../../config/app-config.service';
import { type StorageService } from '../../../infrastructure/storage/storage.service';
import { type AuditService } from '../../audit/audit.service';
import { type ExercisesService } from '../../exercises/application/exercises.service';
import { type MediaRepository } from '../infrastructure/media.repository';
import { MediaService } from './media.service';

const ID = '11111111-1111-4111-8111-111111111111';
const ADMIN = '22222222-2222-4222-8222-222222222222';

function row(overrides: Partial<MediaAsset> = {}): MediaAsset {
  return {
    id: ID,
    kind: 'IMAGE',
    storageKey: `image/${ID}.webp`,
    mimeType: 'image/webp',
    byteSize: 12,
    width: null,
    height: null,
    checksum: 'abc',
    originalName: 'photo.webp',
    uploadedById: ADMIN,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
    deletedAt: null,
    ...overrides,
  };
}

interface Stubs {
  repository: {
    findById: jest.Mock;
    list: jest.Mock;
    create: jest.Mock;
    countReferences: jest.Mock;
    softDelete: jest.Mock;
    setExerciseMedia: jest.Mock;
  };
  storage: { put: jest.Mock; delete: jest.Mock; urlFor: jest.Mock };
  exercises: { invalidateCache: jest.Mock };
  audit: { record: jest.Mock };
}

function buildStubs(): Stubs {
  return {
    repository: {
      findById: jest.fn().mockResolvedValue(null),
      list: jest.fn().mockResolvedValue([]),
      create: jest.fn().mockImplementation((data: MediaAsset) => Promise.resolve(row(data))),
      countReferences: jest.fn().mockResolvedValue(0),
      softDelete: jest.fn().mockResolvedValue(undefined),
      setExerciseMedia: jest.fn().mockResolvedValue(true),
    },
    storage: {
      put: jest.fn().mockResolvedValue(undefined),
      delete: jest.fn().mockResolvedValue(undefined),
      urlFor: jest.fn((key: string) => `http://storage.test/carlys-media/${key}`),
    },
    exercises: { invalidateCache: jest.fn().mockResolvedValue(undefined) },
    audit: { record: jest.fn() },
  };
}

function buildService(stubs: Stubs, maxBytes = 1_024): MediaService {
  return new MediaService(
    stubs.repository as unknown as MediaRepository,
    stubs.storage as unknown as StorageService,
    { mediaMaxUploadBytes: maxBytes } as AppConfigService,
    stubs.exercises as unknown as ExercisesService,
    stubs.audit as unknown as AuditService,
  );
}

function upload(
  overrides: Partial<Parameters<MediaService['upload']>[0]> = {},
): Parameters<MediaService['upload']>[0] {
  return {
    id: ID,
    kind: 'IMAGE',
    mimeType: 'image/webp',
    originalName: 'photo.webp',
    content: Buffer.from('des octets'),
    actor: { adminUserId: ADMIN },
    ...overrides,
  };
}

describe('MediaService', () => {
  it('dépose l’objet AVANT d’écrire la ligne : jamais d’URL morte', async () => {
    const stubs = buildStubs();
    const order: string[] = [];
    stubs.storage.put.mockImplementation(() => {
      order.push('storage');
      return Promise.resolve();
    });
    stubs.repository.create.mockImplementation((data: MediaAsset) => {
      order.push('base');
      return Promise.resolve(row(data));
    });

    await buildService(stubs).upload(upload());

    expect(order).toEqual(['storage', 'base']);
  });

  it('la clé de stockage vient de l’identifiant, pas du nom déposé', async () => {
    const stubs = buildStubs();

    const asset = await buildService(stubs).upload(
      upload({ originalName: '../../etc/passwd.png' }),
    );

    expect(stubs.storage.put).toHaveBeenCalledWith(
      `image/${ID}.webp`,
      expect.any(Buffer),
      'image/webp',
    );
    expect(asset.url).toBe(`http://storage.test/carlys-media/image/${ID}.webp`);
  });

  it('dépôt rejoué après une coupure : ni second objet ni seconde ligne', async () => {
    const stubs = buildStubs();
    stubs.repository.findById.mockResolvedValue(row());

    const asset = await buildService(stubs).upload(upload());

    expect(asset.id).toBe(ID);
    expect(stubs.storage.put).not.toHaveBeenCalled();
    expect(stubs.repository.create).not.toHaveBeenCalled();
  });

  it('type MIME hors du genre demandé → refusé', async () => {
    const stubs = buildStubs();

    await expect(
      buildService(stubs).upload(upload({ mimeType: 'model/gltf-binary' })),
    ).rejects.toThrow(UnsupportedMediaTypeException);
    expect(stubs.storage.put).not.toHaveBeenCalled();
  });

  it('fichier vide → refusé', async () => {
    const stubs = buildStubs();

    await expect(buildService(stubs).upload(upload({ content: Buffer.alloc(0) }))).rejects.toThrow(
      BadRequestException,
    );
  });

  it('fichier au-dessus du plafond → refusé sans toucher au stockage', async () => {
    const stubs = buildStubs();

    await expect(
      buildService(stubs).upload(upload({ content: Buffer.alloc(2_048) })),
    ).rejects.toThrow(PayloadTooLargeException);
    expect(stubs.storage.put).not.toHaveBeenCalled();
  });

  it('les dimensions d’une image sont lues à l’entrée', async () => {
    const stubs = buildStubs();
    // En-tête PNG minimal : signature, longueur + type du chunk, 8×4.
    const png = Buffer.alloc(24);
    png.writeUInt32BE(0x89504e47, 0);
    png.writeUInt32BE(8, 16);
    png.writeUInt32BE(4, 20);

    const asset = await buildService(stubs).upload(upload({ mimeType: 'image/png', content: png }));

    expect(asset.width).toBe(8);
    expect(asset.height).toBe(4);
  });

  it('un maillage n’est pas passé au lecteur d’images', async () => {
    const stubs = buildStubs();

    const asset = await buildService(stubs).upload(
      upload({ kind: 'MESH_3D', mimeType: 'model/gltf-binary', originalName: 'squat.glb' }),
    );

    expect(asset.width).toBeNull();
    expect(stubs.storage.put).toHaveBeenCalledWith(
      `mesh_3d/${ID}.glb`,
      expect.any(Buffer),
      'model/gltf-binary',
    );
  });

  it('suppression refusée tant qu’un exercice référence le média', async () => {
    const stubs = buildStubs();
    stubs.repository.findById.mockResolvedValue(row());
    stubs.repository.countReferences.mockResolvedValue(2);

    await expect(buildService(stubs).remove(ID, { adminUserId: ADMIN })).rejects.toThrow(
      BadRequestException,
    );
    expect(stubs.repository.softDelete).not.toHaveBeenCalled();
    expect(stubs.storage.delete).not.toHaveBeenCalled();
  });

  it('média libre : ligne marquée supprimée puis objet retiré', async () => {
    const stubs = buildStubs();
    stubs.repository.findById.mockResolvedValue(row());

    await buildService(stubs).remove(ID, { adminUserId: ADMIN });

    expect(stubs.repository.softDelete).toHaveBeenCalledWith(ID);
    expect(stubs.storage.delete).toHaveBeenCalledWith(`image/${ID}.webp`);
  });

  it('suppression d’un média inconnu → 404', async () => {
    await expect(buildService(buildStubs()).remove(ID, { adminUserId: ADMIN })).rejects.toThrow(
      NotFoundException,
    );
  });

  it('un maillage ne peut pas servir de photo', async () => {
    const stubs = buildStubs();
    stubs.repository.findById.mockResolvedValue(row({ kind: 'MESH_3D' }));

    await expect(
      buildService(stubs).attachToExercise('ex-1', 'image', ID, { adminUserId: ADMIN }),
    ).rejects.toThrow(BadRequestException);
    expect(stubs.repository.setExerciseMedia).not.toHaveBeenCalled();
  });

  it('rattachement : le cache du catalogue est invalidé (sinon une heure d’attente)', async () => {
    const stubs = buildStubs();
    stubs.repository.findById.mockResolvedValue(row());

    await buildService(stubs).attachToExercise('ex-1', 'image', ID, { adminUserId: ADMIN });

    expect(stubs.exercises.invalidateCache).toHaveBeenCalled();
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.exercise_media_attached', actorType: 'ADMIN' }),
    );
  });

  it('détacher (`null`) ne vérifie aucun média', async () => {
    const stubs = buildStubs();

    await buildService(stubs).attachToExercise('ex-1', 'image', null, { adminUserId: ADMIN });

    expect(stubs.repository.findById).not.toHaveBeenCalled();
    expect(stubs.repository.setExerciseMedia).toHaveBeenCalledWith('ex-1', 'image', null);
  });

  it('exercice introuvable au rattachement → 404', async () => {
    const stubs = buildStubs();
    stubs.repository.findById.mockResolvedValue(row());
    stubs.repository.setExerciseMedia.mockResolvedValue(false);

    await expect(
      buildService(stubs).attachToExercise('inconnu', 'image', ID, { adminUserId: ADMIN }),
    ).rejects.toThrow(NotFoundException);
  });
});
