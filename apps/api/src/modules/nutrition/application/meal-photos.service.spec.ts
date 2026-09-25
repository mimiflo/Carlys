import { ConflictException, NotFoundException } from '@nestjs/common';
import { type MealPhoto } from '@prisma/client';
import { type PinoLogger } from 'nestjs-pino';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { InMemoryObjectStore } from '../../../../test/support/in-memory-object-store';
import {
  ConcurrentPhotoError,
  MealGoneError,
  type MealPhotosRepository,
  type StoredPhoto,
} from '../infrastructure/meal-photos.repository';
import { MealPhotoObjects } from './meal-photo-objects';
import { MealPhotosService } from './meal-photos.service';
import { type MealsService } from './meals.service';

const USER = 'utilisateur-1';
const MEAL = 'repas-1';
const PHOTO = readFileSync(
  join(__dirname, '..', '..', '..', '..', 'test', 'fixtures', 'jpeg', 'repas-exif-gps.jpg'),
);

function photoRow(overrides: Partial<MealPhoto> = {}): MealPhoto {
  return {
    mealId: MEAL,
    storageKey: `meal-photos/${USER}/ancienne.jpg`,
    byteSize: 10,
    sha256: 'empreinte-ancienne',
    createdAt: new Date('2026-09-20T10:00:00Z'),
    updatedAt: new Date('2026-09-20T10:00:00Z'),
    ...overrides,
  };
}

function build() {
  const store = new InMemoryObjectStore();
  const logger = { error: jest.fn(), info: jest.fn() };
  const objects = new MealPhotoObjects(store, logger as unknown as PinoLogger);
  const repository = {
    findOwnedMeal: jest.fn().mockResolvedValue({ id: MEAL, photo: null }),
    attach: jest.fn().mockResolvedValue(undefined),
    detach: jest.fn().mockResolvedValue(null),
    forgetMissingObject: jest.fn().mockResolvedValue(undefined),
    forgetAllOf: jest.fn().mockResolvedValue(undefined),
  };
  const meals = { get: jest.fn().mockResolvedValue({ id: MEAL, photo: { updatedAt: 'x' } }) };
  const service = new MealPhotosService(
    repository as unknown as MealPhotosRepository,
    objects,
    meals as unknown as MealsService,
    logger as unknown as PinoLogger,
  );
  return { store, logger, repository, meals, service };
}

const upload = { mimeType: 'image/jpeg', content: PHOTO };

describe('MealPhotosService', () => {
  it('repas inconnu, supprimé ou d’autrui : le MÊME 404, et rien n’est déposé', async () => {
    const { store, repository, service } = build();
    repository.findOwnedMeal.mockResolvedValue(null);

    await expect(service.replace(USER, MEAL, upload, 'req')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(service.read(USER, MEAL, 'req')).rejects.toThrow('Repas introuvable.');
    await expect(service.remove(USER, MEAL, 'req')).rejects.toThrow('Repas introuvable.');
    expect(store.objects.size).toBe(0);
  });

  it('première photo : l’objet FILTRÉ part au stockage, puis la ligne le cite', async () => {
    const { store, repository, service } = build();

    await service.replace(USER, MEAL, upload, 'req');

    const [key] = store.keysUnder(`meal-photos/${USER}/`);
    const stored = store.objects.get(key!)!.body;
    expect(stored.includes(Buffer.from('Exif'))).toBe(false);
    expect(repository.attach).toHaveBeenCalledWith(USER, MEAL, null, {
      storageKey: key,
      byteSize: stored.length,
      sha256: createHash('sha256').update(stored).digest('hex'),
    });
  });

  it('remplacer : l’ancien objet est effacé APRÈS l’écriture de la nouvelle ligne', async () => {
    const { store, repository, service } = build();
    const old = photoRow();
    await store.put(old.storageKey, Buffer.from('ancienne'), 'image/jpeg');
    repository.findOwnedMeal.mockResolvedValue({ id: MEAL, photo: old });
    repository.attach.mockImplementation(() => {
      // Au moment d'écrire la ligne, l'ancienne photo est encore là.
      expect(store.objects.has(old.storageKey)).toBe(true);
      return Promise.resolve();
    });

    await service.replace(USER, MEAL, upload, 'req');

    expect(repository.attach).toHaveBeenCalledWith(USER, MEAL, old.storageKey, expect.anything());
    expect(store.objects.has(old.storageKey)).toBe(false);
    expect(store.keysUnder(`meal-photos/${USER}/`)).toHaveLength(1);
  });

  it('rejouer le MÊME envoi ne dépose rien de plus (file hors ligne)', async () => {
    const { store, repository, service } = build();
    await service.replace(USER, MEAL, upload, 'req');
    const [, , , written] = repository.attach.mock.calls[0] as [string, string, null, StoredPhoto];
    const current = photoRow({ storageKey: written.storageKey, sha256: written.sha256 });
    repository.findOwnedMeal.mockResolvedValue({ id: MEAL, photo: current });

    await service.replace(USER, MEAL, upload, 'req');

    expect(repository.attach).toHaveBeenCalledTimes(1);
    expect(store.keysUnder(`meal-photos/${USER}/`)).toEqual([current.storageKey]);
  });

  it('deux dépôts simultanés : 409, et l’objet du perdant est repris aussitôt', async () => {
    const { store, repository, service } = build();
    repository.attach.mockRejectedValue(new ConcurrentPhotoError());

    await expect(service.replace(USER, MEAL, upload, 'req')).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(store.objects.size).toBe(0);
  });

  it('repas ou compte supprimé pendant l’envoi : 404, et l’objet neuf est repris aussitôt', async () => {
    const { store, repository, meals, service } = build();
    repository.attach.mockRejectedValue(new MealGoneError());

    await expect(service.replace(USER, MEAL, upload, 'req')).rejects.toThrow('Repas introuvable.');
    expect(store.objects.size).toBe(0);
    expect(meals.get).not.toHaveBeenCalled();
  });

  it('lire : les octets stockés, un ETag fort (empreinte), la date de la photo', async () => {
    const { store, repository, service } = build();
    const row = photoRow({ sha256: 'abc123' });
    await store.put(row.storageKey, Buffer.from('octets'), 'image/jpeg');
    repository.findOwnedMeal.mockResolvedValue({ id: MEAL, photo: row });

    const photo = await service.read(USER, MEAL, 'req');

    expect(photo.bytes.toString()).toBe('octets');
    expect(photo.etag).toBe('"abc123"');
    expect(photo.updatedAt).toEqual(row.updatedAt);
  });

  it('lire un repas sans photo : 404', async () => {
    const { service } = build();
    await expect(service.read(USER, MEAL, 'req')).rejects.toThrow('Ce repas n’a pas de photo.');
  });

  it('objet disparu du stockage : 404, erreur journalisée, et la ligne cesse de l’annoncer', async () => {
    const { repository, logger, service } = build();
    const row = photoRow();
    repository.findOwnedMeal.mockResolvedValue({ id: MEAL, photo: row });

    await expect(service.read(USER, MEAL, 'req-5')).rejects.toBeInstanceOf(NotFoundException);

    expect(repository.forgetMissingObject).toHaveBeenCalledWith(MEAL, row.storageKey);
    expect(logger.error).toHaveBeenCalledWith(
      expect.objectContaining({ requestId: 'req-5' }),
      expect.any(String),
    );
  });

  it('retirer : la ligne, puis l’objet ; sans photo, rien à faire et c’est un succès', async () => {
    const { store, repository, service } = build();
    const row = photoRow();
    await store.put(row.storageKey, Buffer.from('a'), 'image/jpeg');
    repository.detach.mockResolvedValueOnce(row.storageKey);

    await service.remove(USER, MEAL, 'req');
    expect(store.objects.has(row.storageKey)).toBe(false);

    await expect(service.remove(USER, MEAL, 'req')).resolves.toBeUndefined();
  });

  it('retirer quand le stockage refuse d’effacer : 204 quand même, erreur journalisée', async () => {
    const { store, repository, logger, service } = build();
    const row = photoRow();
    await store.put(row.storageKey, Buffer.from('a'), 'image/jpeg');
    repository.detach.mockResolvedValue(row.storageKey);
    store.failDeletes = true;

    await expect(service.remove(USER, MEAL, 'req-6')).resolves.toBeUndefined();
    expect(logger.error).toHaveBeenCalledWith(
      expect.objectContaining({ requestId: 'req-6', storageKey: row.storageKey }),
      expect.any(String),
    );
  });
});
